import QtQuick
import qs.modules.pixel.common
import qs.modules.pixel.widgets

/**
 * A bordered, monochrome single-line text field with a placeholder. Border
 * brightens on focus. Call focusInput() to grab keyboard focus (the panel uses
 * WlrKeyboardFocus.OnDemand, so this is what makes typing work).
 */
Rectangle {
    id: root
    property alias text: input.text
    property string placeholder: ""
    property bool numeric: false
    property bool editable: true
    signal accepted
    signal edited(string t)   // fires on every keystroke (live model updates)

    function focusInput() {
        input.forceActiveFocus();
    }

    implicitHeight: 32
    radius: 0
    antialiasing: false
    color: "transparent"
    border.width: PixTheme.borderWidth
    border.color: input.activeFocus ? PixTheme.colors.fg : PixTheme.colors.line

    TextInput {
        id: input
        anchors.fill: parent
        anchors.leftMargin: 8
        anchors.rightMargin: 8
        verticalAlignment: TextInput.AlignVCenter
        clip: true
        enabled: root.editable
        color: PixTheme.colors.fg
        selectionColor: PixTheme.colors.fg
        selectedTextColor: PixTheme.colors.bg
        selectByMouse: true
        font.family: PixTheme.fontMain
        font.pixelSize: PixTheme.font.pixelSize.normal
        inputMethodHints: root.numeric ? Qt.ImhDigitsOnly : Qt.ImhNone
        onAccepted: root.accepted()
        onTextEdited: root.edited(text)
    }
    PixText {
        anchors.left: parent.left
        anchors.leftMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        visible: input.text.length === 0 && !input.activeFocus
        text: root.placeholder
        color: PixTheme.colors.grey
        font.pixelSize: PixTheme.font.pixelSize.normal
    }
}
