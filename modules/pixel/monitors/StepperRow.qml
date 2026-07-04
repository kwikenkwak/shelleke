pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.modules.pixel.common
import qs.modules.pixel.widgets

/**
 * A labelled integer stepper: label + optional help on the left, [-] value [+]
 * on the right. Emits changed(v) with the clamped new value.
 */
RowLayout {
    id: root
    property string label: ""
    property string help: ""
    property int value: 0
    property int from: 0
    property int to: 999999
    property int step: 1
    signal changed(int v)

    spacing: 8

    ColumnLayout {
        Layout.fillWidth: true
        spacing: 0
        PixText { text: root.label; font.bold: true; font.pixelSize: PixTheme.font.pixelSize.small }
        PixText {
            Layout.fillWidth: true
            visible: root.help.length > 0
            text: root.help
            color: PixTheme.colors.grey
            font.pixelSize: PixTheme.font.pixelSize.smallest
            wrapMode: Text.WordWrap
        }
    }
    PixButton {
        implicitWidth: 30; implicitHeight: 28
        onClicked: root.changed(Math.max(root.from, root.value - root.step))
        PixText { anchors.centerIn: parent; text: "−"; font.bold: true
            font.pixelSize: PixTheme.font.pixelSize.large; color: parent.contentColor }
    }
    PixText {
        Layout.preferredWidth: 42
        horizontalAlignment: Text.AlignHCenter
        text: root.value
        font.bold: true
        font.pixelSize: PixTheme.font.pixelSize.normal
    }
    PixButton {
        implicitWidth: 30; implicitHeight: 28
        onClicked: root.changed(Math.min(root.to, root.value + root.step))
        PixText { anchors.centerIn: parent; text: "+"; font.bold: true
            font.pixelSize: PixTheme.font.pixelSize.large; color: parent.contentColor }
    }
}
