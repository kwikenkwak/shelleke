import QtQuick
import qs.modules.paper.common

/**
 * The hairline — the one structural device the whole family is built from.
 *
 *   PaperRule {}                                   // horizontal, 1 px, `rule`
 *   PaperRule { weight: "fine" }                   // 1 px, `rule2` — aimable
 *   PaperRule { weight: "double" }                 // closes a block (C)
 *   PaperRule { weight: "oxford" }                 // a masthead (C)
 *   PaperRule { vertical: true; length: 14 }       // bar divider
 *   PaperRule { weight: "mark"; tone: "accent" }   // the selection underline
 *
 * `double` and `oxford` degrade to a single hairline in hairline and ledger,
 * which do not have those ornaments — so a surface can write `weight: "oxford"`
 * for its masthead unconditionally and get the right thing everywhere.
 *
 * Rules are drawn as 1 LOGICAL px. On fractional-scale outputs Qt snaps them;
 * do not try to out-clever it with sub-pixel heights, and never let a rule
 * become 0 by dividing by devicePixelRatio.
 */
Item {
    id: root

    /// hair | fine | mark | double | oxford
    property string weight: "hair"
    /// Override the colour: rule | rule2 | ink | accent | alert | link | seal |
    /// ink4 (dotted-disabled). Empty picks the weight's natural tone.
    property string tone: ""
    property bool vertical: false
    /// Along-axis length. Defaults to filling the parent on the long axis.
    property real length: -1
    /// A dotted rule — broadsheet's disabled treatment.
    property bool dotted: false
    /// Hard colour override, for a rule printed on a ground the palette does not
    /// describe — the session screen's masthead sits on a dark scrim where every
    /// ink/rule token is the wrong way round. `null` (the default) keeps the
    /// `tone`/weight colour, so ordinary call sites never see this.
    ///
    ///   PaperRule { weight: "oxford"; colorOverride: PaperTheme.paper }
    ///
    /// Note this is the ONLY sanctioned way to escape the palette: it exists
    /// because an Oxford rule hardcodes `ink` for its thick half, and a
    /// scrim-borne masthead needs that half in paper.
    property var colorOverride: null
    /// Override for the THIN half of a double / Oxford rule. Defaults to
    /// `colorOverride` when that is set, so one property does the usual job.
    property var secondaryColorOverride: null

    readonly property bool isDouble: root.weight === "double" && PaperTheme.ornament.doubleRules
    readonly property bool isOxford: root.weight === "oxford" && PaperTheme.ornament.oxfordRules

    /// Thickness across the axis, including any gap.
    readonly property real thickness: root.isOxford ? PaperTheme.oxfordThick + PaperTheme.ruleGap + PaperTheme.ruleWidth : root.isDouble ? PaperTheme.ruleWidth + PaperTheme.ruleGap + PaperTheme.ruleWidth : root.weight === "mark" ? PaperTheme.markWidth : PaperTheme.ruleWidth

    readonly property color toneColor: {
        switch (root.tone) {
        case "rule":
            return PaperTheme.rule;
        case "rule2":
            return PaperTheme.rule2;
        case "ink":
            return PaperTheme.ink;
        case "ink4":
            return PaperTheme.ink4;
        case "accent":
            return PaperTheme.accent;
        case "alert":
            return PaperTheme.alert;
        case "link":
            return PaperTheme.link;
        case "seal":
            return PaperTheme.seal;
        }
        if (root.weight === "mark")
            return PaperTheme.accent;
        if (root.weight === "fine" || root.isOxford || root.isDouble)
            return PaperTheme.rule2;
        return PaperTheme.rule;
    }

    /// The colour of the rule itself (the thick half of an Oxford rule).
    readonly property color primaryColor: root.colorOverride !== null ? root.colorOverride : (root.isOxford ? PaperTheme.ink : root.toneColor)
    /// The colour of the thin half of a double / Oxford rule.
    readonly property color secondaryColor: root.secondaryColorOverride !== null ? root.secondaryColorOverride : (root.colorOverride !== null ? root.colorOverride : PaperTheme.rule2)

    implicitWidth: root.vertical ? root.thickness : (root.length >= 0 ? root.length : (parent?.width ?? 0))
    implicitHeight: root.vertical ? (root.length >= 0 ? root.length : (parent?.height ?? 0)) : root.thickness

    // The thick half of an Oxford rule, or the first line of a double rule.
    Rectangle {
        x: 0
        y: 0
        width: root.vertical ? (root.isOxford ? PaperTheme.oxfordThick : (root.isDouble ? PaperTheme.ruleWidth : root.thickness)) : root.width
        height: root.vertical ? root.height : (root.isOxford ? PaperTheme.oxfordThick : (root.isDouble ? PaperTheme.ruleWidth : root.thickness))
        color: root.primaryColor
        antialiasing: false
        visible: !root.dotted
    }

    // The thin half, after a 1 px gap.
    Rectangle {
        visible: (root.isOxford || root.isDouble) && !root.dotted
        x: root.vertical ? root.thickness - PaperTheme.ruleWidth : 0
        y: root.vertical ? 0 : root.thickness - PaperTheme.ruleWidth
        width: root.vertical ? PaperTheme.ruleWidth : root.width
        height: root.vertical ? root.height : PaperTheme.ruleWidth
        color: root.secondaryColor
        antialiasing: false
    }

    // Dotted variant: 1 px dashes with 1 px gaps, drawn as cells so it stays
    // crisp. Broadsheet uses this for disabled borders instead of an opacity.
    Row {
        visible: root.dotted && !root.vertical
        spacing: 2
        Repeater {
            model: root.dotted && !root.vertical ? Math.max(0, Math.floor(root.width / 3)) : 0
            delegate: Rectangle {
                width: 1
                height: PaperTheme.ruleWidth
                color: root.primaryColor
                antialiasing: false
            }
        }
    }
    Column {
        visible: root.dotted && root.vertical
        spacing: 2
        Repeater {
            model: root.dotted && root.vertical ? Math.max(0, Math.floor(root.height / 3)) : 0
            delegate: Rectangle {
                width: PaperTheme.ruleWidth
                height: 1
                color: root.primaryColor
                antialiasing: false
            }
        }
    }
}
