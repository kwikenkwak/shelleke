import QtQuick
import qs.services
import qs.modules.pixel.common
import qs.modules.pixel.widgets

/**
 * Clock: "HH:mm · ddd, dd/MM", bold. Hovering shows the clock hover popup
 * (full date, uptime, To Do). Bound to the DateTime service.
 */
MouseArea {
    id: root
    hoverEnabled: true
    implicitWidth: label.implicitWidth
    implicitHeight: 32

    readonly property string text: {
        const d = DateTime.clock?.date ?? new Date();
        return Qt.locale().toString(d, "HH:mm") + " · " + Qt.locale().toString(d, "ddd, dd/MM");
    }

    PixText {
        id: label
        anchors.centerIn: parent
        text: root.text
        font.bold: true
        font.pixelSize: PixTheme.font.pixelSize.title
    }

    PixelBarPopup {
        hoverTarget: root
        PixClockPopup {}
    }
}
