import QtQuick
import qs.services
import qs.modules.pixel.common
import qs.modules.pixel.widgets

/**
 * Battery chip: a 2px-bordered chip with the pixel battery glyph + percent text.
 * Hovering shows the battery hover popup. Clicking opens pixel quick settings.
 * Bound to the Battery service; null-safe and hidden when no battery present.
 */
MouseArea {
    id: root
    // Named 'activated' (not 'clicked') to avoid shadowing MouseArea's built-in
    // clicked(MouseEvent) signal, which would leave onClicked unwired.
    signal activated()

    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    acceptedButtons: Qt.LeftButton
    onClicked: root.activated()

    readonly property real percent: (Battery.percentage ?? 0) * 100
    readonly property bool charging: Battery.isCharging

    visible: Battery.available
    implicitWidth: visible ? chip.implicitWidth : 0
    implicitHeight: 30

    PixButton {
        id: chip
        anchors.centerIn: parent
        interactive: false
        fillOnHover: false
        borderWidth: PixTheme.borderWidth
        implicitWidth: chipRow.implicitWidth + 14
        implicitHeight: 30

        Row {
            id: chipRow
            anchors.centerIn: parent
            spacing: 6

            PixBatteryGlyph {
                anchors.verticalCenter: parent.verticalCenter
                percent: root.percent
                charging: root.charging
                color: chip.contentColor
                u: 1
            }
            PixText {
                anchors.verticalCenter: parent.verticalCenter
                text: Math.round(root.percent)
                color: chip.contentColor
                font.bold: true
                font.pixelSize: PixTheme.font.pixelSize.large
            }
        }
    }

    PixTooltip {
        text: root.charging
            ? Math.round(root.percent) + "% · Charging"
            : Math.round(root.percent) + "%"
        visibleCondition: root.containsMouse
    }

    PixelBarPopup {
        hoverTarget: root
        PixBatteryPopup {}
    }
}
