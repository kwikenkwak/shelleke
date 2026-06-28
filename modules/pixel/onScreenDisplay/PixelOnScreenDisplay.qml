import qs
import qs.services
import qs.modules.common
import qs.modules.pixel.common
import qs.modules.pixel.widgets
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

/**
 * PixelOnScreenDisplay — monochrome volume + brightness OSD.
 *
 * Gated on GlobalStates.osdVolumeOpen / GlobalStates.osdBrightnessOpen (mirrors
 * modules/ii/onScreenDisplay). A small top-center PixPanel shows the relevant
 * PixIcon (speaker / sun) plus a discrete pixel bar meter (filled vs hollow
 * cells) and the numeric percent. Auto-hides on the same osd.timeout the ii OSD
 * uses; hovering the panel dismisses it immediately.
 */
Scope {
    id: root
    property var focusedScreen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name)

    // "volume" | "brightness" — which meter to show.
    property string currentIndicator: "volume"
    readonly property bool anyOpen: GlobalStates.osdVolumeOpen || GlobalStates.osdBrightnessOpen

    property var brightnessMonitor: Brightness.getMonitorForScreen(root.focusedScreen)

    readonly property bool muted: Audio.sink?.audio?.muted ?? false
    readonly property real volumeValue: Audio.sink?.audio?.volume ?? 0
    readonly property real brightnessValue: root.brightnessMonitor?.brightness ?? 0

    readonly property real shownValue: root.currentIndicator === "brightness"
        ? root.brightnessValue : root.volumeValue
    readonly property string shownIcon: root.currentIndicator === "brightness"
        ? "sun" : (root.muted ? "flashoff" : "speaker")
    readonly property string shownLabel: root.currentIndicator === "brightness"
        ? Translation.tr("Brightness") : Translation.tr("Volume")

    function triggerVolume() {
        root.currentIndicator = "volume";
        GlobalStates.osdBrightnessOpen = false;
        GlobalStates.osdVolumeOpen = true;
        osdTimeout.restart();
    }

    function triggerBrightness() {
        root.currentIndicator = "brightness";
        GlobalStates.osdVolumeOpen = false;
        GlobalStates.osdBrightnessOpen = true;
        osdTimeout.restart();
    }

    Timer {
        id: osdTimeout
        interval: Config.options?.osd?.timeout ?? 1000
        repeat: false
        running: false
        onTriggered: {
            GlobalStates.osdVolumeOpen = false;
            GlobalStates.osdBrightnessOpen = false;
        }
    }

    // Keep the timer alive while open (e.g. when toggled via IPC).
    onAnyOpenChanged: {
        if (root.anyOpen)
            osdTimeout.restart();
    }

    Connections {
        target: Brightness
        function onBrightnessChanged() {
            root.triggerBrightness();
        }
    }

    Connections {
        target: Audio.sink?.audio ?? null
        function onVolumeChanged() {
            if (!Audio.ready)
                return;
            root.triggerVolume();
        }
        function onMutedChanged() {
            if (!Audio.ready)
                return;
            root.triggerVolume();
        }
    }

    Loader {
        id: osdLoader
        active: root.anyOpen

        sourceComponent: PanelWindow {
            id: osdRoot
            color: "transparent"

            screen: root.focusedScreen
            Connections {
                target: root
                function onFocusedScreenChanged() {
                    osdRoot.screen = root.focusedScreen;
                }
            }

            WlrLayershell.namespace: "quickshell:pixelOnScreenDisplay"
            WlrLayershell.layer: WlrLayer.Overlay
            anchors {
                top: !(Config.options?.bar?.bottom ?? false)
                bottom: Config.options?.bar?.bottom ?? false
            }
            exclusionMode: ExclusionMode.Ignore
            exclusiveZone: 0
            margins {
                top: PixTheme.barHeight + 14
                bottom: PixTheme.barHeight + 14
            }

            implicitWidth: osdPanel.implicitWidth
            implicitHeight: osdPanel.implicitHeight
            visible: osdLoader.active

            mask: Region {
                item: osdPanel
            }

            PixPanel {
                id: osdPanel
                anchors.horizontalCenter: parent.horizontalCenter
                borderWidth: PixTheme.popupBorderWidth
                implicitWidth: osdRow.implicitWidth + 28
                implicitHeight: osdRow.implicitHeight + 22

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    onEntered: {
                        GlobalStates.osdVolumeOpen = false;
                        GlobalStates.osdBrightnessOpen = false;
                    }
                }

                RowLayout {
                    id: osdRow
                    anchors.centerIn: parent
                    spacing: 14

                    PixIcon {
                        Layout.alignment: Qt.AlignVCenter
                        name: root.shownIcon
                        size: 21
                    }

                    ColumnLayout {
                        Layout.alignment: Qt.AlignVCenter
                        spacing: 8

                        RowLayout {
                            Layout.fillWidth: true
                            PixText {
                                Layout.fillWidth: true
                                font.bold: true
                                font.pixelSize: PixTheme.font.pixelSize.normal
                                text: root.shownLabel
                            }
                            PixText {
                                font.bold: true
                                font.pixelSize: PixTheme.font.pixelSize.normal
                                horizontalAlignment: Text.AlignRight
                                text: Math.round(root.shownValue * 100) + "%"
                            }
                        }

                        // Discrete pixel bar meter: 20 cells, filled up to value.
                        Row {
                            id: meter
                            Layout.alignment: Qt.AlignVCenter
                            spacing: 3
                            readonly property int cellCount: 20
                            readonly property int filledCells:
                                Math.round(Math.max(0, Math.min(1, root.shownValue)) * cellCount)

                            Repeater {
                                model: meter.cellCount
                                delegate: Rectangle {
                                    required property int index
                                    width: 9
                                    height: 16
                                    radius: 0
                                    antialiasing: false
                                    color: index < meter.filledCells
                                        ? PixTheme.colors.fg : "transparent"
                                    border.width: PixTheme.borderWidth
                                    border.color: PixTheme.colors.line
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    IpcHandler {
        target: "pixelOsdVolume"
        function trigger() {
            root.triggerVolume();
        }
        function hide() {
            GlobalStates.osdVolumeOpen = false;
            GlobalStates.osdBrightnessOpen = false;
        }
        function toggle() {
            if (root.anyOpen) {
                GlobalStates.osdVolumeOpen = false;
                GlobalStates.osdBrightnessOpen = false;
            } else {
                root.triggerVolume();
            }
        }
    }
    IpcHandler {
        target: "pixelOsdBrightness"
        function trigger() {
            root.triggerBrightness();
        }
        function hide() {
            GlobalStates.osdVolumeOpen = false;
            GlobalStates.osdBrightnessOpen = false;
        }
    }
    GlobalShortcut {
        name: "pixelOsdVolumeTrigger"
        description: "Triggers pixel volume OSD on press"
        onPressed: root.triggerVolume()
    }
    GlobalShortcut {
        name: "pixelOsdBrightnessTrigger"
        description: "Triggers pixel brightness OSD on press"
        onPressed: root.triggerBrightness()
    }
    GlobalShortcut {
        name: "pixelOsdHide"
        description: "Hides pixel OSD on press"
        onPressed: {
            GlobalStates.osdVolumeOpen = false;
            GlobalStates.osdBrightnessOpen = false;
        }
    }
}
