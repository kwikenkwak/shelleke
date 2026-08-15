import QtQuick
import qs.modules.paper.common

/**
 * A title. Replaces PixTitle.
 *
 * The three variants disagree about what a title IS, and this widget hides the
 * disagreement:
 *   hairline   — there is no display face. A title is body type in micro-caps
 *                (10 px / medium / +0.16 em / UPPERCASE), which is why `role`
 *                defaults to "micro" there.
 *   ledger     — Charter (XCharter) at 16 px, mixed case.
 *   broadsheet — Pagella at 17 px with REAL small caps (`smcp`/`c2sc`).
 *
 * So write `PaperTitle { text: "Displays" }` and let it land correctly. Use
 * `role` to reach up the scale ("headline", "display") for mastheads.
 */
Text {
    id: root

    /// One of: micro lead title headline display. Defaults to the variant's
    /// natural panel-title size.
    property string role: PaperTheme.isHairline ? "micro" : "title"
    property string tone: "ink"
    /// Force the letterspaced-uppercase treatment even in broadsheet.
    property bool caps: PaperTheme.isHairline

    readonly property int roleSize: {
        const s = PaperTheme.font.size;
        switch (root.role) {
        case "micro":
            return s.micro;
        case "lead":
            return s.lead;
        case "headline":
            return s.headline;
        case "display":
            return s.display;
        default:
            return s.title;
        }
    }

    readonly property color toneColor: {
        switch (root.tone) {
        case "ink2":
            return PaperTheme.ink2;
        case "ink3":
            return PaperTheme.ink3;
        case "ink4":
            return PaperTheme.ink4;
        case "accent":
            return PaperTheme.accent;
        case "alert":
            return PaperTheme.alert;
        case "onAccent":
            return PaperTheme.onAccent;
        default:
            return PaperTheme.ink;
        }
    }

    color: root.toneColor
    renderType: Text.NativeRendering
    verticalAlignment: Text.AlignVCenter
    textFormat: Text.PlainText
    font {
        family: root.caps ? PaperTheme.fontBody : PaperTheme.fontTitle
        pixelSize: root.roleSize
        weight: root.caps ? PaperTheme.font.weight.medium : PaperTheme.font.weight.title
        capitalization: root.caps ? Font.AllUppercase : Font.MixedCase
        letterSpacing: root.caps ? PaperTheme.tracking(root.role === "display" ? PaperTheme.font.trackingEm.display : PaperTheme.font.trackingEm.micro, root.font.pixelSize) : 0
        // Real small caps where the face has them; ignored elsewhere.
        features: (!root.caps && PaperTheme.titleIsSmallCaps) ? PaperTheme.font.features.smallCaps : PaperTheme.font.features.none
        hintingPreference: Font.PreferFullHinting
    }
}
