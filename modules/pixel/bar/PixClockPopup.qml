import QtQuick
import qs.services
import qs.modules.pixel.common
import qs.modules.pixel.widgets

/**
 * Clock hover popup content: full date, system uptime, and a To Do section.
 * Mirrors PixelPopups.html. Null-safe against DateTime / Todo.
 */
Column {
    id: root
    spacing: 10

    readonly property string formattedDate: Qt.locale().toString(DateTime.clock.date, "dddd, MMMM dd, yyyy")
    readonly property string formattedUptime: DateTime.uptime
    readonly property string todosSection: getUpcomingTodos()

    function getUpcomingTodos() {
        const all = Todo?.list ?? [];
        const pending = all.filter(item => !item.done);
        if (pending.length === 0)
            return "No pending tasks";
        const limited = pending.slice(0, 5);
        let text = limited.map((item, i) => `${i + 1}. ${item.content}`).join("\n");
        if (pending.length > 5)
            text += `\n... and ${pending.length - 5} more`;
        return text;
    }

    Row {
        spacing: 8
        PixIcon { anchors.verticalCenter: parent.verticalCenter; name: "calendar"; size: 15 }
        PixText {
            anchors.verticalCenter: parent.verticalCenter
            text: root.formattedDate
            font.bold: true
            font.pixelSize: PixTheme.font.pixelSize.larger
        }
    }

    Row {
        spacing: 8
        PixIcon { anchors.verticalCenter: parent.verticalCenter; name: "clock"; size: 15 }
        PixText {
            anchors.verticalCenter: parent.verticalCenter
            text: "System uptime: "
            font.pixelSize: PixTheme.font.pixelSize.larger
        }
        PixText {
            anchors.verticalCenter: parent.verticalCenter
            text: root.formattedUptime
            font.bold: true
            font.pixelSize: PixTheme.font.pixelSize.larger
        }
    }

    // Divider rule above the To Do section
    Rectangle {
        width: root.width
        height: 2
        color: PixTheme.colors.line
        antialiasing: false
    }

    Row {
        spacing: 8
        PixIcon { anchors.verticalCenter: parent.verticalCenter; name: "todo"; size: 15 }
        PixText {
            anchors.verticalCenter: parent.verticalCenter
            text: "To Do"
            font.bold: true
            font.pixelSize: PixTheme.font.pixelSize.larger
        }
    }

    PixText {
        leftPadding: 23
        text: root.todosSection
        wrapMode: Text.Wrap
        color: PixTheme.colors.grey
        font.pixelSize: PixTheme.font.pixelSize.large
    }
}
