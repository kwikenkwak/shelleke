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
 * Media Controls panel WITH LYRICS for the pixel family — a strictly monochrome,
 * hard-edged restyle of `modules/ii/mediaControls/MediaControls.qml`. The ONLY
 * color exception is the album art image.
 *
 * Window / open / close / IPC / GlobalShortcut structure mirrors the ii media
 * controls exactly (gated by GlobalStates.mediaControlsOpen, HyprlandFocusGrab
 * click-away, Escape to close, same IPC target + shortcut names) so the user's
 * existing keybinds keep working. Only the LOOK changes.
 */
Scope {
    id: root

    readonly property MprisPlayer activePlayer: MprisController.activePlayer

    function hide() {
        GlobalStates.mediaControlsOpen = false;
    }

    PanelWindow {
        id: mediaRoot
        visible: GlobalStates.mediaControlsOpen

        exclusionMode: ExclusionMode.Ignore
        exclusiveZone: 0
        implicitWidth: contentLoader.implicitWidth
        implicitHeight: contentLoader.implicitHeight
        color: "transparent"
        WlrLayershell.namespace: "quickshell:pixelMediaControls"

        // Anchored top-left under the bar, like the ii popup's default placement.
        anchors {
            top: true
            left: true
        }
        // Open under the media title in the bar (its scene x is published by the
        // bar on click), clamped so the panel stays on-screen.
        margins {
            top: PixTheme.barHeight + 8
            left: Math.max(12, Math.min(GlobalStates.mediaControlsX,
                (mediaRoot.screen?.width ?? 1920) - mediaRoot.implicitWidth - 12))
        }

        HyprlandFocusGrab {
            id: grab
            windows: [mediaRoot]
            active: GlobalStates.mediaControlsOpen
            onCleared: () => {
                if (!active)
                    root.hide();
            }
        }

        Loader {
            id: contentLoader
            active: GlobalStates.mediaControlsOpen
            anchors.fill: parent

            focus: GlobalStates.mediaControlsOpen
            Keys.onPressed: (event) => {
                if (event.key === Qt.Key_Escape) {
                    root.hide();
                    event.accepted = true;
                }
            }

            sourceComponent: PixPanel {
                id: panel
                borderWidth: PixTheme.popupBorderWidth
                implicitWidth: 360
                implicitHeight: contentColumn.implicitHeight + 32

                readonly property MprisPlayer player: root.activePlayer
                readonly property bool hasPlayer: player !== null

                ColumnLayout {
                    id: contentColumn
                    // Anchor top/left/right (NOT fill) so the column is sized by
                    // its content; the panel's implicitHeight derives from it
                    // without a binding loop (the bug that collapsed the panel to
                    // just the album art).
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.margins: 16
                    spacing: 14

                    // ---- No-player placeholder ----
                    PixText {
                        Layout.fillWidth: true
                        visible: !panel.hasPlayer
                        text: "No active player"
                        color: PixTheme.colors.grey
                        font.pixelSize: PixTheme.font.pixelSize.large
                        horizontalAlignment: Text.AlignHCenter
                    }

                    // ---- Track header: album art + title/artist ----
                    RowLayout {
                        Layout.fillWidth: true
                        visible: panel.hasPlayer
                        spacing: 16

                        // Album art — the ONE sanctioned color exception. Plain
                        // Image (not PixAppIcon), hard-bordered square frame.
                        PixPanel {
                            id: artFrame
                            Layout.alignment: Qt.AlignTop
                            borderWidth: PixTheme.borderWidth
                            implicitWidth: 76
                            implicitHeight: 76

                            Image {
                                id: art
                                anchors.fill: parent
                                anchors.margins: PixTheme.borderWidth
                                visible: source != "" && status === Image.Ready
                                source: panel.player?.trackArtUrl ?? ""
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                smooth: false
                                mipmap: false
                                cache: true
                            }

                            PixIcon {
                                anchors.centerIn: parent
                                visible: !art.visible
                                name: "note"
                                size: 28
                                color: PixTheme.colors.grey
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            spacing: 6

                            PixTitle {
                                Layout.fillWidth: true
                                text: StringUtils.cleanMusicTitle(panel.player?.trackTitle) || "Untitled"
                                font.pixelSize: PixTheme.font.pixelSize.title
                                elide: Text.ElideRight
                            }
                            PixText {
                                Layout.fillWidth: true
                                text: panel.player?.trackArtist ?? ""
                                color: PixTheme.colors.grey
                                font.pixelSize: PixTheme.font.pixelSize.normal
                                elide: Text.ElideRight
                            }
                        }
                    }

                    // ---- Pixel progress bar (discrete filled/hollow cells) ----
                    ColumnLayout {
                        Layout.fillWidth: true
                        visible: panel.hasPlayer
                        spacing: 6

                        Item {
                            id: progress
                            Layout.fillWidth: true
                            implicitHeight: 14

                            readonly property real len: panel.player?.length ?? 0
                            readonly property real pos: panel.player?.position ?? 0
                            readonly property real fraction: len > 0
                                ? Math.max(0, Math.min(1, pos / len)) : 0
                            // Discrete cells across the available width.
                            readonly property int cellW: 8
                            readonly property int gap: 3
                            readonly property int cellCount: Math.max(1,
                                Math.floor((width + gap) / (cellW + gap)))
                            readonly property int filled: Math.round(fraction * cellCount)

                            // Force position to refresh while playing so cells advance.
                            Timer {
                                running: (panel.player?.isPlaying ?? false)
                                    && mediaRoot.visible
                                interval: 1000
                                repeat: true
                                onTriggered: panel.player?.positionChanged()
                            }

                            Row {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: progress.gap

                                Repeater {
                                    model: progress.cellCount
                                    delegate: Rectangle {
                                        required property int index
                                        width: progress.cellW
                                        height: 14
                                        radius: 0
                                        antialiasing: false
                                        color: index < progress.filled
                                            ? PixTheme.colors.fg : "transparent"
                                        border.width: index < progress.filled
                                            ? 0 : PixTheme.borderWidth
                                        border.color: PixTheme.colors.line
                                    }
                                }
                            }
                        }

                        // Position / length timestamps.
                        RowLayout {
                            Layout.fillWidth: true
                            PixText {
                                text: StringUtils.friendlyTimeForSeconds(panel.player?.position ?? 0)
                                color: PixTheme.colors.grey
                                font.pixelSize: PixTheme.font.pixelSize.smaller
                            }
                            Item { Layout.fillWidth: true }
                            PixText {
                                text: StringUtils.friendlyTimeForSeconds(panel.player?.length ?? 0)
                                color: PixTheme.colors.grey
                                font.pixelSize: PixTheme.font.pixelSize.smaller
                            }
                        }
                    }

                    // ---- Transport controls ----
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignHCenter
                        visible: panel.hasPlayer
                        spacing: 10

                        Item { Layout.fillWidth: true }

                        // Previous
                        PixButton {
                            id: prevBtn
                            implicitWidth: 46
                            implicitHeight: 38
                            onClicked: MprisController.previous()
                            PixIcon {
                                anchors.centerIn: parent
                                name: "chevL"
                                size: 14
                                color: prevBtn.contentColor
                            }
                        }

                        // Play / pause — drawn glyphs bound to contentColor.
                        PixButton {
                            id: playBtn
                            implicitWidth: 46
                            implicitHeight: 38
                            onClicked: MprisController.togglePlaying()

                            // Pause: two bars
                            Row {
                                anchors.centerIn: parent
                                visible: MprisController.isPlaying
                                spacing: 4
                                Repeater {
                                    model: 2
                                    delegate: Rectangle {
                                        width: 4
                                        height: 16
                                        radius: 0
                                        antialiasing: false
                                        color: playBtn.contentColor
                                    }
                                }
                            }

                            // Play: filled triangle
                            Canvas {
                                id: playGlyph
                                anchors.centerIn: parent
                                visible: !MprisController.isPlaying
                                width: 16
                                height: 16
                                antialiasing: false
                                onPaint: {
                                    const ctx = getContext("2d");
                                    ctx.reset();
                                    ctx.fillStyle = playBtn.contentColor;
                                    ctx.beginPath();
                                    ctx.moveTo(2, 0);
                                    ctx.lineTo(15, 8);
                                    ctx.lineTo(2, 16);
                                    ctx.closePath();
                                    ctx.fill();
                                }
                                Connections {
                                    target: playBtn
                                    function onContentColorChanged() { playGlyph.requestPaint(); }
                                }
                            }
                        }

                        // Next
                        PixButton {
                            id: nextBtn
                            implicitWidth: 46
                            implicitHeight: 38
                            onClicked: MprisController.next()
                            PixIcon {
                                anchors.centerIn: parent
                                name: "chevR"
                                size: 14
                                color: nextBtn.contentColor
                            }
                        }

                        Item { Layout.fillWidth: true }
                    }

                    // ---- Divider ----
                    Rectangle {
                        Layout.fillWidth: true
                        visible: panel.hasPlayer
                        implicitHeight: PixTheme.borderWidth
                        color: PixTheme.colors.line
                        antialiasing: false
                    }

                    // ---- Lyrics ----
                    PixLyricsView {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 200
                        visible: panel.hasPlayer
                        player: panel.player
                    }
                }
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
