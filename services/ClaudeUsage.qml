pragma Singleton
pragma ComponentBehavior: Bound

import qs.modules.common
import Quickshell
import Quickshell.Io
import QtQuick

/**
 * Polls the Claude Code subscription usage endpoint (the same data `/usage` shows).
 *
 * GET https://api.anthropic.com/api/oauth/usage
 * Authenticated with the Claude Code OAuth access token from ~/.claude/.credentials.json,
 * which Claude Code keeps refreshed. No separate API key is required — if you're logged
 * into Claude Code, this just works. The token is fed to curl via stdin (--config -) so
 * it never appears in process arguments.
 */
Singleton {
    id: root

    readonly property bool enabled: Config.options?.bar?.claudeUsage?.enable ?? true
    readonly property string credentialsPath: Config.options?.bar?.claudeUsage?.credentialsPath
        || (Quickshell.env("HOME") + "/.claude/.credentials.json")
    readonly property int warningThreshold: Config.options?.bar?.claudeUsage?.warningThreshold ?? 80
    readonly property int fetchInterval: (Config.options?.bar?.claudeUsage?.fetchIntervalMinutes ?? 5) * 60 * 1000

    // 5-hour rolling "session" window — the one that usually gates you.
    property real sessionPercent: 0
    property string sessionResetsAt: ""
    property string sessionSeverity: "normal"
    // 7-day "weekly" window across all models.
    property real weekPercent: 0
    property string weekResetsAt: ""
    // 7-day Opus window (only present on some plans; -1 means "not applicable").
    property real opusPercent: -1
    property string opusResetsAt: ""

    property bool available: false
    property string lastError: ""
    property double lastUpdatedMs: 0
    // Live relative age of the data, e.g. "5min ago". Bound to DateTime's clock
    // so it re-evaluates every minute; empty until the first successful fetch.
    readonly property string lastUpdatedAgo: {
        if (lastUpdatedMs === 0)
            return "";
        const diffMin = Math.max(0, Math.floor((DateTime.clock.date.getTime() - lastUpdatedMs) / 60000));
        if (diffMin < 1)
            return Translation.tr("just now");
        if (diffMin < 60)
            return diffMin + Translation.tr("min ago");
        const h = Math.floor(diffMin / 60);
        const m = diffMin % 60;
        return (m > 0 ? `${h}h ${m}m` : `${h}h`) + Translation.tr(" ago");
    }
    // Consecutive network-ish failures. Blips keep showing stale data;
    // only repeated failures hide the indicator.
    property int failureCount: 0
    readonly property int maxTransientFailures: 3
    // Consecutive HTTP 429s. The endpoint rate-limits aggressively, so back off
    // exponentially (fetchInterval * 2^streak, capped) instead of retrying soon —
    // retries keep the limiter's bucket hot and it never recovers.
    property int rateLimitStreak: 0

    readonly property real sessionFraction: Math.min(sessionPercent / 100, 1)
    readonly property bool warning: sessionSeverity !== "normal" || sessionPercent >= warningThreshold

    // Human-friendly reset string, e.g. "2h 13m" if within a day, else "Sun 19:59".
    function formatReset(isoString) {
        if (!isoString || isoString.length === 0)
            return "—";
        const reset = new Date(isoString);
        if (isNaN(reset.getTime()))
            return "—";
        const diffMs = reset.getTime() - new Date().getTime();
        if (diffMs <= 0)
            return Translation.tr("now");
        const diffMin = Math.round(diffMs / 60000);
        if (diffMin < 60)
            return diffMin + "m";
        if (diffMin < 24 * 60) {
            const h = Math.floor(diffMin / 60);
            const m = diffMin % 60;
            return m > 0 ? `${h}h ${m}m` : `${h}h`;
        }
        return Qt.formatDateTime(reset, "ddd hh:mm");
    }

    function getData() {
        if (!root.enabled)
            return;
        // Token read from the credentials file into curl via stdin, kept out of argv.
        // Output is either __NOAUTH__, __HTTP__<code> (non-200), or the jq-compacted JSON.
        const script = `TOKEN="$(jq -r '.claudeAiOauth.accessToken // empty' "${root.credentialsPath}" 2>/dev/null)"
if [ -z "$TOKEN" ]; then echo "__NOAUTH__"; exit 0; fi
RESP="$(curl -s -w '\\n%{http_code}' --config - <<EOF
url = "https://api.anthropic.com/api/oauth/usage"
header = "Authorization: Bearer $TOKEN"
header = "anthropic-beta: oauth-2025-04-20"
header = "Content-Type: application/json"
EOF
)" || { echo "__HTTP__000"; exit 0; }
CODE="\${RESP##*$'\\n'}"
BODY="\${RESP%$'\\n'*}"
if [ "$CODE" != "200" ]; then echo "__HTTP__$CODE"; exit 0; fi
printf '%s' "$BODY" | jq -c '{sessionPercent: (.five_hour.utilization // 0), sessionResetsAt: (.five_hour.resets_at // ""), sessionSeverity: (([.limits[]? | select(.kind=="session") | .severity] | first) // "normal"), weekPercent: (.seven_day.utilization // 0), weekResetsAt: (.seven_day.resets_at // ""), opusPercent: (.seven_day_opus.utilization // -1), opusResetsAt: (.seven_day_opus.resets_at // "")}'`;
        fetcher.command = ["bash", "-c", script];
        fetcher.running = true;
    }

    // Rate limited: keep whatever data we have (usage moves slowly, stale is fine)
    // and let the poll timer's exponential backoff spread out the next attempts.
    function handleRateLimit() {
        root.rateLimitStreak++;
        root.lastError = "Rate limited (HTTP 429)";
        if (root.lastUpdatedMs === 0)
            root.available = false; // never had data — nothing to show yet
        console.warn(`[ClaudeUsage] Rate limited (streak ${root.rateLimitStreak}), next poll in ${Math.round(pollTimer.interval / 60000)}min` + (root.available ? ", keeping stale data" : ""));
    }

    // A transient failure (network blip, 5xx) keeps stale data visible and
    // schedules a quick retry; only repeated failures or a real auth problem hide it.
    function handleFailure(reason, isTransient) {
        root.failureCount++;
        root.lastError = reason;
        if (!isTransient || root.failureCount >= root.maxTransientFailures) {
            root.available = false;
            console.warn(`[ClaudeUsage] ${reason} (failure ${root.failureCount}, hiding indicator)`);
        } else {
            console.info(`[ClaudeUsage] ${reason} (failure ${root.failureCount}/${root.maxTransientFailures}, keeping stale data, retrying in 30s)`);
            retryTimer.restart();
        }
    }

    // No Component.onCompleted fetch — pollTimer's triggeredOnStart covers startup;
    // both firing meant two requests per shell reload against a strict rate limiter.

    Timer {
        id: pollTimer
        running: root.enabled
        repeat: true
        // Doubles per consecutive 429, capped at 16x (e.g. 2min base -> 32min max).
        interval: root.fetchInterval * Math.pow(2, Math.min(root.rateLimitStreak, 4))
        triggeredOnStart: true
        onTriggered: root.getData()
    }

    // One-shot quick retry after a network blip (not used for rate limits).
    Timer {
        id: retryTimer
        interval: 30 * 1000
        onTriggered: root.getData()
    }

    Process {
        id: fetcher
        stdout: StdioCollector {
            onStreamFinished: {
                const out = text.trim();
                if (out === "__NOAUTH__") {
                    root.failureCount++;
                    root.available = false;
                    root.lastError = "Not logged into Claude Code (no token at " + root.credentialsPath + ")";
                    console.warn(`[ClaudeUsage] ${root.lastError}`);
                    return;
                }
                if (out.startsWith("__HTTP__")) {
                    const code = out.slice(8);
                    if (code === "429") {
                        root.handleRateLimit();
                        return;
                    }
                    // 5xx/000 = server/network blip: transient. Anything else (401/403/...) is fatal.
                    root.handleFailure(
                        code === "000" ? "Network error (curl failed)"
                        : `Request failed (HTTP ${code})` + (code === "401" || code === "403" ? " — token may be expired; open Claude Code to refresh it" : ""),
                        code === "000" || code.startsWith("5"));
                    return;
                }
                if (out.length === 0) {
                    root.handleFailure("Empty response from fetch script", true);
                    return;
                }
                try {
                    const d = JSON.parse(out);
                    root.sessionPercent = d.sessionPercent ?? 0;
                    root.sessionResetsAt = d.sessionResetsAt ?? "";
                    root.sessionSeverity = d.sessionSeverity ?? "normal";
                    root.weekPercent = d.weekPercent ?? 0;
                    root.weekResetsAt = d.weekResetsAt ?? "";
                    root.opusPercent = (d.opusPercent ?? -1);
                    root.opusResetsAt = d.opusResetsAt ?? "";
                    root.available = true;
                    root.lastError = "";
                    root.failureCount = 0;
                    root.rateLimitStreak = 0;
                    root.lastUpdatedMs = Date.now();
                    console.info(`[ClaudeUsage] Updated: session ${root.sessionPercent}%, week ${root.weekPercent}%`);
                } catch (e) {
                    root.handleFailure("Bad response: " + out.slice(0, 80), false);
                }
            }
        }
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0)
                root.handleFailure(`Fetch script died (exit ${exitCode})`, true);
        }
    }
}
