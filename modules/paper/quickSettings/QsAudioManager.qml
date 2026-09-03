pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.services
import qs.modules.paper.common
import qs.modules.paper.widgets

/**
 * The audio management overlay — the same shell as QsWifiManager and
 * QsBluetoothManager, one level down from the panel: back bar, masthead rule,
 * a mute button beside a draggable volume meter, then every output device one
 * hairline apart. Tap a device to make it the default sink.
 *
 * Before this screen existed the panel could only MUTE the output; there was
 * nowhere to pick between speakers, headphones and an HDMI sink, which is the
 * one thing a sound row is asked for most.
 *
 * The rows only read a node's name and id, which Pipewire exposes on every
 * global, so nothing here needs a PwObjectTracker — only `audio.volume` and
 * `audio.muted` do, and those are read off `Audio.sink`, which `Audio` binds.
 */
Item {
    id: root

    /// The back chevron was pressed.
    signal back

    readonly property list<var> devices: Audio.outputDevices
    readonly property bool muted: Audio.sink?.audio?.muted ?? false
    readonly property real volume: Audio.sink?.audio?.volume ?? 0
    readonly property int volumePercent: Math.round(root.volume * 100)

    function setVolume(v: real): void {
        if (!Audio.sink?.audio)
            return;
        Audio.sink.audio.volume = Math.max(0, Math.min(1, v));
    }

    /// The glyph for a sink, guessed from its node name. Pipewire has no
    /// portable form factor property on a node, and the name is what every
    /// other mixer reads too.
    function deviceGlyph(node): string {
        const n = ((node?.name ?? "") + " " + (node?.description ?? "")).toLowerCase();
        if (n.includes("bluez") || n.includes("bluetooth"))
            return "bluetooth";
        if (n.includes("headphone") || n.includes("headset") || n.includes("earbud"))
            return "headphones";
        if (n.includes("hdmi") || n.includes("displayport") || n.includes("display-port"))
            return "monitor";
        return "speaker";
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: PaperTheme.pick(16, 10, 12)

        // ---- back bar -----------------------------------------------------
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: Math.max(PaperTheme.size.button, title.implicitHeight)

            PaperButton {
                id: backButton
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                shape: "icon"
                icon: "chevL"
                onClicked: root.back()
            }

            PaperTitle {
                id: title
                anchors.left: backButton.right
                anchors.leftMargin: PaperTheme.pick(14, 9, 10)
                anchors.right: muteButton.left
                anchors.rightMargin: PaperTheme.pick(14, 9, 10)
                anchors.verticalCenter: parent.verticalCenter
                text: "Audio output"
                elide: Text.ElideRight
            }

            PaperButton {
                id: muteButton
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                shape: "icon"
                icon: root.muted ? "speakerOff" : "speaker"
                destructive: root.muted
                enabled: Audio.sink !== null
                onClicked: Audio.toggleMute()

                PaperTooltip {
                    text: root.muted ? "Unmute" : "Mute"
                    anchorEdges: Edges.Left
                    anchorGravity: Edges.Left
                }
            }
        }

        PaperRule {
            Layout.fillWidth: true
            weight: "oxford"
        }

        // ---- volume -------------------------------------------------------
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: PaperTheme.size.listRow - PaperTheme.pick(12, 8, 8)
            spacing: PaperTheme.pick(12, 8, 8)

            PaperText {
                Layout.alignment: Qt.AlignVCenter
                role: "meta"
                text: "Volume"
            }

            PaperMeter {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                value: root.volume
                alert: root.muted
                interactive: Audio.sink !== null
                onSeek: v => root.setVolume(v)
            }

            PaperText {
                Layout.alignment: Qt.AlignVCenter
                Layout.minimumWidth: PaperTheme.pick(38, 34, 36)
                role: "meta"
                tone: "ink"
                figure: true
                horizontalAlignment: Text.AlignRight
                text: root.muted ? "Muted" : root.volumePercent + " %"
            }
        }

        PaperRule {
            Layout.fillWidth: true
        }

        // ---- the devices --------------------------------------------------
        PaperSectionHeader {
            Layout.fillWidth: true
            label: "Devices"
            meta: String(root.devices.length)
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            ListView {
                id: list
                anchors.fill: parent
                clip: true
                spacing: 0
                boundsBehavior: Flickable.StopAtBounds
                model: ScriptModel {
                    values: root.devices
                }

                delegate: PaperListRow {
                    id: devRow
                    required property int index
                    required property var modelData

                    readonly property bool isCurrent: devRow.modelData?.id !== undefined && devRow.modelData.id === Audio.sink?.id

                    width: list.width
                    icon: root.deviceGlyph(devRow.modelData)
                    dotColumn: PaperTheme.isHairline
                    dotFilled: devRow.isCurrent
                    title: devRow.modelData ? Audio.friendlyDeviceName(devRow.modelData) : "Unknown"
                    subtitle: devRow.isCurrent ? "In use" : "Tap to use"
                    on: devRow.isCurrent
                    selected: devRow.isCurrent && !PaperTheme.isHairline
                    separator: devRow.index > 0
                    onActivated: {
                        if (devRow.modelData)
                            Audio.setDefaultSink(devRow.modelData);
                    }

                    PaperStamp {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: devRow.isCurrent && PaperTheme.isBroadsheet
                        text: "In use"
                        tone: "accent"
                    }
                }
            }

            PaperEmpty {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                visible: list.count === 0
                text: "No output devices"
            }
        }
    }
}
