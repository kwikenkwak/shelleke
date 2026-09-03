import QtQuick
import qs.services
import qs.modules.paper.common
import qs.modules.paper.widgets

/**
 * The headphone chip's hover popup: the connected audio peripheral in the
 * header, then one reported line per peripheral that has a battery — including
 * the non-audio ones (mice, keyboards), which the bar itself never shows.
 *
 * Structurally the small sibling of `BarBatteryPopup`: same sheet width family,
 * same header → Oxford rule → value rows shape, but one header for all three
 * variants (there is only a glyph, a name and a figure to place) with the
 * ledger meter and the broadsheet footnote switched in.
 */
Column {
    id: root

    readonly property real sheetWidth: PaperTheme.pick(288, 244, 260)
    readonly property real percent: PeripheralBattery.percentage * 100
    readonly property real criticalAt: PaperTheme.pick(15, 10, 15)
    readonly property bool critical: PeripheralBattery.available && root.percent <= root.criticalAt && !PeripheralBattery.charging

    function glyphFor(kind: string): string {
        switch (kind) {
        case "earbuds":
            return "earbuds";
        case "speaker":
            return "speaker";
        case "mouse":
            return "dot";
        case "keyboard":
            return "keyboard";
        case "phone":
            return "phone";
        case "headphones":
            return "headphones";
        default:
            return "bluetooth";
        }
    }

    function titleFor(kind: string): string {
        switch (kind) {
        case "earbuds":
            return "Earbuds";
        case "speaker":
            return "Speaker";
        case "mouse":
            return "Mouse";
        case "keyboard":
            return "Keyboard";
        case "phone":
            return "Phone";
        case "headphones":
            return "Headphones";
        default:
            return "Device";
        }
    }

    width: root.sheetWidth
    spacing: PaperTheme.pick(11, 5, 6)

    // ---- header -------------------------------------------------------------
    Item {
        width: parent.width
        implicitHeight: Math.max(headGlyph.implicitHeight, headText.implicitHeight)

        PaperIcon {
            id: headGlyph
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            name: root.glyphFor(PeripheralBattery.kind)
            size: PaperTheme.pick(20, 18, 22)
            color: root.critical ? PaperTheme.alert : PaperTheme.ink2
        }

        Column {
            id: headText
            anchors.left: headGlyph.right
            anchors.leftMargin: PaperTheme.spacing.medium
            anchors.right: headPercent.left
            anchors.rightMargin: PaperTheme.spacing.sm
            anchors.verticalCenter: parent.verticalCenter
            spacing: 1

            PaperText {
                width: parent.width
                text: root.titleFor(PeripheralBattery.kind)
                role: "micro"
            }
            PaperText {
                width: parent.width
                text: PeripheralBattery.available ? PeripheralBattery.name : "Nothing connected"
                role: PaperTheme.isHairline ? "small" : "body"
                elide: Text.ElideRight
            }
        }

        PaperText {
            id: headPercent
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: PeripheralBattery.available ? `${Math.round(root.percent)}${PaperTheme.isHairline ? " %" : "%"}` : "—"
            figure: true
            color: root.critical ? PaperTheme.alert : PaperTheme.ink
            font.pixelSize: PaperTheme.pick(15, 14, 17)
        }
    }

    // Ledger measures everything against a ruler.
    PaperMeter {
        visible: PaperTheme.isLedger && PeripheralBattery.available
        width: parent.width
        value: root.percent / 100
        alert: root.critical
    }

    // ---- rule under the header ----------------------------------------------
    Item {
        visible: PeripheralBattery.devices.length > 0
        width: parent.width
        implicitHeight: headRule.thickness + PaperTheme.pick(16, 11, 12)
        PaperRule {
            id: headRule
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            weight: "oxford"
        }
    }

    // ---- one line per peripheral --------------------------------------------
    Repeater {
        model: PeripheralBattery.devices
        delegate: BarValueRow {
            required property var modelData
            width: root.width
            icon: root.glyphFor(modelData.kind)
            label: modelData.name
            value: `${Math.round(modelData.percentage * 100)}%`
            alert: modelData.percentage * 100 <= root.criticalAt && !modelData.charging
            kicker: true
        }
    }

    // ---- broadsheet's closing footnote --------------------------------------
    Item {
        visible: PaperTheme.isBroadsheet
        width: parent.width
        implicitHeight: footRule.thickness + PaperTheme.spacing.medium
        PaperRule {
            id: footRule
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
        }
    }
    PaperText {
        visible: PaperTheme.isBroadsheet
        width: parent.width
        text: PeripheralBattery.charging ? "Charging" : PeripheralBattery.available ? "Reported over Bluetooth" : "No peripheral reporting"
        role: "meta"
        tone: "ink4"
        footnote: true
    }

    PaperText {
        visible: !PaperTheme.isBroadsheet && !PeripheralBattery.available
        text: "No peripheral reporting"
        role: "small"
        tone: "ink4"
        footnote: true
    }
}
