pragma ComponentBehavior: Bound
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.pixel.common
import qs.modules.pixel.widgets
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell

/**
 * Pixel launcher-search box + result list.
 *
 * Wired to the SAME `LauncherSearch` singleton as `modules/ii/overview/
 * SearchWidget.qml`: it drives `LauncherSearch.query` and renders
 * `LauncherSearch.results`, so apps / run / math / clipboard / emoji / web /
 * action prefixes all behave identically to ii. The keyboard handling is ported
 * too — typing anywhere routes into the field, Backspace edits, Ctrl+J/K move
 * the selection, Enter triggers the first/selected result.
 *
 * Restyled to the pixel idiom: a hard-bordered (radius 0) PixPanel with a
 * PixIcon glyph + monospace-ish Pixelify input, a separator line, then a list of
 * PixelSearchItem rows. No rounding/shadow/accent color.
 */
Item {
    id: root
    property alias searchingText: searchInput.text
    property bool showResults: searchInput.text !== ""

    property int fieldWidth: 560
    property int fieldHeight: 48

    implicitWidth: container.implicitWidth
    implicitHeight: container.implicitHeight

    function focusFirstItem() {
        if (appResults.count > 0)
            appResults.currentIndex = 0;
    }
    function focusSearchInput() {
        searchInput.forceActiveFocus();
    }
    function disableExpandAnimation() {}
    function cancelSearch() {
        searchInput.text = "";
        LauncherSearch.query = "";
    }
    function setSearchingText(text) {
        searchInput.text = text;
        LauncherSearch.query = text;
    }

    Keys.onPressed: event => {
        if (event.modifiers & Qt.ControlModifier) {
            if (event.key === Qt.Key_J) {
                if (appResults.currentIndex < appResults.count - 1)
                    appResults.currentIndex = appResults.currentIndex + 1;
                event.accepted = true;
                return;
            } else if (event.key === Qt.Key_K) {
                if (appResults.currentIndex > 0)
                    appResults.currentIndex = appResults.currentIndex - 1;
                event.accepted = true;
                return;
            }
        }
        if (event.key === Qt.Key_Escape)
            return;

        if (event.key === Qt.Key_Backspace) {
            if (!searchInput.activeFocus) {
                root.focusSearchInput();
                if (searchInput.cursorPosition > 0) {
                    searchInput.text = searchInput.text.slice(0, searchInput.cursorPosition - 1)
                        + searchInput.text.slice(searchInput.cursorPosition);
                }
                searchInput.cursorPosition = searchInput.text.length;
                event.accepted = true;
            }
            return;
        }

        if (event.text && event.text.length === 1
            && event.key !== Qt.Key_Enter && event.key !== Qt.Key_Return
            && event.key !== Qt.Key_Delete && event.text.charCodeAt(0) >= 0x20) {
            if (!searchInput.activeFocus) {
                root.focusSearchInput();
                searchInput.text = searchInput.text.slice(0, searchInput.cursorPosition)
                    + event.text + searchInput.text.slice(searchInput.cursorPosition);
                searchInput.cursorPosition += 1;
                event.accepted = true;
                root.focusFirstItem();
            }
        }
    }

    ColumnLayout {
        id: container
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 0

        PixPanel { // Search field
            id: fieldPanel
            borderWidth: PixTheme.popupBorderWidth
            Layout.alignment: Qt.AlignHCenter
            implicitWidth: root.fieldWidth
            implicitHeight: root.fieldHeight

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                spacing: 10

                PixIcon {
                    Layout.alignment: Qt.AlignVCenter
                    name: "puzzle"
                    size: 21
                    color: PixTheme.colors.fg
                }

                TextField {
                    id: searchInput
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    focus: GlobalStates.overviewOpen
                    color: PixTheme.colors.fg
                    selectionColor: PixTheme.colors.line
                    selectedTextColor: PixTheme.colors.bg
                    placeholderText: "Search, calculate or run"
                    placeholderTextColor: PixTheme.colors.grey
                    font.family: PixTheme.fontMain
                    font.pixelSize: PixTheme.font.pixelSize.large
                    background: null
                    verticalAlignment: TextInput.AlignVCenter

                    onTextChanged: LauncherSearch.query = text
                    onAccepted: {
                        let item = appResults.itemAtIndex(Math.max(0, appResults.currentIndex));
                        if (item)
                            item.trigger();
                    }
                }
            }
        }

        Rectangle { // Separator (overlaps borders cleanly)
            visible: root.showResults && appResults.count > 0
            Layout.fillWidth: true
            Layout.topMargin: -PixTheme.popupBorderWidth
            implicitHeight: PixTheme.popupBorderWidth
            color: PixTheme.colors.line
        }

        PixPanel { // Results list
            id: resultsPanel
            visible: root.showResults && appResults.count > 0
            borderWidth: PixTheme.popupBorderWidth
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: -PixTheme.popupBorderWidth
            implicitWidth: root.fieldWidth
            implicitHeight: visible ? Math.min(520, appResults.contentHeight + 12) : 0

            ListView {
                id: appResults
                anchors.fill: parent
                anchors.margins: PixTheme.popupBorderWidth + 3
                clip: true
                spacing: 2
                highlightMoveDuration: 80
                currentIndex: 0

                Connections {
                    target: LauncherSearch
                    function onResultsChanged() {
                        root.focusFirstItem();
                    }
                }

                model: ScriptModel {
                    objectProp: "key"
                    values: LauncherSearch.results
                }

                delegate: PixelSearchItem {
                    required property var modelData
                    width: appResults.width
                    entry: modelData
                    query: StringUtils.cleanOnePrefix(root.searchingText, [
                        Config.options.search.prefix.action,
                        Config.options.search.prefix.app,
                        Config.options.search.prefix.clipboard,
                        Config.options.search.prefix.emojis,
                        Config.options.search.prefix.math,
                        Config.options.search.prefix.shellCommand,
                        Config.options.search.prefix.webSearch
                    ])
                }
            }
        }
    }
}
