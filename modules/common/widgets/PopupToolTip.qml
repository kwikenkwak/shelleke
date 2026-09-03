pragma ComponentBehavior: Bound
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell

Item {
    id: root
    property string text: ""
    property bool extraVisibleCondition: true
    property bool alternativeVisibleCondition: false
    property real horizontalPadding: 10
    property real verticalPadding: 5
    property real horizontalMargin: horizontalPadding
    property real verticalMargin: verticalPadding
    
    function updateAnchor() {
        tooltipLoader.item?.anchor.updateAnchor();
    }

    readonly property bool internalVisibleCondition: (extraVisibleCondition && (parent.hovered === undefined || parent?.hovered)) || alternativeVisibleCondition
    property var anchorEdges: Edges.Top
    property var anchorGravity: anchorEdges

    property Item contentItem: StyledToolTipContent {
        id: contentItem
        anchors.centerIn: parent
        text: root.text
        shown: false
        Component.onCompleted: shown = true
        horizontalPadding: root.horizontalPadding
        verticalPadding: root.verticalPadding
    }

    Loader {
        id: tooltipLoader
        anchors.fill: parent
        active: root.internalVisibleCondition
        sourceComponent: PopupWindow {
            id: popup

            // The anchor, SNAPSHOT at creation — never a live binding.
            // `QsWindow.window` re-resolves on every `windowChanged` in the
            // tree it is attached to, including the ones Qt emits while it is
            // tearing that tree down (a reload, or a ListView releasing the
            // delegate this tooltip sits in). Reading it then dereferences a
            // half-destroyed item and segfaults inside QQuickItem::window().
            // Same fix as modules/paper/widgets/PaperTooltip.qml, which has the
            // long version of the note.
            property var anchorWindow: null
            property var anchorItem: null
            Component.onCompleted: {
                popup.anchorWindow = root.QsWindow.window;
                popup.anchorItem = root.parent;
            }

            visible: popup.anchorWindow !== null && popup.anchorItem !== null
            anchor {
                window: popup.anchorWindow
                item: popup.anchorItem
                edges: root.anchorEdges
                gravity: root.anchorGravity
            }
            mask: Region {
                item: null
            }

            color: "transparent"
            implicitWidth: root.contentItem.implicitWidth + root.horizontalMargin * 2
            implicitHeight: root.contentItem.implicitHeight + root.verticalMargin * 2

            data: [root.contentItem]
        }
    }
}
