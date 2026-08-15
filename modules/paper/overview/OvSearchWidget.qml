pragma ComponentBehavior: Bound
import qs
import qs.services
import qs.modules.common
import qs.modules.paper.common
import qs.modules.paper.widgets
import QtQuick
import Quickshell

/**
 * The launcher field + result list of the paper overview.
 *
 * Wired to the SAME `LauncherSearch` singleton as the ii and pixel families, so
 * the app / run / math / clipboard / emoji / web-search / action prefixes and
 * every keyboard gesture behave identically: typing anywhere routes into the
 * field, Backspace edits, Ctrl+J/K move the selection, Enter runs the current
 * row. That logic is ported verbatim from PixelSearchWidget.
 *
 * The field and the result list are ONE sheet in all three variants — what
 * differs is the seam between them:
 *
 *   hairline   — the field has no box at all; its own underline (`rule-2` at
 *                rest, `ink` while typing) IS the seam. 600 px, query 16 px.
 *   ledger     — 560 × 46; the field loses its bottom corners, the list loses
 *                its top border and a single hairline runs across the seam,
 *                turning `accent` while the field has focus.
 *   broadsheet — a 560 × 48 floating masthead with corner ticks, Pagella 21
 *                and an oxblood caret; the result sheet joins seam-to-seam.
 */
Item {
    id: root

    property alias searchingText: searchInput.text
    readonly property bool typing: searchInput.text !== ""
    readonly property bool showResults: root.typing && appResults.count > 0

    // Per-variant field metrics. A pads roughly twice as much as the others,
    // which is the whole point of its "no box" field.
    readonly property int fieldHeight: PaperTheme.pick(54, 46, 48)
    readonly property int padH: PaperTheme.pick(22, 14, 14)
    readonly property int gutter: PaperTheme.pick(14, 11, 11)
    readonly property int querySize: PaperTheme.pick(16, 15, 21)
    /// Inner margin of the result list inside the sheet.
    readonly property int listPad: PaperTheme.pick(6, 0, 6)

    /// The seam. Hairline draws it always (it doubles as the field underline);
    /// the other two only once results hang below.
    readonly property bool seamVisible: PaperTheme.isHairline || root.showResults
    readonly property string seamTone: {
        if (PaperTheme.isBroadsheet)
            return "rule";
        if (PaperTheme.isHairline)
            return root.typing ? "ink" : "rule2";
        return searchInput.activeFocus ? "accent" : "rule";
    }

    implicitWidth: sheet.implicitWidth
    implicitHeight: sheet.implicitHeight

    function focusFirstItem(): void {
        if (appResults.count > 0)
            appResults.currentIndex = 0;
    }
    function focusSearchInput(): void {
        searchInput.forceActiveFocus();
    }
    function disableExpandAnimation(): void {}
    function cancelSearch(): void {
        searchInput.text = "";
        LauncherSearch.query = "";
    }
    function setSearchingText(text: string): void {
        searchInput.text = text;
        LauncherSearch.query = text;
    }

    // Ported verbatim from PixelSearchWidget: every keystroke in the overlay
    // ends up in the field, whichever item happens to hold focus.
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
                    searchInput.text = searchInput.text.slice(0, searchInput.cursorPosition - 1) + searchInput.text.slice(searchInput.cursorPosition);
                }
                searchInput.cursorPosition = searchInput.text.length;
                event.accepted = true;
            }
            return;
        }

        if (event.text && event.text.length === 1 && event.key !== Qt.Key_Enter && event.key !== Qt.Key_Return && event.key !== Qt.Key_Delete && event.text.charCodeAt(0) >= 0x20) {
            if (!searchInput.activeFocus) {
                root.focusSearchInput();
                searchInput.text = searchInput.text.slice(0, searchInput.cursorPosition) + event.text + searchInput.text.slice(searchInput.cursorPosition);
                searchInput.cursorPosition += 1;
                event.accepted = true;
                root.focusFirstItem();
            }
        }
    }

    PaperPanel {
        id: sheet
        kind: "sheet"
        floating: true
        ticks: true
        clip: true
        implicitWidth: PaperTheme.size.searchWidth
        implicitHeight: root.fieldHeight + (root.showResults ? PaperTheme.ruleWidth + resultsBox.height : 0)

        Behavior on implicitHeight {
            NumberAnimation {
                duration: PaperTheme.motion.fast
                easing.type: PaperTheme.motion.type
                easing.bezierCurve: PaperTheme.motion.bezierCurve
            }
        }

        // ------------------------------------------------------------ field
        Item {
            id: fieldRow
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: root.fieldHeight

            PaperIcon {
                id: searchGlyph
                anchors.verticalCenter: parent.verticalCenter
                x: root.padH
                name: "search"
                size: PaperTheme.pick(18, 18, 20)
                // B turns the glyph blue on focus; A darkens it while typing;
                // C keeps it quiet — the caret carries the colour there.
                color: PaperTheme.isBroadsheet ? PaperTheme.ink3 : PaperTheme.isLedger ? (searchInput.activeFocus ? PaperTheme.accent : PaperTheme.ink3) : (root.typing ? PaperTheme.ink2 : PaperTheme.ink3)
            }

            TextInput {
                id: searchInput
                anchors.verticalCenter: parent.verticalCenter
                x: searchGlyph.x + searchGlyph.width + root.gutter
                width: hint.x - x - root.gutter
                focus: GlobalStates.overviewOpen
                activeFocusOnTab: true
                selectByMouse: true
                clip: true
                color: PaperTheme.ink
                selectionColor: PaperTheme.selection
                selectedTextColor: PaperTheme.ink
                renderType: Text.NativeRendering
                verticalAlignment: TextInput.AlignVCenter
                font {
                    // C sets the query in the display face; A and B in body type.
                    family: PaperTheme.isBroadsheet ? PaperTheme.fontTitle : PaperTheme.fontBody
                    pixelSize: root.querySize
                    weight: PaperTheme.font.weight.normal
                    hintingPreference: Font.PreferFullHinting
                }

                // A 1 px caret in the variant's active ink — oxblood in C.
                cursorDelegate: Rectangle {
                    width: PaperTheme.ruleWidth
                    color: PaperTheme.isHairline ? PaperTheme.ink : PaperTheme.accent
                    antialiasing: false
                }

                onTextChanged: LauncherSearch.query = text
                onAccepted: {
                    let item = appResults.itemAtIndex(Math.max(0, appResults.currentIndex));
                    if (item)
                        item.trigger();
                }
            }

            PaperText {
                id: placeholder
                anchors.verticalCenter: parent.verticalCenter
                x: searchInput.x
                visible: searchInput.text === ""
                text: "Search, calculate or run"
                tone: "ink4"
                footnote: true
                // Italic Pagella in C, plain body type in A and B.
                font.pixelSize: root.querySize
            }

            // ---- right-hand cut-in -------------------------------------
            // A: a result count in micro-caps. B: a ⏎ chip at rest, the count
            // in mono while typing. C: the accelerator hint as a footnote, and
            // a calculation result printed in oldstyle figures.
            Item {
                id: hint
                anchors.verticalCenter: parent.verticalCenter
                x: fieldRow.width - root.padH - width
                width: hintRow.implicitWidth
                height: parent.height

                Row {
                    id: hintRow
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: PaperTheme.gap.value

                    // C only: the math answer, set at query size in oxblood.
                    PaperText {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: PaperTheme.isBroadsheet && root.mathAnswer !== ""
                        text: root.mathAnswer
                        figure: true
                        tone: "accent"
                        font.pixelSize: root.querySize
                    }

                    PaperText {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: PaperTheme.isBroadsheet
                        text: "ctrl+j / ctrl+k"
                        role: "micro"
                        tone: "ink4"
                        footnote: true
                        font.capitalization: Font.MixedCase
                        font.letterSpacing: 0
                    }

                    PaperText {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: PaperTheme.isHairline && root.typing
                        text: `${appResults.count} results`
                        role: "micro"
                    }

                    PaperText {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: PaperTheme.isLedger && root.typing
                        text: `${appResults.count} results`
                        role: "micro"
                        mono: true
                        tone: "ink4"
                        font.capitalization: Font.MixedCase
                        font.letterSpacing: 0
                    }

                    // Ledger's resting ⏎ hint — the shared chip, marked
                    // non-interactive so it keeps the chip body without
                    // becoming something you can press.
                    PaperChip {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: PaperTheme.isLedger && !root.typing
                        interactive: false
                        label: "⏎"
                    }
                }
            }
        }

        // ------------------------------------------------------------- seam
        PaperRule {
            id: seam
            anchors.top: fieldRow.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            visible: root.seamVisible
            tone: root.seamTone
            z: 3
        }

        // ---------------------------------------------------------- results
        Item {
            id: resultsBox
            anchors.top: seam.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            visible: root.showResults
            height: root.showResults ? Math.min(PaperTheme.size.searchResultsMax, appResults.contentHeight + 2 * root.listPad) : 0

            ListView {
                id: appResults
                anchors.fill: parent
                anchors.topMargin: root.listPad
                anchors.bottomMargin: root.listPad
                clip: true
                spacing: 0
                highlightMoveDuration: PaperTheme.motion.base
                currentIndex: 0
                boundsBehavior: Flickable.StopAtBounds

                Connections {
                    target: LauncherSearch
                    function onResultsChanged(): void {
                        root.focusFirstItem();
                    }
                }

                model: ScriptModel {
                    objectProp: "key"
                    values: LauncherSearch.results
                }

                delegate: OvSearchRow {
                    required property var modelData
                    width: appResults.width
                    entry: modelData
                    sidePad: root.padH
                    gutter: root.gutter
                }
            }
        }
    }

    /// The current math answer, if the query is a calculation. Only C prints it
    /// in the field itself (§4.6 of its SPEC).
    readonly property string mathAnswer: {
        if (!root.typing)
            return "";
        if (!root.searchingText.startsWith(Config.options.search.prefix.math))
            return "";
        return LauncherSearch.mathResult ?? "";
    }
}
