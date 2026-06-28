pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.Mpris
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.pixel.common
import qs.modules.pixel.widgets

/**
 * Media controls WITH LYRICS for the pixel family — a strictly monochrome,
 * hard-edged restyle of `modules/ii/mediaControls/MediaControls.qml` +
 * `PlayerControl.qml`. The window/positioning/expansion mechanism is copied
 * from ii verbatim; ONLY the visual styling changes. The one color exception
 * is the album art image.
 *
 * Expansion (ii's trick to avoid surface-resize flicker): the layer-shell
 * surface stays a FIXED height (player + lyrics); only the inner card animates
 * its height, and the lyrics sit at a fixed position revealed/clipped by it.
 */
Scope {
    id: root

    readonly property MprisPlayer activePlayer: MprisController.activePlayer
    readonly property real widgetWidth: 460
    readonly property real playerHeight: 170
    readonly property real lyricsPanelHeight: 210
    readonly property bool lyricsEnabled: Config.options.media.lyrics.enabled
    readonly property bool lyricsShown: root.lyricsEnabled && Config.options.media.lyrics.show

    function hide() {
        GlobalStates.mediaControlsOpen = false;
    }

    PanelWindow {
        id: mediaRoot
        visible: GlobalStates.mediaControlsOpen

        exclusionMode: ExclusionMode.Ignore
        exclusiveZone: 0
        color: "transparent"
        WlrLayershell.namespace: "quickshell:pixelMediaControls"

        implicitWidth: root.widgetWidth
        // FIXED surface height (never animates) — see header.
        implicitHeight: root.playerHeight + (root.lyricsEnabled ? root.lyricsPanelHeight : 0)

        // Positioning copied from ii MediaControls (non-vertical bar case).
        anchors {
            top: !(Config.options.bar.bottom ?? false)
            bottom: (Config.options.bar.bottom ?? false)
            left: true
        }
        margins {
            top: PixTheme.barHeight
            bottom: PixTheme.barHeight
            left: (mediaRoot.screen.width / 2) - (Appearance.sizes.osdWidth / 2) - root.widgetWidth
        }

        // Only the visible card is interactive; the (transparent) area below it
        // stays click-through, and clicking there dismisses via the focus grab.
        mask: Region {
            item: card
        }

        HyprlandFocusGrab {
            windows: [mediaRoot]
            active: GlobalStates.mediaControlsOpen
            onCleared: () => {
                if (!active)
                    root.hide();
            }
        }

        PixPanel {
            id: card
            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
            }
            borderWidth: PixTheme.popupBorderWidth
            clip: true
            focus: GlobalStates.mediaControlsOpen
            Keys.onPressed: (event) => {
                if (event.key === Qt.Key_Escape) {
                    root.hide();
                    event.accepted = true;
                }
            }

            // Only the card animates; the surface stays fixed.
            height: root.lyricsShown ? (root.playerHeight + root.lyricsPanelHeight) : root.playerHeight
            Behavior on height {
                NumberAnimation {
                    duration: 300
                    easing.type: Easing.OutCubic
                }
            }

            readonly property MprisPlayer player: root.activePlayer
            readonly property bool hasPlayer: player !== null

            // ---- No-player placeholder ----
            PixText {
                anchors.centerIn: parent
                visible: !card.hasPlayer
                text: "No active player"
                color: PixTheme.colors.grey
                font.pixelSize: PixTheme.font.pixelSize.large
            }

            // ---- Player area (fixed height, pinned to the top) ----
            RowLayout {
                id: playerArea
                anchors {
                    top: parent.top
                    left: parent.left
                    right: parent.right
                    topMargin: 14
                    leftMargin: 16
                    rightMargin: 16
                }
                // Bounded so content never extends past the fixed card height.
                height: root.playerHeight - 28
                visible: card.hasPlayer
                spacing: 14

                // Album art — the ONE sanctioned color exception. Fixed size.
                PixPanel {
                    id: artFrame
                    Layout.preferredWidth: root.playerHeight - 28
                    Layout.preferredHeight: root.playerHeight - 28
                    Layout.alignment: Qt.AlignVCenter
                    borderWidth: PixTheme.borderWidth

                    Image {
                        id: art
                        anchors.fill: parent
                        anchors.margins: PixTheme.borderWidth
                        visible: status === Image.Ready
                        source: card.player?.trackArtUrl ?? ""
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        cache: true
                        smooth: false
                        mipmap: false
                    }
                    PixIcon {
                        anchors.centerIn: parent
                        visible: !art.visible
                        name: "note"
                        size: 28
                        color: PixTheme.colors.grey
                    }
                }

                // Info + controls
                ColumnLayout {
                    Layout.fillHeight: true
                    Layout.fillWidth: true
                    spacing: 8

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0
                    RowLayout { // title + lyrics toggle
                        Layout.fillWidth: true
                        spacing: 8
                        PixTitle {
                            Layout.fillWidth: true
                            text: StringUtils.cleanMusicTitle(card.player?.trackTitle) || "Untitled"
                            font.pixelSize: PixTheme.font.pixelSize.title
                            elide: Text.ElideRight
                        }
                        PixButton {
                            id: lyricsToggle
                            visible: root.lyricsEnabled
                            implicitWidth: 30
                            implicitHeight: 26
                            filled: root.lyricsShown
                            onClicked: Config.options.media.lyrics.show = !Config.options.media.lyrics.show
                            PixIcon {
                                anchors.centerIn: parent
                                name: "message"
                                size: 14
                                color: lyricsToggle.contentColor
                            }
                        }
                    }
                    PixText {
                        Layout.fillWidth: true
                        text: card.player?.trackArtist ?? ""
                        color: PixTheme.colors.grey
                        font.pixelSize: PixTheme.font.pixelSize.normal
                        elide: Text.ElideRight
                    }
                }

                    Item { Layout.fillHeight: true } // spacer

                    // Time
                    PixText {
                        text: `${StringUtils.friendlyTimeForSeconds(card.player?.position ?? 0)} / ${StringUtils.friendlyTimeForSeconds(card.player?.length ?? 0)}`
                        color: PixTheme.colors.grey
                        font.pixelSize: PixTheme.font.pixelSize.smaller
                    }

                    // Pixel progress bar (discrete cells, click to seek)
                    Item {
                        id: progress
                        Layout.fillWidth: true
                        implicitHeight: 12

                        readonly property real len: card.player?.length ?? 0
                        readonly property real pos: card.player?.position ?? 0
                        readonly property real fraction: len > 0 ? Math.max(0, Math.min(1, pos / len)) : 0
                        readonly property int cellW: 7
                        readonly property int gap: 3
                        readonly property int cellCount: Math.max(1, Math.floor((width + gap) / (cellW + gap)))
                        readonly property int filled: Math.round(fraction * cellCount)

                        Timer { // advance cells while playing
                            running: (card.player?.isPlaying ?? false) && mediaRoot.visible
                            interval: 1000
                            repeat: true
                            onTriggered: card.player?.positionChanged()
                        }

                        Row {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: progress.gap
                            Repeater {
                                model: progress.cellCount
                                delegate: Rectangle {
                                    required property int index
                                    width: progress.cellW
                                    height: 12
                                    radius: 0
                                    antialiasing: false
                                    color: index < progress.filled ? PixTheme.colors.fg : "transparent"
                                    border.width: index < progress.filled ? 0 : PixTheme.borderWidth
                                    border.color: PixTheme.colors.line
                                }
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            enabled: card.player?.canSeek ?? false
                            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                            onClicked: (mouse) => {
                                if (card.player && progress.len > 0)
                                    card.player.position = (mouse.x / width) * progress.len;
                            }
                        }
                    }

                    // Transport controls
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10

                        PixButton {
                            id: prevBtn
                            implicitWidth: 44
                            implicitHeight: 32
                            onClicked: MprisController.previous()
                            PixIcon { anchors.centerIn: parent; name: "chevL"; size: 14; color: prevBtn.contentColor }
                        }
                        PixButton {
                            id: playBtn
                            Layout.fillWidth: true
                            implicitHeight: 32
                            onClicked: MprisController.togglePlaying()
                            // Pause: two bars
                            Row {
                                anchors.centerIn: parent
                                visible: MprisController.isPlaying
                                spacing: 4
                                Repeater {
                                    model: 2
                                    delegate: Rectangle { width: 4; height: 14; radius: 0; antialiasing: false; color: playBtn.contentColor }
                                }
                            }
                            // Play: triangle
                            Canvas {
                                id: playGlyph
                                anchors.centerIn: parent
                                visible: !MprisController.isPlaying
                                width: 14
                                height: 14
                                antialiasing: false
                                onPaint: {
                                    const ctx = getContext("2d");
                                    ctx.reset();
                                    ctx.fillStyle = playBtn.contentColor;
                                    ctx.beginPath();
                                    ctx.moveTo(2, 0);
                                    ctx.lineTo(13, 7);
                                    ctx.lineTo(2, 14);
                                    ctx.closePath();
                                    ctx.fill();
                                }
                                Connections {
                                    target: playBtn
                                    function onContentColorChanged() { playGlyph.requestPaint(); }
                                }
                            }
                        }
                        PixButton {
                            id: nextBtn
                            implicitWidth: 44
                            implicitHeight: 32
                            onClicked: MprisController.next()
                            PixIcon { anchors.centerIn: parent; name: "chevR"; size: 14; color: nextBtn.contentColor }
                        }
                    }
                }
            }

            // ---- Divider between player and lyrics ----
            Rectangle {
                anchors {
                    left: parent.left
                    right: parent.right
                    top: parent.top
                    topMargin: root.playerHeight
                }
                visible: card.hasPlayer && card.height > root.playerHeight + 1
                height: PixTheme.borderWidth
                color: PixTheme.colors.line
                antialiasing: false
            }

            // ---- Lyrics (fixed position, revealed by the animating card) ----
            PixLyricsView {
                anchors {
                    left: parent.left
                    right: parent.right
                    leftMargin: 16
                    rightMargin: 16
                }
                y: root.playerHeight + PixTheme.borderWidth + 6
                height: root.lyricsPanelHeight - PixTheme.borderWidth - 16
                // Mounted through the reveal/collapse animation; hidden once collapsed.
                visible: card.hasPlayer && card.height > root.playerHeight + 1
                player: card.player
            }
        }
    }

    // Same IPC target + GlobalShortcut names as the ii media controls so the
    // user's existing keybinds keep working.
    IpcHandler {
        target: "mediaControls"

        function toggle(): void {
            GlobalStates.mediaControlsOpen = !GlobalStates.mediaControlsOpen;
        }
        function close(): void {
            GlobalStates.mediaControlsOpen = false;
        }
        function open(): void {
            GlobalStates.mediaControlsOpen = true;
        }
    }

    GlobalShortcut {
        name: "mediaControlsToggle"
        description: "Toggles media controls on press"
        onPressed: GlobalStates.mediaControlsOpen = !GlobalStates.mediaControlsOpen
    }
    GlobalShortcut {
        name: "mediaControlsOpen"
        description: "Opens media controls on press"
        onPressed: GlobalStates.mediaControlsOpen = true
    }
    GlobalShortcut {
        name: "mediaControlsClose"
        description: "Closes media controls on press"
        onPressed: GlobalStates.mediaControlsOpen = false
    }
}
