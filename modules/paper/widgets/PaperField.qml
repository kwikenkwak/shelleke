import QtQuick
import qs.modules.paper.common

/**
 * A single-line text field. Replaces PixField.
 *
 *   hairline   — a micro-caps label, the value, and a single hairline
 *                UNDERNEATH. No box, ever. Rest `rule-2`; focus `ink`; invalid
 *                `alert` with the reason directly beneath in `alert` at 11 px;
 *                read-only keeps `rule` and `ink-2`.
 *   ledger     — 28 tall, 1 px `rule-2`, radius 2. Focus does not merely
 *                recolour the border: it adds a 2 px blue underline INSIDE the
 *                box, like ruling a line under an entry.
 *   broadsheet — 30 tall, `paper` fill, 1 px `rule` with a `rule2` bottom.
 *                Focus thickens the BOTTOM hairline to 2 px oxblood; nothing
 *                else moves. Placeholders are Pagella italic in `ink-4`.
 *
 * `borderless: true` is the search / to-do-adder variant: no label, full width,
 * an optional leading glyph, and only the underline.
 *
 *   PaperField { label: "Task name"; placeholder: "hairline-theme"
 *                invalid: !valid; invalidMessage: "letters, digits, . _ - only"
 *                onEdited: t => name = t }
 *
 * Call focusInput() to grab keyboard focus — the panels that host fields use
 * WlrKeyboardFocus.OnDemand, so this is what makes typing work.
 */
Item {
    id: root

    property alias text: input.text
    property string label: ""
    property string placeholder: ""
    /// A leading glyph (search, plus).
    property string icon: ""
    property bool numeric: false
    property bool readOnly: false
    property bool invalid: false
    property string invalidMessage: ""
    /// No label, no box — the full-width search / adder variant.
    property bool borderless: false
    /// A hint beneath the field, in `ink-3` (or `alert` when invalid).
    property string hint: ""

    signal accepted
    /// Fires on every keystroke, for live model updates.
    signal edited(string value)

    function focusInput(): void {
        input.forceActiveFocus();
    }
    function clear(): void {
        input.text = "";
    }

    readonly property bool focused: input.activeFocus
    readonly property bool boxed: PaperTheme.ornament.framedControls && !root.borderless
    readonly property color markColor: root.invalid ? PaperTheme.alert : root.focused ? (PaperTheme.isHairline ? PaperTheme.ink : PaperTheme.accent) : root.readOnly ? PaperTheme.rule : PaperTheme.rule2
    readonly property string footer: root.invalid && root.invalidMessage !== "" ? root.invalidMessage : root.hint

    implicitWidth: 200
    implicitHeight: (labelText.visible ? labelText.implicitHeight + PaperTheme.pick(9, 6, 6) : 0) + fieldRow.height + (footerText.visible ? footerText.implicitHeight + PaperTheme.pick(7, 5, 5) : 0)

    PaperText {
        id: labelText
        visible: root.label !== ""
        text: root.label
        role: "micro"
        anchors.left: parent.left
        anchors.top: parent.top
    }

    Item {
        id: fieldRow
        anchors.left: parent.left
        anchors.right: parent.right
        y: labelText.visible ? labelText.implicitHeight + PaperTheme.pick(9, 6, 6) : 0
        height: root.boxed ? PaperTheme.size.field : Math.max(input.implicitHeight + PaperTheme.pick(7, 6, 6), 22)

        // The box — absent in hairline and in the borderless variant.
        Rectangle {
            anchors.fill: parent
            visible: root.boxed
            color: root.invalid ? PaperTheme.alertWash : root.readOnly ? PaperTheme.paperSunk : PaperTheme.paper
            radius: PaperTheme.radiusControl
            antialiasing: radius > 0
            border.width: PaperTheme.ruleWidth
            border.color: root.invalid ? PaperTheme.alertSoft : root.focused ? PaperTheme.rule2 : PaperTheme.rule
        }

        PaperIcon {
            id: leading
            visible: root.icon !== ""
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.leftMargin: root.boxed ? PaperTheme.pick(0, 8, 9) : 0
            name: root.icon
            size: root.borderless ? PaperTheme.icon.large : PaperTheme.icon.row
            color: root.focused ? PaperTheme.accent : PaperTheme.ink3
        }

        TextInput {
            id: input
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: leading.visible ? leading.right : parent.left
            anchors.right: parent.right
            anchors.leftMargin: leading.visible ? PaperTheme.gap.icon + (root.borderless ? 6 : 0) : (root.boxed ? PaperTheme.pick(0, 8, 9) : 0)
            anchors.rightMargin: root.boxed ? PaperTheme.pick(0, 8, 9) : 0
            clip: true
            enabled: !root.readOnly
            color: PaperTheme.ink
            selectionColor: PaperTheme.selection
            selectedTextColor: PaperTheme.ink
            selectByMouse: true
            cursorVisible: input.activeFocus
            font.family: PaperTheme.fontBody
            font.pixelSize: root.borderless ? PaperTheme.pick(16, 15, 21) : PaperTheme.font.size.body
            font.weight: PaperTheme.font.weight.normal
            font.hintingPreference: Font.PreferFullHinting
            renderType: TextInput.NativeRendering
            inputMethodHints: root.numeric ? Qt.ImhDigitsOnly : Qt.ImhNone
            onAccepted: root.accepted()
            onTextEdited: root.edited(text)

            // A 1 px caret, on brand.
            cursorDelegate: Rectangle {
                width: PaperTheme.ruleWidth
                color: root.invalid ? PaperTheme.alert : PaperTheme.ink
                antialiasing: false
            }
        }

        PaperText {
            anchors.fill: input
            visible: input.text.length === 0
            text: root.placeholder
            tone: "ink4"
            footnote: true
            role: root.borderless ? "lead" : "body"
            font.pixelSize: input.font.pixelSize
            elide: Text.ElideRight
        }

        // The underline. In hairline and the borderless variant it IS the field;
        // in ledger it is a 2 px mark drawn inside the box on focus; in
        // broadsheet the box's bottom hairline thickens to 2 px oxblood.
        Rectangle {
            anchors.bottom: parent.bottom
            anchors.bottomMargin: root.boxed ? PaperTheme.ruleWidth : 0
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: root.boxed ? PaperTheme.ruleWidth : 0
            anchors.rightMargin: root.boxed ? PaperTheme.ruleWidth : 0
            visible: !root.boxed || root.focused || root.invalid
            height: (root.boxed && (root.focused || root.invalid)) ? PaperTheme.markWidth : PaperTheme.ruleWidth
            color: root.markColor
            antialiasing: false
            Behavior on color {
                ColorAnimation {
                    duration: PaperTheme.motion.base
                    easing.type: PaperTheme.motion.type
                    easing.bezierCurve: PaperTheme.motion.bezierCurve
                }
            }
        }
    }

    PaperText {
        id: footerText
        visible: root.footer !== ""
        text: root.footer
        role: "meta"
        tone: root.invalid ? "alert" : "ink3"
        footnote: true
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: fieldRow.bottom
        anchors.topMargin: PaperTheme.pick(7, 5, 5)
        wrapMode: Text.WordWrap
    }
}
