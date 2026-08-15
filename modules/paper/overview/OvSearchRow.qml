pragma ComponentBehavior: Bound
import qs
import qs.services
import qs.modules.common
import qs.modules.common.models
import qs.modules.paper.common
import qs.modules.paper.widgets
import QtQuick
import QtQuick.Layouts

/**
 * One launcher-search result row.
 *
 * SURFACE-LOCAL, and deliberately NOT `PaperListRow` — that widget now exists
 * and was evaluated for this row during integration. Four differences are
 * structural rather than cosmetic, so folding this in would mean rebuilding the
 * widget around the launcher rather than reusing it:
 *
 *   1. the leading slot needs THREE alternative renderings (a real app icon, a
 *      framed glyph slot, a raw emoji), where PaperListRow's is one PaperIcon;
 *   2. the type kicker sits ABOVE the name; PaperListRow stacks title then
 *      subtitle;
 *   3. PaperListRow animates a `changeBarIndent` on selection — a moving row
 *      under a fast-moving keyboard cursor is exactly what a launcher must not
 *      do;
 *   4. ledger's selected ground here is `paperSunk`, not `selection`, and
 *      broadsheet insets the between-row rule by 10 px.
 *
 * If a second list ever wants the same shape, the move is to give PaperListRow
 * an optional leading-content slot and a `kickerFirst` mode — see HANDOFF §3.
 *
 * Data and execute behaviour are identical to ii/pixel: a LauncherSearchResult
 * entry, click (or Enter on the current row) closes the overview and runs
 * `entry.execute()`.
 *
 * The selection language per variant:
 *   hairline   — no fill and no inversion. The row's ink comes forward, a 1 px
 *                ink change bar sits in the left margin, and the verb appears.
 *   ledger     — `paper-sunk` ground, a 2 px blue change bar, the name in blue.
 *   broadsheet — the `selection` ground, a 2 px oxblood change bar, and the
 *                verb in Pagella small caps oxblood.
 *
 * §4.6 also asked for a NEW mapping from LauncherSearch entry kinds to
 * PaperIcon glyphs, which the pixel build lacks (everything non-app there
 * collapses to a single `terminal` glyph because it has no symbol font). It
 * lives in `glyphFor()` below and keys off the Material symbol name the
 * service already sets, so it survives translation of the `type` label.
 */
Item {
    id: root

    required property var entry
    required property int index
    /// Horizontal padding, handed down from the sheet so field and rows align.
    property int sidePad: PaperTheme.pick(22, 14, 14)
    property int gutter: PaperTheme.pick(14, 11, 11)

    readonly property bool entryShown: root.entry?.shown ?? true
    readonly property string itemType: root.entry?.type ?? ""
    readonly property string itemName: root.entry?.name ?? ""
    readonly property var iconType: root.entry?.iconType
    readonly property string iconName: root.entry?.iconName ?? ""
    readonly property string verb: root.entry?.verb ?? "Open"
    readonly property bool monoName: root.entry?.fontType === LauncherSearchResult.FontType.Monospace

    readonly property bool selected: root.ListView.isCurrentItem
    readonly property bool hovered: mouse.containsMouse

    readonly property bool isApp: root.itemType === "App"
    readonly property bool isSystemIcon: root.iconType === LauncherSearchResult.IconType.System
    readonly property bool isTextIcon: root.iconType === LauncherSearchResult.IconType.Text

    /// Entry kind → PaperIcon glyph. Material symbol names first (they are set
    /// by the service and never translated), then the clipboard's `#…` type.
    function glyphFor(name: string, type: string): string {
        switch (name) {
        case "calculate":
            return "proc";
        case "terminal":
            return "terminal";
        case "travel_explore":
            return "search";
        case "settings_suggest":
            return "sliders";
        case "content_copy":
            return "layers";
        case "delete":
            return "trash";
        case "folder":
        case "document-open":
            return "folder";
        }
        // Cliphist entries carry no icon at all and type "#<first token>".
        if (type.startsWith("#"))
            return "lines";
        return "ellipsis";
    }

    readonly property color nameColor: PaperTheme.isBroadsheet ? PaperTheme.ink : PaperTheme.isLedger ? (root.selected ? PaperTheme.accent : PaperTheme.ink) : (root.selected ? PaperTheme.ink : PaperTheme.ink2)
    readonly property color glyphColor: (PaperTheme.isHairline && root.selected) ? PaperTheme.ink : PaperTheme.ink2

    readonly property int iconBoxSize: PaperTheme.pick(20, 22, 26)

    visible: root.entryShown
    implicitHeight: PaperTheme.isLedger ? 42 : content.implicitHeight + PaperTheme.pick(20, 20, 16)
    height: visible ? implicitHeight : 0

    function trigger(): void {
        GlobalStates.overviewOpen = false;
        if (root.entry?.execute)
            root.entry.execute();
    }

    // Selection / hover ground. Hairline has neither — its rows are separated
    // by whitespace and one rule, and "selected" is ink weight plus the bar.
    Rectangle {
        anchors.fill: parent
        color: root.selected ? (PaperTheme.isHairline ? "transparent" : PaperTheme.isLedger ? PaperTheme.paperSunk : PaperTheme.selection) : root.hovered ? PaperTheme.wash : "transparent"
        antialiasing: false
        Behavior on color {
            ColorAnimation {
                duration: PaperTheme.motion.fast
                easing.type: PaperTheme.motion.type
                easing.bezierCurve: PaperTheme.motion.bezierCurve
            }
        }
    }

    // The hairline between rows. Broadsheet insets it, as a rule between two
    // items in a block rather than an edge of the sheet.
    PaperRule {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: PaperTheme.pick(0, 0, 10)
        anchors.rightMargin: PaperTheme.pick(0, 0, 10)
        visible: root.index > 0
    }

    // The change bar — the family's one selection mark. Inset by one rule so
    // it prints just INSIDE the sheet's own edge, which PaperPanel draws above
    // its content (z: 2) and would otherwise cover.
    PaperRule {
        anchors.left: parent.left
        anchors.leftMargin: PaperTheme.ruleWidth
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.topMargin: PaperTheme.isHairline ? PaperTheme.spacing.small : 0
        anchors.bottomMargin: PaperTheme.isHairline ? PaperTheme.spacing.small : 0
        visible: root.selected
        vertical: true
        weight: "mark"
        tone: PaperTheme.isHairline ? "ink" : "accent"
        z: 2
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.trigger()
    }

    RowLayout {
        id: content
        anchors.fill: parent
        anchors.leftMargin: root.sidePad
        anchors.rightMargin: root.sidePad
        spacing: root.gutter

        // ---- the icon -------------------------------------------------
        Item {
            Layout.alignment: Qt.AlignVCenter
            Layout.preferredWidth: root.iconBoxSize
            Layout.preferredHeight: root.iconBoxSize

            // Apps and recent files: the real icon, desaturated and (A/C)
            // multiplied toward ink by PaperAppIcon.
            PaperAppIcon {
                anchors.centerIn: parent
                visible: root.isSystemIcon
                icon: root.iconName
                size: PaperTheme.pick(20, 14, 16)
                fallbackIcon: "apps"
            }

            // Non-app entries sit in a hairline slot in B and C; in A the glyph
            // stands alone, because A has no boxes.
            Rectangle {
                anchors.fill: parent
                visible: !root.isSystemIcon && !root.isTextIcon && PaperTheme.ornament.framedControls
                color: "transparent"
                radius: PaperTheme.radiusControl
                antialiasing: radius > 0
                border.width: PaperTheme.ruleWidth
                border.color: PaperTheme.rule
            }
            PaperIcon {
                anchors.centerIn: parent
                visible: !root.isSystemIcon && !root.isTextIcon
                name: root.glyphFor(root.iconName, root.itemType)
                size: PaperTheme.pick(20, 14, 14)
                color: root.glyphColor
            }

            // Emoji results carry their glyph as raw text.
            PaperText {
                anchors.centerIn: parent
                visible: root.isTextIcon
                text: root.iconName
                font.pixelSize: PaperTheme.pick(18, 16, 18)
            }
        }

        // ---- kicker over name ------------------------------------------
        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: PaperTheme.pick(2, 1, 1)

            PaperText {
                Layout.fillWidth: true
                visible: root.itemType !== "" && !root.isApp
                text: root.itemType
                role: "micro"
                elide: Text.ElideRight
            }
            PaperText {
                Layout.fillWidth: true
                text: root.itemName
                mono: root.monoName
                color: root.nameColor
                font.pixelSize: PaperTheme.pick(13, 13, 13)
                elide: Text.ElideRight
            }
        }

        // ---- the verb, only on the current row --------------------------
        PaperTitle {
            Layout.alignment: Qt.AlignVCenter
            visible: root.selected && root.verb !== ""
            text: root.verb
            role: "micro"
            // C sets it in real Pagella small caps; A and B letterspace it.
            caps: !PaperTheme.isBroadsheet
            tone: PaperTheme.isHairline ? "ink" : "accent"
            font.pixelSize: PaperTheme.pick(10, 10, 12)
        }
    }
}
