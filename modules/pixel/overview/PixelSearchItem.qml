pragma ComponentBehavior: Bound
import qs
import qs.services
import qs.modules.common
import qs.modules.common.models
import qs.modules.pixel.common
import qs.modules.pixel.widgets
import QtQuick
import QtQuick.Layouts
import Quickshell

/**
 * A single launcher-search result row for the pixel overview.
 *
 * The data model + execute behavior is the SAME as `modules/ii/overview/
 * SearchItem.qml` (a `LauncherSearchResult` entry; click → close overview +
 * entry.execute()). Restyled to the pixel idiom: hard-edged hover/selection fill
 * with inverted (bg) content, Pixelify body text, Silkscreen-ish verb label, and
 * app/system icons rendered through `PixAppIcon` (grayscale + pixelated) so no
 * app contributes color. Material-symbol and text icon types fall back to a
 * monospace glyph / the raw text (e.g. emoji), since the pixel family has no
 * Material symbol font.
 */
Rectangle {
    id: root
    property var entry
    property string query
    property bool entryShown: entry?.shown ?? true
    property string itemType: entry?.type ?? ""
    property string itemName: entry?.name ?? ""
    property var iconType: entry?.iconType
    property string iconName: entry?.iconName ?? ""
    property var itemExecute: entry?.execute
    property string itemClickActionName: entry?.verb ?? "Open"
    property bool selected: ListView.isCurrentItem

    signal clicked()

    visible: root.entryShown
    implicitHeight: rowLayout.implicitHeight + 12
    height: visible ? implicitHeight : 0

    radius: 0
    antialiasing: false
    readonly property bool active: selected || mouseArea.containsMouse
    color: mouseArea.containsPress ? PixTheme.colors.grey
        : active ? PixTheme.colors.line
        : "transparent"
    readonly property color contentColor: active ? PixTheme.colors.bg : PixTheme.colors.fg

    function trigger() {
        GlobalStates.overviewOpen = false;
        if (root.itemExecute)
            root.itemExecute();
    }
    onClicked: root.trigger()

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.trigger()
    }

    RowLayout {
        id: rowLayout
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        spacing: 10

        // Icon — app/system icons through PixAppIcon (grayscale), others as glyph/text
        Loader {
            id: iconLoader
            Layout.alignment: Qt.AlignVCenter
            active: true
            sourceComponent: switch (root.iconType) {
                case LauncherSearchResult.IconType.System: return systemIconComponent;
                case LauncherSearchResult.IconType.Material: return glyphComponent;
                case LauncherSearchResult.IconType.Text: return textIconComponent;
                default: return spacerComponent;
            }
        }
        Component {
            id: systemIconComponent
            PixAppIcon {
                icon: root.iconName
                size: 28
                pixelResolution: 16
            }
        }
        Component {
            id: glyphComponent
            PixIcon {
                name: "terminal"
                size: 21
                color: root.contentColor
            }
        }
        Component {
            id: textIconComponent
            PixText {
                text: root.iconName
                font.pixelSize: PixTheme.font.pixelSize.large
                color: root.contentColor
            }
        }
        Component {
            id: spacerComponent
            Item { width: 4; height: 1 }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: 0

            PixText {
                visible: root.itemType !== "" && root.itemType !== "App"
                text: root.itemType
                font.pixelSize: PixTheme.font.pixelSize.smaller
                color: root.active ? PixTheme.colors.bg : PixTheme.colors.grey
            }
            PixText {
                Layout.fillWidth: true
                text: root.itemName
                font.pixelSize: PixTheme.font.pixelSize.normal
                color: root.contentColor
                elide: Text.ElideRight
            }
        }

        PixTitle {
            visible: root.active
            text: root.itemClickActionName
            font.pixelSize: PixTheme.font.pixelSize.smaller
            color: root.contentColor
        }
    }
}
