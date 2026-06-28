pragma ComponentBehavior: Bound
import QtQuick
import Quickshell.Services.Mpris
import qs.services
import qs.modules.pixel.common
import qs.modules.pixel.widgets

/**
 * Monochrome lyrics panel for the pixel media controls. Mirrors the highlight /
 * auto-scroll behavior of `modules/ii/mediaControls/LyricsView.qml` but styled in
 * the pixel idiom (current line bold + fg, past lines fainter grey, upcoming grey).
 *
 * Highlight: LyricsService.indexForPosition(position) gives the index of the
 * active synced line (binary search over LyricsService.lines, each {time, text}).
 * Scroll: whenever the current index changes we positionViewAtIndex(idx, Center)
 * and animate contentY toward it, unless the user is manually scrolling (in which
 * case auto-scroll resumes a few seconds later).
 */
Item {
    id: root
    required property MprisPlayer player

    property real position: 0
    property bool userScrolling: false
    property bool _instant: true

    readonly property bool synced: LyricsService.synced
    readonly property int currentIndex: root.synced ? LyricsService.indexForPosition(root.position) : -1

    function _refreshPosition() {
        if (!root.player) return;
        root.player.positionChanged();
        root.position = root.player.position ?? 0;
    }

    function centerCurrent() {
        if (root.userScrolling || lyricsList.count === 0) return;
        const idx = root.currentIndex;
        if (idx < 0) return;
        const from = lyricsList.contentY;
        lyricsList.positionViewAtIndex(idx, ListView.Center);
        const to = lyricsList.contentY;
        if (root._instant) {
            root._instant = false;
            scrollAnim.stop();
            return;
        }
        if (Math.abs(to - from) < 1) return;
        lyricsList.contentY = from;
        scrollAnim.from = from;
        scrollAnim.to = to;
        scrollAnim.restart();
    }

    function _markUserScroll() {
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
        function onLinesChanged() {
            root.userScrolling = false;
            root._instant = true;
            lyricsList.contentY = 0;
            root._refreshPosition();
            Qt.callLater(root.centerCurrent);
        }
    }

    Connections {
        target: root.player
        function onPositionChanged() { root.position = root.player?.position ?? 0; }
    }

    Timer { // Fine-grained position polling for smooth line tracking
        running: (root.player?.isPlaying ?? false) && root.synced && root.visible
        interval: 250
        repeat: true
        onTriggered: root._refreshPosition()
    }

    Timer { // Resume auto-scroll a few seconds after the user stops scrolling
        id: resumeTimer
        interval: 4000
        repeat: false
        onTriggered: {
            root.userScrolling = false;
            root.centerCurrent();
        }
    }

    // ---- Status / placeholder ----
    PixText {
        anchors.centerIn: parent
        width: parent.width - 20
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap
        color: PixTheme.colors.grey
        font.pixelSize: PixTheme.font.pixelSize.normal
        visible: !root.synced && LyricsService.plainLyrics.length === 0
        text: {
            switch (LyricsService.status) {
            case "loading": return "Searching for lyrics...";
            case "notfound": return "No lyrics";
            case "error": return "Couldn't load lyrics";
            default:
                return LyricsService.instrumental ? "Instrumental" : "No lyrics";
            }
        }
    }

    // ---- Synced lyrics ----
    ListView {
        id: lyricsList
        anchors.fill: parent
        visible: root.synced
        clip: true
        interactive: true
        boundsBehavior: Flickable.DragOverBounds
        maximumFlickVelocity: 3500
        cacheBuffer: 600
        spacing: 4
        // Pad so the first/last lines can reach vertical center.
        header: Item { width: 1; height: lyricsList.height / 2 }
        footer: Item { width: 1; height: lyricsList.height / 2 }

        model: LyricsService.lines

        onMovementStarted: root._markUserScroll()
        onDraggingChanged: if (dragging) root._markUserScroll()

        NumberAnimation {
            id: scrollAnim
            target: lyricsList
            property: "contentY"
            duration: 400
            easing.type: Easing.OutCubic
        }

        delegate: Item {
            id: lineItem
            required property int index
            required property var modelData
            readonly property bool isCurrent: index === root.currentIndex
            readonly property bool isPast: root.currentIndex >= 0 && index < root.currentIndex
            width: lyricsList.width
            implicitHeight: lineText.implicitHeight + 6

            PixText {
                id: lineText
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                horizontalAlignment: Text.AlignLeft
                wrapMode: Text.WordWrap
                text: (lineItem.modelData.text && lineItem.modelData.text.length > 0)
                    ? lineItem.modelData.text : "..."
                font.pixelSize: lineItem.isCurrent
                    ? PixTheme.font.pixelSize.large : PixTheme.font.pixelSize.normal
                font.bold: lineItem.isCurrent
                color: lineItem.isCurrent ? PixTheme.colors.fg
                    : (lineItem.isPast ? PixTheme.colors.grey2 : PixTheme.colors.grey)
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
            onWheel: (wheel) => {
                root._markUserScroll();
                const maxY = Math.max(0, lyricsList.contentHeight - lyricsList.height);
                lyricsList.contentY = Math.max(0, Math.min(maxY, lyricsList.contentY - wheel.angleDelta.y));
                wheel.accepted = true;
            }
        }
    }

    // ---- Plain (unsynced) lyrics ----
    Flickable {
        id: plainFlick
        anchors.fill: parent
        visible: !root.synced && LyricsService.plainLyrics.length > 0
        contentHeight: plainText.implicitHeight + 12
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        PixText {
            id: plainText
            width: plainFlick.width
            wrapMode: Text.WordWrap
            color: PixTheme.colors.grey
            font.pixelSize: PixTheme.font.pixelSize.normal
            text: LyricsService.plainLyrics
        }
    }
}
