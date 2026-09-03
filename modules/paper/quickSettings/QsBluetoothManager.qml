pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Bluetooth
import qs.services
import qs.modules.paper.common
import qs.modules.paper.widgets

/**
 * The Bluetooth management overlay — the same shell as QsWifiManager, one level
 * down from the panel: back bar, masthead rule, radio, the pairing window, then
 * the devices (connected, then paired, then discovered) one hairline apart.
 *
 * NOTHING starts by itself. Opening this screen powers no radio, starts no
 * inquiry and makes the machine visible to nobody; it just lists what BlueZ
 * already knows. A pairing window is a deliberate act: press Start, and for
 * `pairWindowSeconds` the adapter scans AND is discoverable, with the time left
 * on the row. It closes itself when the countdown runs out, when you press
 * Stop, when you pick a device, or when you leave the screen.
 *
 * That is ONE control for what BlueZ splits into three (`discovering` = we look
 * for them; `discoverable` + `pairable` = they can find us), because "pair a new
 * device" always wants all three and nothing else in the shell wants any of them
 * on its own.
 *
 * Two rules the radio itself imposes, both learned the hard way:
 *
 *   An inquiry blocks a link. The controller cannot scan and bring up a
 *   connection reliably at the same time, and it is the connection that loses —
 *   that is what produces a speaker which reports "Connected" and drops a second
 *   later. So every pair and every connect stops the scan FIRST (`endScan`),
 *   which is also why the pairing window is a window and not a mode.
 *
 *   A tap never disconnects. These rows re-sort the instant a device's state
 *   changes — one that connects jumps to the top group — so a second tap after a
 *   successful connect used to land on a now-connected row and tear the link
 *   straight back down. A tap only ever moves a device TOWARD connected;
 *   disconnect, cancel and forget are all right-click, each named in the tooltip.
 *
 * Null-safe against there being no adapter at all.
 */
Item {
    id: root

    /// The back chevron was pressed.
    signal back

    readonly property var adapter: Bluetooth.defaultAdapter ?? null
    readonly property bool radioOn: root.adapter?.enabled ?? false
    readonly property bool scanning: root.adapter?.discovering ?? false
    readonly property bool pairingMode: (root.adapter?.discoverable ?? false) && (root.adapter?.pairable ?? false)
    readonly property var devices: BluetoothStatus.friendlyDeviceList ?? []

    /// How long one pairing window lasts. Long enough to fish a speaker out of a
    /// bag and hold its button down; short enough that a panel left open is not
    /// a laptop broadcasting itself all afternoon.
    readonly property int pairWindowSeconds: 120
    property int pairSecondsLeft: 0

    /// BlueZ PERSISTS the two timeouts in the adapter's stored settings, so the
    /// screen puts them back the way it found them instead of leaving the
    /// machine permanently discoverable-without-timeout for whatever turns
    /// discoverability on next. -1 means "nothing saved".
    property int savedDiscoverableTimeout: -1
    property int savedPairableTimeout: -1

    readonly property string pairStatus: {
        if (!root.adapter)
            return "No Bluetooth adapter";
        if (root.pairingMode)
            return "Visible and scanning · " + root.pairSecondsLeft + " s left";
        if (!root.radioOn)
            return "Starting will turn Bluetooth on";
        return "Idle — nothing is scanned until you start";
    }

    onVisibleChanged: if (!root.visible)
        root.endPairingWindow()
    Component.onDestruction: root.endPairingWindow()

    Timer {
        id: pairCountdown
        interval: 1000
        repeat: true
        onTriggered: {
            root.pairSecondsLeft -= 1;
            if (root.pairSecondsLeft <= 0)
                root.endPairingWindow();
        }
    }

    /// BlueZ auto-connects most audio devices as soon as pairing lands, but not
    /// all of them, and a device that reports "Paired" while staying silent is
    /// the most confusing outcome this screen can produce. So: one follow-up
    /// connect a beat after the pair request, plus `trusted`, which is what lets
    /// the speaker reconnect on its own from then on.
    Timer {
        id: connectAfterPair
        interval: 2500
        property var device: null
        onTriggered: {
            const d = connectAfterPair.device;
            connectAfterPair.device = null;
            if (!d || !d.paired)
                return;
            d.trusted = true;
            if (!d.connected && d.state === BluetoothDeviceState.Disconnected)
                d.connect();
        }
    }

    function toggleRadio(): void {
        if (!root.adapter)
            return;
        root.adapter.enabled = !root.adapter.enabled;
        if (!root.adapter.enabled)
            root.endPairingWindow();
    }

    /// Stop the inquiry. Called before every pair and every connect: the
    /// controller cannot scan and bring up a link at the same time.
    function endScan(): void {
        if (root.adapter?.discovering)
            root.adapter.discovering = false;
    }

    function startPairingWindow(): void {
        if (!root.adapter)
            return;
        root.adapter.enabled = true;
        if (root.savedDiscoverableTimeout < 0) {
            root.savedDiscoverableTimeout = root.adapter.discoverableTimeout;
            root.savedPairableTimeout = root.adapter.pairableTimeout;
        }
        // 0 = no BlueZ timeout; this screen's own countdown owns the window, so
        // it cannot expire early underneath the button.
        root.adapter.discoverableTimeout = 0;
        root.adapter.pairableTimeout = 0;
        root.adapter.discoverable = true;
        root.adapter.pairable = true;
        if (!root.adapter.discovering)
            root.adapter.discovering = true;
        root.pairSecondsLeft = root.pairWindowSeconds;
        pairCountdown.restart();
    }

    function endPairingWindow(): void {
        pairCountdown.stop();
        root.pairSecondsLeft = 0;
        if (!root.adapter)
            return;
        root.endScan();
        // Clear the flags BEFORE restoring the timeouts: writing a timeout while
        // discoverable is still true just restarts the timer.
        root.adapter.discoverable = false;
        root.adapter.pairable = false;
        if (root.savedDiscoverableTimeout >= 0) {
            root.adapter.discoverableTimeout = root.savedDiscoverableTimeout;
            root.adapter.pairableTimeout = root.savedPairableTimeout;
            root.savedDiscoverableTimeout = -1;
            root.savedPairableTimeout = -1;
        }
    }

    /// The one forward action a row can take: get this device connected, from
    /// whatever state it is in. Never the reverse.
    function advance(device): void {
        if (!device || device.pairing || device.connected)
            return;
        root.endScan();
        if (device.paired) {
            device.connect();
            return;
        }
        device.pair();
        connectAfterPair.device = device;
        connectAfterPair.restart();
    }

    /// The undo actions, all on the secondary click so the primary one can never
    /// take a working speaker away.
    function retreat(device): void {
        if (!device)
            return;
        if (device.pairing)
            device.cancelPair();
        else if (device.connected)
            device.disconnect();
        else if (device.paired)
            device.forget();
    }

    /// The glyph for a device, from the freedesktop icon name BlueZ reports.
    function deviceGlyph(device): string {
        const i = (device?.icon ?? "").toLowerCase();
        if (i.includes("headset") || i.includes("headphone"))
            return "headphones";
        if (i.includes("phone"))
            return "phone";
        if (i.includes("audio") || i.includes("speaker"))
            return "speaker";
        if (i.includes("keyboard"))
            return "keyboard";
        if (i.includes("mouse") || i.includes("input"))
            return "grip";
        if (i.includes("computer"))
            return "laptop";
        if (i.includes("display") || i.includes("video"))
            return "monitor";
        return "bluetooth";
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
                anchors.right: radioButton.visible ? radioButton.left : parent.right
                anchors.rightMargin: radioButton.visible ? PaperTheme.pick(14, 9, 10) : 0
                anchors.verticalCenter: parent.verticalCenter
                text: "Bluetooth"
                elide: Text.ElideRight
            }

            // Ledger and broadsheet put the radio in the masthead as an On
            // button; hairline gives it a switch on its own row below.
            PaperButton {
                id: radioButton
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                visible: !PaperTheme.isHairline
                enabled: root.adapter !== null
                label: root.radioOn ? "On" : "Off"
                checked: root.radioOn
                connected: true
                onClicked: root.toggleRadio()
            }
        }

        PaperRule {
            Layout.fillWidth: true
            weight: "oxford"
        }

        // ---- radio row (hairline only) ------------------------------------
        PaperToggleRow {
            Layout.fillWidth: true
            visible: PaperTheme.isHairline
            enabled: root.adapter !== null
            icon: "bluetooth"
            title: "Bluetooth"
            status: root.radioOn ? "Radio on" : "Radio off"
            on: root.radioOn
            connected: true
            minHeight: PaperTheme.size.listRow
            onToggled: root.toggleRadio()
        }

        // ---- the pairing window -------------------------------------------
        // A button, not a switch: this starts something that runs on a clock and
        // takes over the radio, so it should read as an act, not a setting.
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: Math.max(PaperTheme.size.listRow, pairButton.implicitHeight)

            PaperIcon {
                id: pairGlyph
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                name: "eye"
                size: PaperTheme.icon.control
                color: root.pairingMode ? PaperTheme.link : PaperTheme.ink3
            }

            Column {
                anchors.left: pairGlyph.right
                anchors.leftMargin: PaperTheme.pick(13, 9, 10)
                anchors.right: pairButton.left
                anchors.rightMargin: PaperTheme.pick(12, 8, 8)
                anchors.verticalCenter: parent.verticalCenter
                spacing: PaperTheme.pick(2, 2, 1)

                PaperText {
                    width: parent.width
                    role: PaperTheme.pick("body", "small", "body")
                    text: "Pair a new device"
                    color: root.pairingMode ? PaperTheme.link : PaperTheme.ink
                    font.weight: PaperTheme.isHairline ? PaperTheme.font.weight.normal : PaperTheme.font.weight.medium
                    elide: Text.ElideRight
                }
                PaperText {
                    width: parent.width
                    role: "meta"
                    color: root.pairingMode ? PaperTheme.link : PaperTheme.ink3
                    text: root.pairStatus
                    elide: Text.ElideRight
                }
            }

            PaperButton {
                id: pairButton
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                enabled: root.adapter !== null
                label: root.pairingMode ? "Stop" : "Start"
                checked: root.pairingMode
                connected: true
                onClicked: {
                    if (root.pairingMode)
                        root.endPairingWindow();
                    else
                        root.startPairingWindow();
                }

                PaperTooltip {
                    text: "Scan for nearby devices and let them find this machine"
                    anchorEdges: Edges.Left
                    anchorGravity: Edges.Left
                }
            }
        }

        PaperRule {
            Layout.fillWidth: true
        }

        // ---- the devices --------------------------------------------------
        PaperSectionHeader {
            Layout.fillWidth: true
            label: "Devices"
            meta: root.scanning ? "Scanning…" : String(root.devices.length)
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

                    readonly property bool isConnected: devRow.modelData?.connected ?? false
                    readonly property bool isPaired: devRow.modelData?.paired ?? false
                    readonly property bool isPairing: devRow.modelData?.pairing ?? false
                    /// A connect/disconnect is already in flight. The row stops
                    /// taking clicks until it lands — repeated taps otherwise
                    /// just pile up "already disconnecting" errors on the bus
                    /// and churn the list this delegate lives in.
                    readonly property bool busy: devRow.modelData?.state === BluetoothDeviceState.Connecting || devRow.modelData?.state === BluetoothDeviceState.Disconnecting

                    width: list.width
                    icon: root.deviceGlyph(devRow.modelData)
                    dotColumn: PaperTheme.isHairline
                    dotFilled: devRow.isConnected
                    title: devRow.modelData?.name || "Unknown device"
                    // The subtitle names what the tap will do, so pairing is
                    // never something you have to guess at.
                    subtitle: {
                        const d = devRow.modelData;
                        if (!d)
                            return "";
                        if (d.pairing)
                            return "Pairing…";
                        if (d.state === BluetoothDeviceState.Connecting)
                            return "Connecting…";
                        if (d.state === BluetoothDeviceState.Disconnecting)
                            return "Disconnecting…";
                        if (d.connected)
                            return d.batteryAvailable ? "Connected · " + Math.round(d.battery * 100) + " %" : "Connected";
                        if (d.paired)
                            return "Paired · tap to connect";
                        return "Not paired · tap to pair";
                    }
                    on: devRow.isConnected
                    selected: devRow.isConnected && !PaperTheme.isHairline
                    connected: true
                    separator: devRow.index > 0
                    interactive: !devRow.busy
                    // The secondary action is the only destructive one, so it is
                    // the only one that has to announce itself.
                    tooltip: {
                        if (devRow.isPairing)
                            return "Right-click to cancel pairing";
                        if (devRow.isConnected)
                            return "Right-click to disconnect";
                        if (devRow.isPaired)
                            return "Right-click to forget this device";
                        return "";
                    }
                    onActivated: root.advance(devRow.modelData)
                    onRightActivated: root.retreat(devRow.modelData)

                    PaperStamp {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: devRow.isPairing
                        text: "Pairing"
                        tone: "accent"
                    }

                    PaperStamp {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: devRow.isConnected && PaperTheme.isBroadsheet
                        text: "Linked"
                        tone: "link"
                    }
                }
            }

            PaperEmpty {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                visible: list.count === 0
                text: !root.radioOn ? "Bluetooth off" : root.scanning ? "Scanning…" : "No known devices — press Start to pair one"
            }
        }
    }
}
