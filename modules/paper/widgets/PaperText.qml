import QtQuick
import qs.modules.paper.common

/**
 * Body text for the paper family. Replaces PixText.
 *
 * Instead of raw sizes, ask for a ROLE from the type scale and a TONE from the
 * ink ramp; both resolve per variant, so the same markup sets Inter 13 in
 * hairline, Adwaita Sans 13 in ledger and Lato 13 in broadsheet.
 *
 *   PaperText { text: "Internet" }                          // body / ink
 *   PaperText { role: "micro"; text: "Connectivity" }        // section label
 *   PaperText { role: "meta"; tone: "ink3"; text: "2 m" }
 *   PaperText { mono: true; role: "small"; text: "3840×2160@60" }
 *   PaperText { figure: true; role: "lead"; text: "78 %" }
 *
 * `micro` is the theme's only heading device outside broadsheet: 10 px, tracked,
 * uppercased automatically. `figure` sets the text in the variant's numeral face
 * with tabular (and, in broadsheet, oldstyle) figures — use it for EVERY number
 * the eye has to compare, or the bar clock will jitter.
 *
 * Anything not covered by role/tone can still be set directly (font.pixelSize,
 * color, …) because this is a plain Text.
 */
Text {
    id: root

    /// One of: micro meta small body lead title headline display folio
    property string role: "body"
    /// One of: ink ink2 ink3 ink4 accent accentSoft link alert seal onAccent
    property string tone: ""
    /// Set in the mono face (paths, identifiers, log output).
    property bool mono: false
    /// Set in the numeral face with tabular/oldstyle figures.
    property bool figure: false
    /// Placeholders, hints, empty states and "busy" — italic in broadsheet.
    property bool footnote: false
    /// Strike the text through with a 1 px rule (a completed to-do).
    property bool struck: false

    readonly property bool isMicro: root.role === "micro"

    readonly property int roleSize: {
        const s = PaperTheme.font.size;
        switch (root.role) {
        case "micro":
            return s.micro;
        case "meta":
            return s.meta;
        case "small":
            return s.small;
        case "lead":
            return s.lead;
        case "title":
            return s.title;
        case "headline":
            return s.headline;
        case "display":
            return s.display;
        case "folio":
            return s.folio;
        default:
            return s.body;
        }
    }

    readonly property color toneColor: {
        switch (root.tone) {
        case "ink":
            return PaperTheme.ink;
        case "ink2":
            return PaperTheme.ink2;
        case "ink3":
            return PaperTheme.ink3;
        case "ink4":
            return PaperTheme.ink4;
        case "accent":
            return PaperTheme.accent;
        case "accentSoft":
            return PaperTheme.accentSoft;
        case "link":
            return PaperTheme.link;
        case "alert":
            return PaperTheme.alert;
        case "seal":
            return PaperTheme.seal;
        case "onAccent":
            return PaperTheme.onAccent;
        }
        // Default tone per role: labels and meta sit back, body comes forward.
        if (root.isMicro || root.role === "meta")
            return PaperTheme.ink3;
        if (root.role === "small")
            return PaperTheme.ink2;
        return PaperTheme.ink;
    }

    // The optical weight rule: as size goes up, weight comes down.
    readonly property int roleWeight: {
        const w = PaperTheme.font.weight;
        if (root.roleSize <= 11)
            return w.medium;
        if (root.roleSize >= 24)
            return w.light;
        return w.normal;
    }

    color: root.toneColor
    renderType: Text.NativeRendering
    verticalAlignment: Text.AlignVCenter
    textFormat: Text.PlainText
    font {
        family: root.mono ? PaperTheme.fontMono : root.figure ? PaperTheme.fontFigure : root.footnote ? PaperTheme.fontFootnote : PaperTheme.fontBody
        pixelSize: root.roleSize
        weight: root.roleWeight
        italic: root.footnote && PaperTheme.italicPlaceholders
        capitalization: root.isMicro ? Font.AllUppercase : Font.MixedCase
        letterSpacing: root.isMicro ? PaperTheme.tracking(PaperTheme.font.trackingEm.micro, root.font.pixelSize) : (root.role === "display" ? PaperTheme.tracking(PaperTheme.font.trackingEm.display, root.font.pixelSize) : 0)
        strikeout: root.struck
        features: root.figure ? (root.role === "folio" ? PaperTheme.font.features.lining : PaperTheme.font.features.figures) : root.mono ? PaperTheme.font.features.figures : PaperTheme.font.features.none
        hintingPreference: Font.PreferFullHinting
    }

    Behavior on color {
        ColorAnimation {
            duration: PaperTheme.motion.fast
            easing.type: PaperTheme.motion.type
            easing.bezierCurve: PaperTheme.motion.bezierCurve
        }
    }
}
