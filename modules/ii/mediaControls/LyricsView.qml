pragma ComponentBehavior: Bound
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.services
import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Mpris

Item { // Live lyrics panel
    id: root
    required property MprisPlayer player
    required property QtObject colors

    property real position: 0
    property bool userScrolling: false
    property bool _programmatic: false
    // When true, the next placement snaps instead of animating (used on open / new
    // lyrics so the panel appears already focused on the current line).
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
        const to = lyricsList.contentY; // positionViewAtIndex already moved contentY here
        if (root._instant) {
            // First placement after opening / new lyrics: snap, don't animate.
            root._instant = false;
            scrollAnim.stop();
            return;
        }
        if (Math.abs(to - from) < 1) return;
        lyricsList.contentY = from; // rewind, then animate to target
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

    // Snap (don't animate) to the current line whenever the panel (re)appears.
    onVisibleChanged: {
        if (visible) {
            root._instant = true;
            root._refreshPosition();
            Qt.callLater(root.centerCurrent);
        }
    }

    // Reset and re-center whenever a fresh set of lyrics arrives.
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

    // ---- Status / placeholder states ----
    StyledText {
        anchors.centerIn: parent
        width: parent.width - 40
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap
        color: root.colors.colSubtext
        font.pixelSize: Appearance.font.pixelSize.normal
        visible: !root.synced && LyricsService.plainLyrics.length === 0
        text: {
            switch (LyricsService.status) {
            case "loading": return Translation.tr("Searching for lyrics…");
            case "notfound": return Translation.tr("No lyrics found");
            case "error": return Translation.tr("Couldn't load lyrics");
            default:
                return LyricsService.instrumental ? Translation.tr("♪ Instrumental") : "";
            }
        }
    }

    // ---- Synced lyrics ----
    ListView {
        id: lyricsList
        anchors.fill: parent
        anchors.leftMargin: 13
        anchors.rightMargin: 13
        visible: root.synced
        clip: true
        interactive: true
        boundsBehavior: Flickable.DragOverBounds
        maximumFlickVelocity: 3500
        cacheBuffer: 600
        spacing: 2
        // Pad so the first/last lines can reach vertical center
        header: Item { width: 1; height: lyricsList.height / 2 }
        footer: Item { width: 1; height: lyricsList.height / 2 }

        model: LyricsService.lines

        onMovementStarted: root._markUserScroll()
        onDraggingChanged: if (dragging) root._markUserScroll()

        NumberAnimation {
            id: scrollAnim
            target: lyricsList
            property: "contentY"
            duration: Appearance.animation.elementMove.numberAnimation.duration ?? 400
            easing.type: Easing.OutCubic
        }

        delegate: Item {
            id: lineItem
            required property int index
            required property var modelData
            readonly property bool isCurrent: index === root.currentIndex
            readonly property bool isPast: root.currentIndex >= 0 && index < root.currentIndex
            width: lyricsList.width
            implicitHeight: lineText.implicitHeight + 8

            StyledText {
                id: lineText
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                horizontalAlignment: Text.AlignLeft
                wrapMode: Text.WordWrap
                text: (lineItem.modelData.text && lineItem.modelData.text.length > 0)
                    ? lineItem.modelData.text : "♪"
                font.pixelSize: lineItem.isCurrent
                    ? Appearance.font.pixelSize.large : Appearance.font.pixelSize.normal
                font.weight: lineItem.isCurrent ? Font.Bold : Font.Medium
                color: lineItem.isCurrent ? root.colors.colPrimary : root.colors.colOnLayer0
                opacity: lineItem.isCurrent ? 1 : (lineItem.isPast ? 0.38 : 0.55)

                Behavior on opacity {
                    animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                }
                Behavior on font.pixelSize {
                    animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                }
                Behavior on color {
                    animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
                }
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

        // Wheel handling that marks user interaction without stealing clicks
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
    StyledFlickable {
        id: plainFlick
        anchors.fill: parent
        anchors.leftMargin: 13
        anchors.rightMargin: 13
        visible: !root.synced && LyricsService.plainLyrics.length > 0
        contentHeight: plainText.implicitHeight + 20
        clip: true

        StyledText {
            id: plainText
            width: plainFlick.width
            wrapMode: Text.WordWrap
            color: root.colors.colOnLayer0
            opacity: 0.75
            font.pixelSize: Appearance.font.pixelSize.normal
            text: LyricsService.plainLyrics
        }
    }

    // ---- Source attribution ----
    StyledText {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 6
        visible: LyricsService.status === "found" && LyricsService.source.length > 0
        color: root.colors.colSubtext
        opacity: 0.5
        font.pixelSize: Appearance.font.pixelSize.smaller
        text: LyricsService.source
    }
}
