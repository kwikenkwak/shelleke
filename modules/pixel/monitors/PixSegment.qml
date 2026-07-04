pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.modules.pixel.common
import qs.modules.pixel.widgets

/**
 * A small segmented selector: a row of hollow squares, the current one filled.
 * options = [{ label, value }]. Emits picked(value) on tap.
 */
RowLayout {
    id: root
    property var options: []
    property var value
    signal picked(var value)
    spacing: 6

    Repeater {
        model: root.options
        delegate: PixButton {
            id: seg
            required property var modelData
            Layout.fillWidth: true
            Layout.preferredHeight: 30
            filled: root.value === modelData.value
            onClicked: root.picked(modelData.value)
            PixText {
                anchors.centerIn: parent
                text: seg.modelData.label
                font.pixelSize: PixTheme.font.pixelSize.small
                color: seg.contentColor
            }
        }
    }
}
