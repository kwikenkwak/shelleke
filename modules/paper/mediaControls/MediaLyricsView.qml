pragma ComponentBehavior: Bound
import QtQuick
import Quickshell.Services.Mpris
import qs.services
import qs.modules.paper.common
import qs.modules.paper.widgets

/**
 * The synced-lyrics panel.
 *
 * Behaviour is ported one-for-one from modules/pixel/mediaControls/
 * PixLyricsView.qml (itself the ii original) and must not drift:
 *   · `LyricsService.indexForPosition(position)` gives the active line;
 *   · the view scrolls so that line stays vertically CENTRED, animated over
 *     `PaperTheme.motion.scroll` (400 / 420 / 420 ms);
 *   · any manual scroll (wheel, drag, flick) suspends auto-scroll for
 *     `PaperTheme.motion.scrollSuspend` (4 s);
 *   · clicking a line seeks the player to that line's timestamp;
 *   · the position is polled at 250 ms while playing so tracking stays smooth;
 *   · unsynced lyrics render as one wrapped block, and the four placeholders
 *     ("Searching for lyrics…", "No lyrics", "Couldn't load lyrics",
 *     "Instrumental") come from `LyricsService.status` / `.instrumental`.
 *
 * The typography is the only thing that changes:
 *   hairline   — reading direction is a pure fade: current line `lead` 15 px
 *                `ink`, upcoming 13 px `ink-3`, PAST 13 px `ink-4`. No mark.
 *   ledger     — Charter; the current line is 15 px bold `ink` behind a 2 px
 *                ink-blue rule in the left margin — the same selection mark as
 *                a list row, so "where we are" is always the same gesture.
 *   broadsheet — Pagella; the current line is 16 px `ink` with a 2 px oxblood
 *                change bar and 9 px of indent.
 * Placeholders are never centred hero text; they are one quiet line.
 */
Item {
    id: root
    required property MprisPlayer player

    property real position: 0
    property bool userScrolling: false
    property bool _instant: true

    readonly property bool synced: LyricsService.synced
    readonly property int currentIndex: root.synced ? LyricsService.indexForPosition(root.position) : -1

    /// The lyrics face: body type in A, the title serif in B and C.
    readonly property string lyricFamily: PaperTheme.isHairline ? PaperTheme.fontBody : PaperTheme.fontTitle
    readonly property int currentSize: PaperTheme.pick(15, 15, 16)
    readonly property int restSize: PaperTheme.pick(13, 13, 13)
    /// A and B/C disagree about whether the current line carries a mark.
    readonly property bool markCurrent: !PaperTheme.isHairline

    function _refreshPosition(): void {
        if (!root.player)
            return;
        root.player.positionChanged();
        root.position = root.player.position ?? 0;
    }

    function centerCurrent(): void {
        if (root.userScrolling || lyricsList.count === 0)
            return;
        const idx = root.currentIndex;
        if (idx < 0)
            return;
        const from = lyricsList.contentY;
        lyricsList.positionViewAtIndex(idx, ListView.Center);
        const to = lyricsList.contentY;
        if (root._instant) {
            root._instant = false;
            scrollAnim.stop();
            return;
        }
        if (Math.abs(to - from) < 1)
            return;
        lyricsList.contentY = from;
        scrollAnim.from = from;
        scrollAnim.to = to;
        scrollAnim.restart();
    }

    function _markUserScroll(): void {
        root.userScrolling = true;
        resumeTimer.restart();
    }

    onCurrentIndexChanged: centerCurrent()

    Component.onCompleted: {
        root._instant = true;
        root._refreshPosition();
        Qt.callLater(root.centerCurrent);
    }

    onVisibleChanged: {
        if (visible) {
            root._instant = true;
            root._refreshPosition();
            Qt.callLater(root.centerCurrent);
        }
    }

    Connections {
        target: LyricsService
        function onLinesChanged(): void {
            root.userScrolling = false;
            root._instant = true;
            lyricsList.contentY = 0;
            root._refreshPosition();
            Qt.callLater(root.centerCurrent);
        }
    }

    Connections {
        target: root.player
        function onPositionChanged(): void {
            root.position = root.player?.position ?? 0;
        }
    }

    Timer { // Fine-grained position polling for smooth line tracking.
        running: (root.player?.isPlaying ?? false) && root.synced && root.visible
        interval: 250
        repeat: true
        onTriggered: root._refreshPosition()
    }

    Timer { // Resume auto-scroll 4 s after the user stops scrolling.
        id: resumeTimer
        interval: PaperTheme.motion.scrollSuspend
        repeat: false
        onTriggered: {
            root.userScrolling = false;
            root.centerCurrent();
        }
    }

    // ---- section header (B only: "LYRICS · synced") ----------------------
    PaperSectionHeader {
        id: header
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        visible: PaperTheme.isLedger
        height: visible ? implicitHeight : 0
        label: "Lyrics"
        meta: root.synced ? "synced" : (LyricsService.plainLyrics.length > 0 ? "unsynced" : "")
    }

    Item {
        id: body
        anchors.top: header.visible ? header.bottom : parent.top
        anchors.topMargin: header.visible ? PaperTheme.spacing.xs : 0
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom

        // ---- status / placeholder ---------------------------------------
        // One quiet line at the top, never centred hero text (§4.6 of B).
        PaperText {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            wrapMode: Text.WordWrap
            footnote: true
            role: PaperTheme.pick("meta", "small", "body")
            tone: PaperTheme.isHairline ? "ink4" : "ink3"
            visible: !root.synced && LyricsService.plainLyrics.length === 0
            text: {
                switch (LyricsService.status) {
                case "loading":
                    return "Searching for lyrics…";
                case "notfound":
                    return "No lyrics";
                case "error":
                    return "Couldn't load lyrics";
                default:
                    return LyricsService.instrumental ? "Instrumental" : "No lyrics";
                }
            }
        }

        // ---- synced lyrics ----------------------------------------------
        ListView {
            id: lyricsList
            anchors.fill: parent
            visible: root.synced
            clip: true
            interactive: true
            boundsBehavior: Flickable.DragOverBounds
            maximumFlickVelocity: 3500
            cacheBuffer: 600
            spacing: PaperTheme.pick(0, 5, 3)
            // Pad so the first/last lines can reach vertical centre.
            header: Item {
                width: 1
                height: lyricsList.height / 2
            }
            footer: Item {
                width: 1
                height: lyricsList.height / 2
            }

            model: LyricsService.lines

            onMovementStarted: root._markUserScroll()
            onDraggingChanged: if (dragging)
                root._markUserScroll()

            NumberAnimation {
                id: scrollAnim
                target: lyricsList
                property: "contentY"
                duration: PaperTheme.motion.scroll
                easing.type: PaperTheme.motion.type
                easing.bezierCurve: PaperTheme.motion.bezierCurve
            }

            delegate: Item {
                id: lineItem
                required property int index
                required property var modelData
                readonly property bool isCurrent: lineItem.index === root.currentIndex
                readonly property bool isPast: root.currentIndex >= 0 && lineItem.index < root.currentIndex
                width: lyricsList.width
                implicitHeight: lineText.implicitHeight + PaperTheme.pick(10, 4, 4)

                // The change bar — the same mark a selected list row takes.
                PaperRule {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    visible: lineItem.isCurrent && root.markCurrent
                    vertical: true
                    weight: "mark"
                    tone: "accent"
                }

                PaperText {
                    id: lineText
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: (lineItem.isCurrent && root.markCurrent) ? PaperTheme.changeBarIndent : 0
                    horizontalAlignment: Text.AlignLeft
                    wrapMode: Text.WordWrap
                    text: (lineItem.modelData.text && lineItem.modelData.text.length > 0) ? lineItem.modelData.text : "…"
                    font.family: root.lyricFamily
                    font.pixelSize: lineItem.isCurrent ? root.currentSize : root.restSize
                    // Only B sets the current line in bold ("Charter 15 bold");
                    // A has no bold at all and C leans on size and the bar.
                    font.weight: (lineItem.isCurrent && PaperTheme.isLedger) ? PaperTheme.font.weight.bold : PaperTheme.font.weight.normal
                    tone: lineItem.isCurrent ? "ink" : (lineItem.isPast ? "ink4" : "ink3")
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: (root.player?.canSeek ?? false) ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: {
                        if (root.player?.canSeek) {
                            root.player.position = lineItem.modelData.time;
                            root._refreshPosition();
                            root.userScrolling = false;
                            Qt.callLater(root.centerCurrent);
                        }
                    }
                }
            }

            // Wheel handling that marks user interaction without stealing clicks.
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.NoButton
                onWheel: wheel => {
                    root._markUserScroll();
                    const maxY = Math.max(0, lyricsList.contentHeight - lyricsList.height);
                    lyricsList.contentY = Math.max(0, Math.min(maxY, lyricsList.contentY - wheel.angleDelta.y));
                    wheel.accepted = true;
                }
            }
        }

        // ---- plain (unsynced) lyrics -------------------------------------
        Flickable {
            id: plainFlick
            anchors.fill: parent
            visible: !root.synced && LyricsService.plainLyrics.length > 0
            contentHeight: plainText.implicitHeight + PaperTheme.spacing.medium
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            PaperText {
                id: plainText
                width: plainFlick.width
                wrapMode: Text.WordWrap
                role: "small"
                tone: "ink2"
                font.family: root.lyricFamily
                lineHeight: 1.6
                text: LyricsService.plainLyrics
            }
        }
    }
}
