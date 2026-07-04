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
    property string lastUpdated: ""

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
        const script = `set -o pipefail
TOKEN="$(jq -r '.claudeAiOauth.accessToken // empty' "${root.credentialsPath}" 2>/dev/null)"
if [ -z "$TOKEN" ]; then echo "__NOAUTH__"; exit 0; fi
curl -sf --config - <<EOF | jq -c '{sessionPercent: (.five_hour.utilization // 0), sessionResetsAt: (.five_hour.resets_at // ""), sessionSeverity: (([.limits[]? | select(.kind=="session") | .severity] | first) // "normal"), weekPercent: (.seven_day.utilization // 0), weekResetsAt: (.seven_day.resets_at // ""), opusPercent: (.seven_day_opus.utilization // -1), opusResetsAt: (.seven_day_opus.resets_at // "")}'
url = "https://api.anthropic.com/api/oauth/usage"
header = "Authorization: Bearer $TOKEN"
header = "anthropic-beta: oauth-2025-04-20"
header = "Content-Type: application/json"
EOF`;
        fetcher.command = ["bash", "-c", script];
        fetcher.running = true;
    }

    Component.onCompleted: getData()

    Timer {
        running: root.enabled
        repeat: true
        interval: root.fetchInterval
        triggeredOnStart: true
        onTriggered: root.getData()
    }

    Process {
        id: fetcher
        stdout: StdioCollector {
            onStreamFinished: {
                const out = text.trim();
                if (out === "__NOAUTH__" || out.length === 0) {
                    root.available = false;
                    root.lastError = "Not logged into Claude Code (no token at " + root.credentialsPath + ")";
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
                    root.lastUpdated = Qt.formatDateTime(new Date(), "hh:mm");
                } catch (e) {
                    root.available = false;
                    root.lastError = "Bad response: " + out.slice(0, 80);
                }
            }
        }
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0) {
                root.available = false;
                root.lastError = "Request failed (exit " + exitCode + ") — token may be expired; open Claude Code to refresh it";
            }
        }
    }
}
