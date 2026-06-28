pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import qs.modules.common
import qs.modules.common.functions

/**
 * Fetches timestamped (synced) lyrics for the currently playing track.
 *
 * All enabled sources are queried IN PARALLEL. The result is committed from the
 * highest-priority source that passes the sanity checks (duration + title/artist
 * match); a lower-priority result is only used once every higher-priority source
 * has finished (so priority is preserved while latency stays ~one round-trip).
 *
 * Priority (high -> low):
 *   1. LRCLIB    /api/get     (server-side exact match — synced)
 *   2. LRCLIB    /api/search  (fuzzy, best candidate by duration — synced)
 *   3. Musixmatch              (app-token subtitles — synced)
 *   4. lyrics.ovh              (plain/unsynced — last resort)
 *
 * Exposes:
 *   lines        -> [{ time: <seconds>, text: <string> }] sorted by time (synced)
 *   synced       -> bool, true when at least one line has a timestamp
 *   plainLyrics  -> string, unsynced fallback text
 *   instrumental -> bool
 *   status       -> "idle" | "loading" | "found" | "notfound" | "error"
 *   source       -> human-readable provider name of the accepted result
 */
Singleton {
    id: root

    readonly property var cfg: Config.options.media.lyrics
    readonly property string lrclibUserAgent: "quickshell-ii (https://github.com/quickshell-mirror/quickshell)"

    readonly property MprisPlayer activePlayer: MprisController.activePlayer

    // ---- Output state ----
    property var lines: []
    property bool synced: false
    property string plainLyrics: ""
    property bool instrumental: false
    property string status: "idle"
    property string source: ""

    // Identity of the track lyrics are currently loaded/loading for
    property string trackKey: ""
    property int _reqId: 0
    property var _ctx: null

    // Parallel-fetch bookkeeping for the current request
    property var _order: []        // active provider keys, high -> low priority
    property var _results: ({})     // key -> { done: bool, candidate: <obj|null> }
    property bool _settled: false

    // Cached Musixmatch app token (refreshed per shell session / on auth failure)
    property string _mxmToken: ""
    property int _mxmPendingReqId: -1

    // Touch from the shell root to eagerly create this singleton, so lyrics are
    // fetched on every track change even before the media popup is opened.
    function load() {}

    // ---------------------------------------------------------------------
    // Track watching
    // ---------------------------------------------------------------------
    function _currentKey() {
        const p = root.activePlayer;
        if (!p) return "";
        const title = (p.trackTitle ?? "").trim();
        const artist = (p.trackArtist ?? "").trim();
        if (title.length === 0) return "";
        return `${title} ${artist}`;
    }

    function maybeFetch() {
        if (!root.cfg.enabled) {
            root._clear("idle");
            return;
        }
        const key = root._currentKey();
        if (key === root.trackKey) return; // Same track, nothing to do
        root.trackKey = key;
        if (key.length === 0) {
            root._clear("idle");
            return;
        }
        root.fetchLyrics();
    }

    Connections {
        target: MprisController
        function onTrackChanged() { debounce.restart(); }
    }
    onActivePlayerChanged: debounce.restart()
    Component.onCompleted: {
        if (root.cfg.useMusixmatch) mxmTokenProc.running = true; // warm the token
        debounce.restart();
    }

    Timer {
        id: debounce
        // Metadata often arrives in pieces (title, then album, then art);
        // wait for it to settle before firing requests.
        interval: 700
        repeat: false
        onTriggered: root.maybeFetch()
    }

    // ---------------------------------------------------------------------
    // Fetch orchestration (parallel)
    // ---------------------------------------------------------------------
    function fetchLyrics() {
        const p = root.activePlayer;
        if (!p) { root._clear("idle"); return; }

        const reqId = ++root._reqId;
        root._ctx = {
            reqId: reqId,
            title: StringUtils.cleanMusicTitle(p.trackTitle) || (p.trackTitle ?? ""),
            artist: p.trackArtist ?? "",
            album: p.trackAlbum ?? "",
            duration: Math.round(p.length ?? 0)
        };

        root.lines = [];
        root.synced = false;
        root.plainLyrics = "";
        root.instrumental = false;
        root.source = "";
        root.status = "loading";

        // Build the active provider set (priority order) and fire them all at once.
        const order = ["lrclib-get", "lrclib-search"];
        if (root.cfg.useMusixmatch) order.push("musixmatch");
        if (root.cfg.usePlainFallback) order.push("lyrics-ovh");
        root._order = order;
        const results = {};
        for (const k of order) results[k] = { done: false, candidate: null };
        root._results = results;
        root._settled = false;

        root._runLrclibGet();
        root._runLrclibSearch();
        if (root.cfg.useMusixmatch) root._runMusixmatch();
        if (root.cfg.usePlainFallback) root._runPlainFallback();

        watchdog.restart();
    }

    // Safety net: if some provider never reports back (e.g. a process couldn't be
    // restarted while a previous request was still in flight), don't hang on
    // "loading" forever — finalize with whatever valid result we already have.
    Timer {
        id: watchdog
        interval: 13000
        repeat: false
        onTriggered: {
            if (root._settled) return;
            for (const key of root._order) {
                const r = root._results[key];
                if (r && r.done && r.candidate) { root._commit(r.candidate); return; }
            }
            root._settled = true;
            root.status = "notfound";
        }
    }

    function _clear(state) {
        root._reqId++; // invalidate any in-flight callbacks
        root._settled = true;
        root.lines = [];
        root.synced = false;
        root.plainLyrics = "";
        root.instrumental = false;
        root.source = "";
        root.status = state ?? "idle";
    }

    function _stale(reqId) {
        return reqId !== root._reqId || root._ctx === null;
    }

    // Record a provider's outcome and re-evaluate the priority decision.
    function _report(reqId, key, candidate) {
        if (root._stale(reqId) || root._settled) return;
        const r = root._results[key];
        if (!r) return;
        r.done = true;
        r.candidate = candidate;
        root._evaluate();
    }

    function _evaluate() {
        if (root._settled) return;
        for (const key of root._order) {
            const r = root._results[key];
            if (!r.done) return;           // must wait for this higher-priority source
            if (r.candidate) {             // highest-priority valid result wins
                root._commit(r.candidate);
                return;
            }
        }
        // Everything finished, nothing valid.
        root._settled = true;
        root.status = "notfound";
        watchdog.stop();
    }

    function _commit(candidate) {
        root._settled = true;
        watchdog.stop();
        root.lines = candidate.lines;
        root.synced = candidate.synced;
        root.plainLyrics = candidate.plainLyrics;
        root.instrumental = candidate.instrumental;
        root.source = candidate.source;
        root.status = "found";
    }

    // ---------------------------------------------------------------------
    // Providers
    // ---------------------------------------------------------------------
    function _runLrclibGet() {
        const c = root._ctx;
        lrclibGetProc.reqId = c.reqId;
        lrclibGetProc.command = ["bash", "-c",
            `curl -sf -m 10 --connect-timeout 6 --compressed -G 'https://lrclib.net/api/get' ` +
            `-H "User-Agent: $5" ` +
            `--data-urlencode "track_name=$1" --data-urlencode "artist_name=$2" ` +
            `--data-urlencode "album_name=$3" --data-urlencode "duration=$4"`,
            "lyrics", c.title, c.artist, c.album, String(c.duration), root.lrclibUserAgent];
        lrclibGetProc.running = true;
    }

    function _runLrclibSearch() {
        const c = root._ctx;
        lrclibSearchProc.reqId = c.reqId;
        lrclibSearchProc.command = ["bash", "-c",
            `curl -sf -m 10 --connect-timeout 6 --compressed -G 'https://lrclib.net/api/search' ` +
            `-H "User-Agent: $3" ` +
            `--data-urlencode "track_name=$1" --data-urlencode "artist_name=$2"`,
            "lyrics", c.title, c.artist, root.lrclibUserAgent];
        lrclibSearchProc.running = true;
    }

    function _runMusixmatch() {
        const c = root._ctx;
        if (root._mxmToken.length > 0) {
            root._mxmFetchSubtitles(c.reqId);
        } else {
            // Token still warming/unavailable: fetch it, then continue.
            root._mxmPendingReqId = c.reqId;
            if (!mxmTokenProc.running) mxmTokenProc.running = true;
        }
    }

    function _mxmFetchSubtitles(reqId) {
        const c = root._ctx;
        if (root._stale(reqId)) return;
        mxmSubtitlesProc.reqId = reqId;
        mxmSubtitlesProc.command = ["bash", "-c",
            `curl -sf -m 10 --connect-timeout 6 --compressed -G ` +
            `'https://apic-desktop.musixmatch.com/ws/1.1/macro.subtitles.get' ` +
            `-H 'authority: apic-desktop.musixmatch.com' -H 'cookie: x-mxm-token-guid=' ` +
            `--data 'format=json' --data 'namespace=lyrics_richsynced' ` +
            `--data 'subtitle_format=lrc' --data 'app_id=web-desktop-app-v1.0' ` +
            `--data-urlencode "usertoken=$1" --data-urlencode "q_track=$2" ` +
            `--data-urlencode "q_artist=$3" --data-urlencode "q_duration=$4"`,
            "lyrics", root._mxmToken, c.title, c.artist, String(c.duration)];
        mxmSubtitlesProc.running = true;
    }

    function _runPlainFallback() {
        const c = root._ctx;
        if (c.artist.length === 0) { root._report(c.reqId, "lyrics-ovh", null); return; }
        // lyrics.ovh uses path params, so values must be URL-encoded ourselves.
        plainFallbackProc.reqId = c.reqId;
        plainFallbackProc.command = ["bash", "-c",
            `curl -sf -m 10 --connect-timeout 6 --compressed "https://api.lyrics.ovh/v1/$1/$2"`,
            "lyrics", root._encodeUriPath(c.artist), root._encodeUriPath(c.title)];
        plainFallbackProc.running = true;
    }

    // ---------------------------------------------------------------------
    // Provider result handlers
    // ---------------------------------------------------------------------
    function _onLrclibGet(reqId, text) {
        let data = null;
        try { data = text.length ? JSON.parse(text) : null; } catch (e) { data = null; }
        let cand = null;
        if (data && !data.code) {
            cand = root._makeCandidate("LRCLIB", data.syncedLyrics, data.plainLyrics,
                !!data.instrumental, data.trackName, data.artistName, data.duration);
        }
        root._report(reqId, "lrclib-get", cand);
    }

    function _onLrclibSearch(reqId, text) {
        let arr = null;
        try { arr = text.length ? JSON.parse(text) : null; } catch (e) { arr = null; }
        let cand = null;
        if (Array.isArray(arr) && arr.length > 0) {
            const ranked = arr
                .map(r => ({ r: r, score: root._matchScore(r.trackName, r.artistName, r.duration) }))
                .filter(x => x.score >= 0)
                .sort((a, b) => {
                    const aSync = a.r.syncedLyrics ? 1 : 0;
                    const bSync = b.r.syncedLyrics ? 1 : 0;
                    if (aSync !== bSync) return bSync - aSync;
                    return b.score - a.score;
                });
            for (const x of ranked) {
                cand = root._makeCandidate("LRCLIB", x.r.syncedLyrics, x.r.plainLyrics,
                    !!x.r.instrumental, x.r.trackName, x.r.artistName, x.r.duration);
                if (cand) break;
            }
        }
        root._report(reqId, "lrclib-search", cand);
    }

    function _onMxmToken(text) {
        let token = "";
        try { token = JSON.parse(text)?.message?.body?.user_token ?? ""; } catch (e) { token = ""; }
        if (typeof token !== "string") token = "";
        root._mxmToken = token;
        const pending = root._mxmPendingReqId;
        root._mxmPendingReqId = -1;
        if (pending >= 0) {
            if (token.length > 0) root._mxmFetchSubtitles(pending);
            else root._report(pending, "musixmatch", null);
        }
    }

    function _onMxmSubtitles(reqId, text) {
        let cand = null;
        let authFailed = false;
        try {
            const body = JSON.parse(text)?.message?.body;
            const macro = body?.macro_calls ?? {};
            const subMsg = macro["track.subtitles.get"]?.message;
            const subStatus = subMsg?.header?.status_code ?? 200;
            if (subStatus === 401) authFailed = true;
            const subList = subMsg?.body?.subtitle_list;
            let lrc = "";
            if (Array.isArray(subList) && subList.length > 0) {
                lrc = subList[0]?.subtitle?.subtitle_body ?? "";
            }
            const matcher = macro["matcher.track.get"]?.message?.body?.track;
            cand = root._makeCandidate("Musixmatch", lrc, lrc,
                matcher?.instrumental === 1,
                matcher?.track_name ?? null, matcher?.artist_name ?? null,
                matcher?.track_length ?? 0);
        } catch (e) { cand = null; }

        if (cand === null && authFailed) {
            root._mxmToken = ""; // force a token refresh next time
        }
        root._report(reqId, "musixmatch", cand);
    }

    function _onPlainFallback(reqId, text) {
        let data = null;
        try { data = text.length ? JSON.parse(text) : null; } catch (e) { data = null; }
        const lyrics = (data && typeof data.lyrics === "string") ? data.lyrics : "";
        // Plain-text only, keyed by exact artist/title; lowest priority.
        const cand = root._makeCandidate("lyrics.ovh", "", lyrics, false, null, null, 0);
        root._report(reqId, "lyrics-ovh", cand);
    }

    // ---------------------------------------------------------------------
    // Candidate building + sanity checks
    // ---------------------------------------------------------------------
    // Returns a non-negative score if the candidate plausibly matches the
    // current track, or -1 to reject it outright.
    function _matchScore(candTitle, candArtist, candDuration) {
        const c = root._ctx;
        if (!c) return -1;
        let score = 0;

        // Duration is the strongest signal when available on both sides.
        if (c.duration > 0 && candDuration > 0) {
            const diff = Math.abs(candDuration - c.duration);
            if (diff > root.cfg.durationToleranceSeconds) return -1;
            score += (root.cfg.durationToleranceSeconds - diff);
        }

        // Title must be recognizably the same.
        const t1 = root._norm(c.title);
        const t2 = root._norm(candTitle);
        if (t1.length > 0 && t2.length > 0) {
            if (t1 === t2) score += 6;
            else if (t1.includes(t2) || t2.includes(t1)) score += 4;
            else {
                const ov = root._tokenOverlap(t1, t2);
                if (ov < 0.5) return -1;
                score += ov * 3;
            }
        }

        // Artist is a softer signal (compilations, "feat.", localized names).
        const a1 = root._norm(c.artist);
        const a2 = root._norm(candArtist);
        if (a1.length > 0 && a2.length > 0) {
            if (a1 === a2 || a1.includes(a2) || a2.includes(a1)) score += 2;
            else score += root._tokenOverlap(a1, a2) * 2;
        }
        return score;
    }

    // Build a displayable candidate, or null if it doesn't match / is empty.
    function _makeCandidate(sourceName, syncedText, plainText, instrumental, candTitle, candArtist, candDuration) {
        if (candTitle !== null || candDuration > 0) {
            if (root._matchScore(candTitle, candArtist, candDuration) < 0) return null;
        }
        if (instrumental) {
            return { source: sourceName, lines: [], synced: false, plainLyrics: "", instrumental: true };
        }
        const parsed = root._parseLrc(syncedText);
        if (parsed.length > 0) {
            return { source: sourceName, lines: parsed, synced: true,
                plainLyrics: plainText ?? "", instrumental: false };
        }
        if (plainText && plainText.trim().length > 0) {
            return { source: sourceName, lines: [], synced: false,
                plainLyrics: plainText, instrumental: false };
        }
        return null;
    }

    // ---------------------------------------------------------------------
    // Helpers
    // ---------------------------------------------------------------------
    function _norm(s) {
        if (!s) return "";
        s = String(s).toLowerCase();
        s = s.replace(/\(.*?\)|\[.*?\]|\{.*?\}/g, " "); // bracketed extras
        s = s.replace(/\b(feat|ft|featuring|with)\b.*$/g, " ");
        s = s.replace(/[^\p{L}\p{N}]+/gu, " "); // keep letters/numbers only
        return s.trim().replace(/\s+/g, " ");
    }

    // encodeURIComponent, plus the chars it leaves unescaped, so the result is
    // safe to drop into both a URL path and a bash argument.
    function _encodeUriPath(s) {
        return encodeURIComponent(String(s ?? "")).replace(/[!'()*]/g, c =>
            "%" + c.charCodeAt(0).toString(16).toUpperCase());
    }

    function _tokenOverlap(a, b) {
        const sa = a.split(" ").filter(x => x.length > 0);
        const sb = new Set(b.split(" ").filter(x => x.length > 0));
        if (sa.length === 0 || sb.size === 0) return 0;
        let hit = 0;
        for (const t of sa) if (sb.has(t)) hit++;
        return hit / sa.length;
    }

    function _parseLrc(lrc) {
        if (!lrc) return [];
        const out = [];
        const tagRe = /\[(\d{1,2}):(\d{1,2}(?:[.:]\d{1,3})?)\]/g;
        const lines = String(lrc).split(/\r?\n/);
        for (const line of lines) {
            const text = line.replace(tagRe, "").trim();
            let m;
            tagRe.lastIndex = 0;
            while ((m = tagRe.exec(line)) !== null) {
                const min = parseInt(m[1], 10);
                const sec = parseFloat(m[2].replace(":", "."));
                if (isNaN(min) || isNaN(sec)) continue;
                out.push({ time: min * 60 + sec, text: text });
            }
        }
        out.sort((a, b) => a.time - b.time);
        return out;
    }

    /** Index of the active line for a given playback position (seconds). */
    function indexForPosition(pos) {
        const l = root.lines;
        if (!l || l.length === 0) return -1;
        if (pos < l[0].time) return -1;
        // Binary search for the last line with time <= pos.
        let lo = 0, hi = l.length - 1, ans = -1;
        while (lo <= hi) {
            const mid = (lo + hi) >> 1;
            if (l[mid].time <= pos) { ans = mid; lo = mid + 1; }
            else hi = mid - 1;
        }
        return ans;
    }

    // ---------------------------------------------------------------------
    // Processes
    // ---------------------------------------------------------------------
    Process {
        id: lrclibGetProc
        property int reqId: 0
        stdout: StdioCollector { onStreamFinished: root._onLrclibGet(lrclibGetProc.reqId, this.text) }
    }
    Process {
        id: lrclibSearchProc
        property int reqId: 0
        stdout: StdioCollector { onStreamFinished: root._onLrclibSearch(lrclibSearchProc.reqId, this.text) }
    }
    Process {
        id: mxmTokenProc
        command: ["bash", "-c",
            `curl -sf -m 10 --connect-timeout 6 --compressed ` +
            `'https://apic-desktop.musixmatch.com/ws/1.1/token.get?app_id=web-desktop-app-v1.0' ` +
            `-H 'authority: apic-desktop.musixmatch.com' -H 'cookie: x-mxm-token-guid='`]
        stdout: StdioCollector { onStreamFinished: root._onMxmToken(this.text) }
    }
    Process {
        id: mxmSubtitlesProc
        property int reqId: 0
        stdout: StdioCollector { onStreamFinished: root._onMxmSubtitles(mxmSubtitlesProc.reqId, this.text) }
    }
    Process {
        id: plainFallbackProc
        property int reqId: 0
        stdout: StdioCollector { onStreamFinished: root._onPlainFallback(plainFallbackProc.reqId, this.text) }
    }
}
