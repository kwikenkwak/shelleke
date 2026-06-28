import QtQuick
import qs.modules.pixel.common

/**
 * A bordered, square pixel button. Monochrome interaction model:
 *   - default : transparent fill, line border, fg content
 *   - active/checked/hover/press : filled with `line`, content flips to `bg`
 *
 * Put icons/labels as children; bind their color to `root.contentColor` so they
 * invert correctly. Set `filled: true` for a permanently-filled (selected) look.
 */
Rectangle {
    id: root
    property bool filled: false
    property bool checked: false
    property bool interactive: true
    // Whether hover should visually fill the button (invert). Some chips (e.g.
    // the app-pin group) are non-interactive and keep this off.
    property bool fillOnHover: true
    property int borderWidth: PixTheme.borderWidth

    readonly property bool active: filled || checked || (interactive && fillOnHover && mouseArea.containsMouse)
    readonly property bool pressed: interactive && mouseArea.containsPress
    // Content (icons/text) should bind to this so it inverts on fill.
    readonly property color contentColor: active ? PixTheme.colors.bg : PixTheme.colors.fg

    signal clicked()
    signal rightClicked()

    radius: 0
    antialiasing: false
    color: pressed ? PixTheme.colors.grey
        : active ? PixTheme.colors.line
        : "transparent"
    border.width: borderWidth
    border.color: PixTheme.colors.line

    implicitWidth: 34
    implicitHeight: 34

    Behavior on color {
        ColorAnimation {
            duration: PixTheme.animation.duration
            easing.type: PixTheme.animation.type
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        enabled: root.interactive
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: root.interactive ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: (mouse) => {
            if (mouse.button === Qt.RightButton)
                root.rightClicked();
            else
                root.clicked();
        }
    }
}
