pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import qs
import qs.services
import qs.modules.common.models.quickToggles
import qs.modules.paper.common
import qs.modules.paper.widgets

/**
 * The quick-settings panel body — §4.3 in all four SPECs.
 *
 * A page pinned to the right edge: `paper` ground, one hairline down its LEFT
 * side (the other three edges meet the screen, and a docked panel never takes
 * the shadow), `PaperTheme.pad.panel` of padding and `PaperTheme.gap.section`
 * between blocks. Every section is fixed height except the notification list,
 * which flex-grows, so the calendar always sits at the bottom of the screen
 * where the hand expects it.
 *
 * Top to bottom: header (uptime + four actions) · masthead rule · connectivity
 * · notifications · footer · calendar area.
 *
 * The one structural branch is connectivity, and it is the branch all three
 * SPECs call for:
 *   hairline   — SIX 56 px PaperToggleRows in a single column. Same
 *                information as the pixel build's 3 × 2 grid of bordered tiles,
 *                more of it visible, and the switch carries the state so a
 *                title never has to invert. Plus a five-column "Toggles" row of
 *                glyph-over-micro-cap, underlined when on.
 *   ledger /    — three rows of tiles and square buttons, exactly the pixel
 *   broadsheet    layout re-cut in paper: two toggle tiles + a square button,
 *                 a square button + two tiles, then five equal buttons.
 * It is a `Loader` with a `sourceComponent` binding rather than a forest of
 * `visible:`, so a live variant switch re-lays it out with no reload.
 *
 * Clicking Internet or Bluetooth covers the panel with a management overlay
 * (QsWifiManager / QsBluetoothManager) rather than floating a dialog over it.
 */
Item {
    id: root

    /// Which management overlay is open: "" | "wifi" | "bluetooth".
    property string overlay: ""

    // ---- backing toggle models: reuse, never reimplement -------------------
    BluetoothToggle {
        id: bluetoothToggle
    }
    IdleInhibitorToggle {
        id: idleToggle
    }
    MicToggle {
        id: micToggle
    }
    NightLightToggle {
        id: nightLightToggle
    }
    CloudflareWarpToggle {
        id: warpToggle
    }
    GameModeToggle {
        id: gameModeToggle
    }
    EasyEffectsToggle {
        id: easyEffectsToggle
    }
    AntiFlashbangToggle {
        id: antiFlashbangToggle
    }
    ColorPickerToggle {
        id: colorPickerToggle
    }

    // ---- derived service state --------------------------------------------
    readonly property bool internetConnected: Network.wifiStatus === "connected" || Network.ethernet
    readonly property string internetStatus: Network.networkName !== "" ? Network.networkName : (root.internetConnected ? "Connected" : "Not connected")
    readonly property bool micActive: !(Audio.source?.audio?.muted ?? true)
    readonly property bool audioMuted: Audio.sink?.audio?.muted ?? false
    readonly property int volumePercent: Math.round((Audio.sink?.audio?.volume ?? 0) * 100)
    readonly property string sinkName: Audio.sink ? Audio.friendlyDeviceName(Audio.sink) : ""
    /// The status line always carries the real value, never the word "On".
    readonly property string audioStatus: {
        if (root.audioMuted)
            return "Muted";
        if (PaperTheme.isHairline)
            return "Unmuted · " + root.volumePercent + " %";
        return (root.sinkName !== "" ? root.sinkName + " · " : "") + root.volumePercent + " %";
    }
    readonly property int notifCount: Notifications.list.length

    /// Gap between blocks. `gap.section` (24/10/12) is the distance between two
    /// sections that are separated BY a rule; here every closing rule is its
    /// own row, so a full section gap lands on each side of it and the column
    /// grows 8 px per rule taller than the previews. 20/10/12 reproduces the
    /// three previews' actual block rhythm and keeps the whole fixed stack
    /// inside a 1080 px screen in hairline, which is the tallest variant.
    readonly property int blockGap: PaperTheme.pick(20, 10, 12)

    /// The five "extras". Peers, so they keep their grid in every variant.
    readonly property var extraToggles: [
        {
            // Ledger draws WARP with `cloud`; the other two with `nodes`.
            icon: PaperTheme.isLedger ? "cloud" : "nodes",
            label: "WARP",
            tip: "Cloudflare WARP",
            model: warpToggle
        },
        {
            icon: "fullscreen",
            label: "Game",
            tip: "Game mode",
            model: gameModeToggle
        },
        {
            icon: "sliders",
            label: "Effects",
            tip: "Easy Effects",
            model: easyEffectsToggle
        },
        {
            icon: "flashoff",
            label: "Anti-flash",
            tip: "Anti-flashbang",
            model: antiFlashbangToggle
        },
        {
            icon: "dropper",
            label: "Picker",
            tip: "Colour picker",
            model: colorPickerToggle
        }
    ]

    readonly property var headerActions: [
        {
            icon: "pencil",
            action: "edit",
            tip: "Edit"
        },
        {
            icon: "refresh",
            action: "refresh",
            tip: "Refresh"
        },
        {
            icon: "gear",
            action: "settings",
            tip: "Settings"
        },
        {
            icon: "power",
            action: "power",
            tip: "Power"
        }
    ]

    function runHeaderAction(action: string): void {
        if (action === "power") {
            GlobalStates.sessionOpen = true;
            GlobalStates.sidebarRightOpen = false;
        } else if (action === "settings") {
            Quickshell.execDetached(["qs", "-p", Quickshell.shellPath("settings.qml")]);
            GlobalStates.sidebarRightOpen = false;
        }
        // edit / refresh: harmless stubs, exactly as in the pixel build.
    }

    // ======================================================================
    PaperPanel {
        id: sheet
        anchors.fill: parent
        kind: "sheet"
        // A docked panel takes NO shadow — only the edge rule against the
        // screen edge — and drops the border on every edge that meets one.
        floating: false
        edgeTop: false
        edgeBottom: false
        edgeRight: false
        edgeLeft: true
        edgeWeight: PaperTheme.isHairline ? "hair" : "fine"

        ColumnLayout {
            id: column
            anchors.fill: parent
            anchors.margins: PaperTheme.pad.panel
            spacing: root.blockGap

            // ============================ HEADER =========================
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: Math.max(headerButtons.implicitHeight, uptimeLoader.implicitHeight)

                Loader {
                    id: uptimeLoader
                    anchors.left: parent.left
                    anchors.right: headerButtons.left
                    anchors.rightMargin: root.blockGap
                    anchors.verticalCenter: parent.verticalCenter
                    sourceComponent: PaperTheme.isBroadsheet ? stackedUptime : PaperTheme.isLedger ? cardUptime : inlineUptime
                }

                Row {
                    id: headerButtons
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: PaperTheme.pick(16, 8, 8)

                    Repeater {
                        model: root.headerActions

                        delegate: PaperButton {
                            id: headerButton
                            required property var modelData

                            shape: "icon"
                            icon: headerButton.modelData.icon
                            // Broadsheet frames its masthead buttons; the other
                            // two leave them bare.
                            ghost: !PaperTheme.isBroadsheet
                            implicitWidth: PaperTheme.pick(24, 26, 30)
                            implicitHeight: PaperTheme.pick(24, 26, 28)
                            onClicked: root.runHeaderAction(headerButton.modelData.action)

                            PaperTooltip {
                                text: headerButton.modelData.tip
                                anchorEdges: Edges.Left
                                anchorGravity: Edges.Left
                            }
                        }
                    }
                }
            }

            // The masthead. An Oxford rule in broadsheet, a hairline elsewhere.
            PaperRule {
                Layout.fillWidth: true
                weight: "oxford"
            }

            // ========================= CONNECTIVITY =======================
            ColumnLayout {
                Layout.fillWidth: true
                spacing: PaperTheme.pick(6, 6, 8)

                PaperSectionHeader {
                    Layout.fillWidth: true
                    // Broadsheet goes straight from the masthead to the tiles.
                    visible: !PaperTheme.isBroadsheet
                    label: "Connectivity"
                }

                Loader {
                    Layout.fillWidth: true
                    sourceComponent: PaperTheme.isHairline ? connectivityRows : connectivityGrid
                }
            }

            // Hairline gives the five extras their own section; the other two
            // fold them into the connectivity grid as row C.
            ColumnLayout {
                Layout.fillWidth: true
                visible: PaperTheme.isHairline
                spacing: PaperTheme.pick(16, 6, 6)

                PaperSectionHeader {
                    Layout.fillWidth: true
                    label: "Toggles"
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    Repeater {
                        model: root.extraToggles

                        delegate: PaperButton {
                            id: extraColumn
                            required property var modelData

                            Layout.fillWidth: true
                            Layout.preferredHeight: PaperTheme.pick(50, 50, 52)
                            shape: "stacked"
                            icon: extraColumn.modelData.icon
                            label: extraColumn.modelData.label
                            checked: extraColumn.modelData.model.toggled
                            enabled: extraColumn.modelData.model.available
                            onClicked: extraColumn.modelData.model.mainAction()

                            PaperTooltip {
                                text: extraColumn.modelData.tip
                                anchorEdges: Edges.Left
                                anchorGravity: Edges.Left
                            }
                        }
                    }
                }
            }

            // Closes the connectivity block. Doubles in broadsheet.
            PaperRule {
                Layout.fillWidth: true
                weight: "double"
            }

            // ======================== NOTIFICATIONS =======================
            PaperSectionHeader {
                Layout.fillWidth: true
                label: "Notifications"
                // The pixel build's non-interactive full-width "N
                // notification(s)" button is gone in hairline: the count lives
                // in the section header, where every other count in the theme
                // lives.
                meta: PaperTheme.isBroadsheet ? root.notifCount + " unread" : String(root.notifCount)
            }

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumHeight: 60

                ListView {
                    id: notifList
                    anchors.fill: parent
                    clip: true
                    spacing: PaperTheme.pick(0, 8, 2)
                    boundsBehavior: Flickable.StopAtBounds
                    model: ScriptModel {
                        values: Notifications.appNameList
                    }

                    delegate: PaperNotifRow {
                        id: notifRow
                        required property int index
                        required property var modelData

                        width: notifList.width
                        group: Notifications.groupsByAppName[notifRow.modelData] ?? null
                        // Ledger cards are spaced, not ruled; the other two rule.
                        separator: notifRow.index > 0 && !PaperTheme.isLedger
                        onDismiss: id => Notifications.discardNotification(id)
                    }
                }

                PaperEmpty {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    visible: Notifications.appNameList.length === 0
                    text: "No notifications"
                }
            }

            // ============================ FOOTER ==========================
            Loader {
                Layout.fillWidth: true
                sourceComponent: PaperTheme.isHairline ? capsFooter : buttonFooter
            }

            // Closes the notification block.
            PaperRule {
                Layout.fillWidth: true
                weight: "double"
            }

            // ======================= CALENDAR AREA ========================
            QsCalendarArea {
                id: calendarArea
                Layout.fillWidth: true
                Layout.preferredHeight: calendarArea.implicitHeight
            }
        }
    }

    // ======================================================================
    // Management overlay. Covers the whole panel on an opaque paper ground —
    // it REPLACES the panel body rather than floating a dialog over it.
    // Broadsheet's SPEC asks for a 280 ms slide-in; the family's hard 4 px
    // travel ceiling forbids that, so it fades over `motion.slow` instead.
    Rectangle {
        id: cover
        anchors.fill: parent
        anchors.leftMargin: PaperTheme.ruleWidth
        visible: opacity > 0
        opacity: root.overlay !== "" ? 1 : 0
        color: PaperTheme.paper

        Behavior on opacity {
            NumberAnimation {
                duration: PaperTheme.motion.slow
                easing.type: PaperTheme.motion.type
                easing.bezierCurve: PaperTheme.motion.bezierCurve
            }
        }

        // The same grain the panels carry, so the overlay is cut from one sheet
        // with the page underneath it.
        Image {
            anchors.fill: parent
            visible: PaperTheme.ornament.grain && PaperTheme.ornament.grainOpacity > 0
            source: Qt.resolvedUrl(Quickshell.shellPath("assets/images/paper-grain.png"))
            fillMode: Image.Tile
            opacity: PaperTheme.ornament.grainOpacity
            cache: true
            smooth: false
        }

        MouseArea {
            // Swallow clicks so they never reach the panel underneath.
            anchors.fill: parent
            hoverEnabled: true
        }

        Loader {
            id: overlayLoader
            anchors.fill: parent
            anchors.margins: PaperTheme.pad.panel
            active: root.overlay !== ""
            sourceComponent: root.overlay === "wifi" ? wifiManager : root.overlay === "bluetooth" ? bluetoothManager : null
        }
    }

    // ---------------------------------------------------------- components
    Component {
        id: wifiManager
        QsWifiManager {
            onBack: root.overlay = ""
        }
    }
    Component {
        id: bluetoothManager
        QsBluetoothManager {
            onBack: root.overlay = ""
        }
    }

    // ---- uptime, three shapes ---------------------------------------------
    Component {
        id: inlineUptime
        Row {
            spacing: PaperTheme.pick(9, 7, 7)

            PaperIcon {
                anchors.verticalCenter: parent.verticalCenter
                name: "clock"
                size: PaperTheme.icon.row
                color: PaperTheme.ink3
            }
            PaperText {
                anchors.verticalCenter: parent.verticalCenter
                role: "small"
                text: "Up"
            }
            PaperText {
                anchors.verticalCenter: parent.verticalCenter
                role: "small"
                tone: "ink"
                figure: true
                text: DateTime.uptime
            }
        }
    }

    Component {
        id: cardUptime
        PaperPanel {
            kind: "card"
            floating: false
            implicitWidth: uptimeRow.implicitWidth + 2 * PaperTheme.pad.card
            implicitHeight: PaperTheme.pick(26, 26, 26)

            Row {
                id: uptimeRow
                anchors.centerIn: parent
                spacing: PaperTheme.pick(9, 7, 7)

                PaperIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: "clock"
                    size: PaperTheme.icon.row
                    color: PaperTheme.ink2
                }
                PaperText {
                    anchors.verticalCenter: parent.verticalCenter
                    role: "micro"
                    text: "Up"
                }
                PaperText {
                    anchors.verticalCenter: parent.verticalCenter
                    role: "meta"
                    tone: "ink"
                    figure: true
                    text: DateTime.uptime
                }
            }
        }
    }

    Component {
        id: stackedUptime
        Column {
            spacing: 0

            PaperText {
                role: "micro"
                text: "Uptime"
            }
            PaperText {
                role: "lead"
                tone: "ink"
                figure: true
                text: DateTime.uptime
            }
        }
    }

    // ---- connectivity, hairline: six rows ----------------------------------
    Component {
        id: connectivityRows

        ColumnLayout {
            spacing: 0

            PaperToggleRow {
                Layout.fillWidth: true
                icon: root.internetConnected ? "wifi" : "wifiOff"
                title: "Internet"
                status: root.internetStatus
                on: root.internetConnected
                connected: true
                control: "chevron"
                tooltip: "Wi-Fi"
                onActivated: root.overlay = "wifi"
            }
            PaperToggleRow {
                Layout.fillWidth: true
                separator: true
                icon: "bluetooth"
                title: "Bluetooth"
                status: bluetoothToggle.statusText
                on: bluetoothToggle.toggled
                connected: true
                control: "chevron"
                tooltip: "Bluetooth"
                onActivated: root.overlay = "bluetooth"
            }
            PaperToggleRow {
                Layout.fillWidth: true
                separator: true
                icon: "coffee"
                title: "Keep awake"
                status: idleToggle.toggled ? "Idle inhibited" : "Idle allowed"
                on: idleToggle.toggled
                tooltip: "Keep system awake"
                onToggled: idleToggle.mainAction()
            }
            PaperToggleRow {
                Layout.fillWidth: true
                separator: true
                icon: root.micActive ? "mic" : "micOff"
                title: "Microphone"
                status: root.micActive ? "Unmuted" : "Muted"
                on: root.micActive
                tooltip: "Microphone"
                onToggled: micToggle.mainAction()
            }
            PaperToggleRow {
                Layout.fillWidth: true
                separator: true
                icon: root.audioMuted ? "speakerOff" : "speaker"
                title: "Audio output"
                status: root.audioStatus
                on: !root.audioMuted
                tooltip: "Audio output"
                onToggled: Audio.toggleMute()
            }
            PaperToggleRow {
                Layout.fillWidth: true
                separator: true
                icon: "moon"
                title: "Night light"
                status: nightLightToggle.statusText
                on: nightLightToggle.toggled
                tooltip: "Night light"
                onToggled: nightLightToggle.mainAction()
            }
        }
    }

    // ---- connectivity, ledger / broadsheet: three rows of tiles ------------
    Component {
        id: connectivityGrid

        ColumnLayout {
            spacing: PaperTheme.gap.tile

            // Row A — Internet · Bluetooth · keep awake
            RowLayout {
                Layout.fillWidth: true
                spacing: PaperTheme.pick(8, 8, 8)

                QsToggleTile {
                    Layout.fillWidth: true
                    icon: root.internetConnected ? "wifi" : "wifiOff"
                    title: "Internet"
                    status: root.internetStatus
                    on: root.internetConnected
                    connected: true
                    tooltip: "Wi-Fi"
                    onActivated: root.overlay = "wifi"
                }
                QsToggleTile {
                    Layout.fillWidth: true
                    icon: "bluetooth"
                    title: "Bluetooth"
                    status: bluetoothToggle.statusText
                    on: bluetoothToggle.toggled
                    connected: true
                    tooltip: "Bluetooth"
                    onActivated: root.overlay = "bluetooth"
                }
                PaperButton {
                    Layout.preferredWidth: PaperTheme.pick(34, 34, 44)
                    Layout.preferredHeight: PaperTheme.pick(42, 42, 48)
                    shape: "icon"
                    ghost: false
                    icon: "coffee"
                    iconSize: PaperTheme.icon.large - 2
                    checked: idleToggle.toggled
                    onClicked: idleToggle.mainAction()

                    PaperTooltip {
                        text: "Keep system awake"
                        anchorEdges: Edges.Left
                        anchorGravity: Edges.Left
                    }
                }
            }

            // Row B — microphone · output · night light
            RowLayout {
                Layout.fillWidth: true
                spacing: PaperTheme.pick(8, 8, 8)

                PaperButton {
                    Layout.preferredWidth: PaperTheme.pick(34, 34, 44)
                    Layout.preferredHeight: PaperTheme.pick(42, 42, 48)
                    shape: "icon"
                    ghost: false
                    icon: root.micActive ? "mic" : "micOff"
                    iconSize: PaperTheme.icon.large - 2
                    checked: root.micActive
                    onClicked: micToggle.mainAction()

                    PaperTooltip {
                        text: "Microphone"
                        anchorEdges: Edges.Left
                        anchorGravity: Edges.Left
                    }
                }
                QsToggleTile {
                    Layout.fillWidth: true
                    icon: root.audioMuted ? "speakerOff" : "speaker"
                    title: "Output"
                    status: root.audioStatus
                    on: !root.audioMuted
                    tooltip: "Audio output"
                    onActivated: Audio.toggleMute()
                }
                QsToggleTile {
                    Layout.fillWidth: true
                    icon: "moon"
                    title: "Night light"
                    status: nightLightToggle.statusText
                    on: nightLightToggle.toggled
                    tooltip: "Night light"
                    onActivated: nightLightToggle.mainAction()
                }
            }

            // Row C — the five extras
            RowLayout {
                Layout.fillWidth: true
                spacing: PaperTheme.pick(6, 6, 6)

                Repeater {
                    model: root.extraToggles

                    delegate: PaperButton {
                        id: extraButton
                        required property var modelData

                        Layout.fillWidth: true
                        Layout.preferredHeight: PaperTheme.pick(34, 34, 34)
                        shape: "icon"
                        ghost: false
                        icon: extraButton.modelData.icon
                        checked: extraButton.modelData.model.toggled
                        enabled: extraButton.modelData.model.available
                        onClicked: extraButton.modelData.model.mainAction()

                        PaperTooltip {
                            text: extraButton.modelData.tip
                            anchorEdges: Edges.Left
                            anchorGravity: Edges.Left
                        }
                    }
                }
            }

            // Broadsheet names the five so the row reads at a glance without
            // hovering anything. The tooltips remain.
            PaperText {
                Layout.fillWidth: true
                visible: PaperTheme.isBroadsheet
                role: "meta"
                footnote: true
                tone: "ink4"
                text: "WARP · Game mode · Easy Effects · Anti-flashbang · Colour picker"
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
            }
        }
    }

    // ---- notification footer, two shapes -----------------------------------
    Component {
        id: capsFooter

        RowLayout {
            spacing: PaperTheme.pick(26, 12, 12)

            PaperButton {
                label: "Mark all read"
                onClicked: Notifications.markAllRead()
            }
            PaperButton {
                label: "Clear all"
                destructive: true
                onClicked: Notifications.discardAllNotifications()
            }
            Item {
                Layout.fillWidth: true
            }
        }
    }

    Component {
        id: buttonFooter

        RowLayout {
            spacing: PaperTheme.pick(8, 8, 8)

            PaperButton {
                Layout.preferredWidth: PaperTheme.pick(40, 32, 40)
                Layout.preferredHeight: PaperTheme.pick(30, 30, 30)
                shape: "icon"
                ghost: false
                icon: "bell"
                onClicked: Notifications.markAllRead()

                PaperTooltip {
                    text: "Mark all read"
                    anchorEdges: Edges.Left
                    anchorGravity: Edges.Left
                }
            }

            // A non-interactive tally. Broadsheet dots its frame, which is its
            // "this is not a control" mark.
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: PaperTheme.pick(30, 30, 30)

                Rectangle {
                    anchors.fill: parent
                    color: "transparent"
                    radius: PaperTheme.radiusControl
                    antialiasing: radius > 0
                    border.width: PaperTheme.isBroadsheet ? 0 : PaperTheme.ruleWidth
                    border.color: PaperTheme.rule
                }
                // Broadsheet's dotted frame — its "this is not a control" mark,
                // the same device it uses for a disabled edge.
                PaperRule {
                    visible: PaperTheme.isBroadsheet
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    dotted: true
                    tone: "ink4"
                }
                PaperRule {
                    visible: PaperTheme.isBroadsheet
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    anchors.right: parent.right
                    dotted: true
                    tone: "ink4"
                }
                PaperRule {
                    visible: PaperTheme.isBroadsheet
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    vertical: true
                    dotted: true
                    tone: "ink4"
                }
                PaperRule {
                    visible: PaperTheme.isBroadsheet
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    anchors.right: parent.right
                    vertical: true
                    dotted: true
                    tone: "ink4"
                }
                PaperText {
                    anchors.centerIn: parent
                    role: PaperTheme.isBroadsheet ? "micro" : "small"
                    tone: "ink3"
                    text: root.notifCount + (root.notifCount === 1 ? " notification" : " notifications")
                }
            }

            PaperButton {
                Layout.preferredWidth: PaperTheme.pick(40, 32, 40)
                Layout.preferredHeight: PaperTheme.pick(30, 30, 30)
                shape: "icon"
                ghost: false
                destructive: true
                icon: "trash"
                onClicked: Notifications.discardAllNotifications()

                PaperTooltip {
                    text: "Clear all"
                    anchorEdges: Edges.Left
                    anchorGravity: Edges.Left
                }
            }
        }
    }
}
