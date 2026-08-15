pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.modules.common

/**
 * Theme singleton for the "paper" panel family.
 *
 * ONE family, THREE variants. `Config.options.paper.variant` selects between:
 *
 *   "hairline"   — design/paper-a-hairline/SPEC.md
 *                  Fine print on paper. One 1 px rule is the only structural
 *                  device. No fills, no cards, no shadow, no radius. "On" is
 *                  ink weight, an underline, or a 6 px dot. One hue (seal red)
 *                  for critical states only.
 *   "ledger"     — design/paper-b-ledger/SPEC.md
 *                  A well-kept ledger. Hairline cards on a raised sheet, dotted
 *                  key···value leaders, a ruler meter. Two inks: ink blue means
 *                  interactive/on, stamp red means warning/destructive.
 *   "broadsheet" — design/paper-c-broadsheet/SPEC.md
 *                  A typeset broadsheet. Oxford and double rules, corner ticks,
 *                  Pagella oldstyle figures and real small caps, sepia stamps.
 *                  Three inks: oxblood (active/danger), ink blue (connected),
 *                  sepia (stamps/ornament).
 *
 * The variant is switchable AT RUNTIME — every token below is a binding, so a
 * variant change restyles the running shell with no reload. Surface code must
 * therefore never cache a token into a plain `var`; always read
 * `PaperTheme.<token>` in the binding itself.
 *
 * Dark mode follows the shell-wide toggle (`Appearance.m3colors.darkmode`),
 * exactly as PixTheme does, so the bar's sun/moon control keeps working. Light
 * ("Paper") is the primary palette in all three variants; dark ("Dusk Paper")
 * is a warm companion, never an inversion.
 *
 * See modules/paper/HANDOFF.md for the full token/widget catalog.
 */
Singleton {
    id: root

    // ---------------------------------------------------------------- variant

    readonly property list<string> variants: ["hairline", "ledger", "broadsheet"]

    /// Active variant. Falls back to "hairline" before Config is ready or when
    /// the persisted value is garbage.
    readonly property string variant: {
        const v = Config.options?.paper?.variant ?? "hairline";
        return root.variants.includes(v) ? v : "hairline";
    }

    readonly property bool isHairline: root.variant === "hairline"
    readonly property bool isLedger: root.variant === "ledger"
    readonly property bool isBroadsheet: root.variant === "broadsheet"

    /// Follows the global dark mode toggle.
    readonly property bool dark: Appearance.m3colors.darkmode

    /**
     * Per-variant value selector — the workhorse of this file and the one thing
     * surface code should reach for when a layout genuinely differs between
     * variants (sizes, paddings, counts). For *styling* differences, prefer the
     * widgets in modules/paper/widgets, which already branch internally.
     *
     *   implicitHeight: PaperTheme.pick(56, 42, 48)
     */
    function pick(hairline, ledger, broadsheet) {
        if (root.variant === "ledger")
            return ledger;
        if (root.variant === "broadsheet")
            return broadsheet;
        return hairline;
    }

    function setVariant(name: string): void {
        if (root.variants.includes(name))
            Config.options.paper.variant = name;
    }

    /// Cycle hairline → ledger → broadsheet → hairline. Bound to the
    /// "paperVariantCycle" GlobalShortcut and the "paperVariant" IPC target.
    function cycleVariant(): void {
        const i = root.variants.indexOf(root.variant);
        Config.options.paper.variant = root.variants[(i + 1) % root.variants.length];
    }

    // --------------------------------------------------------------- palettes
    //
    // Six palettes, one vocabulary. Every token exists in every palette so a
    // surface never has to ask "does this variant have an accent wash?" — in
    // hairline, which has no tinted fills, `accentWash` simply resolves to the
    // 4 % hover wash and `alertWash` to transparent.

    component Palette: QtObject {
        /// The sheet. Bar body, panel ground, popup ground.
        property color paper
        /// A raised sheet laid on `paper`. == paper where the variant has no
        /// raised level (hairline, broadsheet).
        property color paperRaise
        /// Recessed ground: log boxes, album-art well, scroll bodies.
        property color paperSunk
        /// Deepest step: press wash, table header bands.
        property color paperEdge
        /// Hover wash (one step).
        property color wash
        /// Press wash (two steps) and text selection band.
        property color wash2

        /// Primary text, active icons, active rules.
        property color ink
        /// Secondary text, resting icons, body copy.
        property color ink2
        /// Meta, statuses, section labels, placeholders.
        property color ink3
        /// Disabled, out-of-month days, dotted leaders, footnotes.
        property color ink4

        /// The hairline. Borders, separators, dividers.
        property color rule
        /// A hairline the user must be able to aim at: field underlines, switch
        /// rails, sheet edges, gauge baselines.
        property color rule2

        /// Active / selected / on. NOTE: in hairline this IS `ink` — that
        /// variant expresses "on" with weight, not hue.
        property color accent
        /// Accent at reduced weight (sublabels on an accent ground).
        property color accentSoft
        /// Tint behind an active control. == `wash` in hairline (no tints).
        property color accentWash
        /// Text/icons on a filled accent or filled ink ground.
        property color onAccent

        /// "Connected to something out there" — Wi-Fi, Bluetooth, a daemon.
        /// == accent in hairline and ledger; ink blue in broadsheet.
        property color link
        property color linkWash

        /// Failure, danger, destructive, critical.
        property color alert
        /// Alert at rest (a non-urgent warning, a destructive border).
        property color alertSoft
        /// Tint behind a failure. Transparent in hairline.
        property color alertWash

        /// Stamp / ornament ink (PaperStamp). Ink3 in hairline, which has no
        /// stamps — PaperStamp degrades to plain micro-caps text there.
        property color seal
        property color sealWash

        /// Keyboard-selection ground.
        property color selection

        /// Overview backdrop.
        property color scrim
        /// Session screen and worktrees backdrop (heavier).
        property color scrim2
    }

    // -- hairline ------------------------------------------------------------
    readonly property Palette pHairlineLight: Palette {
        paper: "#FAF8F3"
        paperRaise: "#FAF8F3"
        paperSunk: "#F4F1E9"
        paperEdge: "#E7E2D6"
        wash: "#EFEBE1"
        wash2: "#E7E2D6"
        ink: "#1C1A17"
        ink2: "#56514A"
        ink3: "#8A8379"
        ink4: "#B7B0A3"
        rule: "#DCD6C9"
        rule2: "#C3BCAC"
        accent: "#1C1A17"       // ink — hairline has no accent for "on"
        accentSoft: "#56514A"
        accentWash: "#EFEBE1"
        onAccent: "#FAF8F3"
        link: "#1C1A17"
        linkWash: "#EFEBE1"
        alert: "#8E3B2F"
        alertSoft: "#C89A90"
        alertWash: "transparent"
        seal: "#8A8379"
        sealWash: "transparent"
        selection: "#E7E2D6"
        scrim: "#9efaf8f3"      // paper @ 62 % — the desktop is bleached
        scrim2: "#ebfaf8f3"     // paper @ 92 %
    }
    readonly property Palette pHairlineDark: Palette {
        paper: "#1B1917"
        paperRaise: "#1B1917"
        paperSunk: "#232019"
        paperEdge: "#302C27"
        wash: "#262320"
        wash2: "#302C27"
        ink: "#EDE7DA"
        ink2: "#A9A192"
        ink3: "#756E63"
        ink4: "#4E483F"
        rule: "#35302A"
        rule2: "#4A443B"
        accent: "#EDE7DA"
        accentSoft: "#A9A192"
        accentWash: "#262320"
        onAccent: "#1B1917"
        link: "#EDE7DA"
        linkWash: "#262320"
        alert: "#CE8272"
        alertSoft: "#6E4137"
        alertWash: "transparent"
        seal: "#756E63"
        sealWash: "transparent"
        selection: "#302C27"
        scrim: "#a81b1917"
        scrim2: "#eb1b1917"
    }

    // -- ledger --------------------------------------------------------------
    readonly property Palette pLedgerLight: Palette {
        paper: "#F6F2E9"
        paperRaise: "#FBF8F1"
        paperSunk: "#EFEADD"
        paperEdge: "#E8E2D2"
        wash: "#EFEADD"
        wash2: "#E8E2D2"
        ink: "#22201C"
        ink2: "#5A5449"
        ink3: "#857D6E"
        ink4: "#A9A08D"
        rule: "#DDD6C6"
        rule2: "#C6BCA6"
        accent: "#2C557E"       // ink blue
        accentSoft: "#4E7BA6"
        accentWash: "#E7ECF3"
        onAccent: "#FBF8F1"
        link: "#2C557E"
        linkWash: "#E7ECF3"
        alert: "#A33726"        // stamp red
        alertSoft: "#C3604A"
        alertWash: "#F5E6E1"
        seal: "#A33726"
        sealWash: "#F5E6E1"
        selection: "#E7ECF3"
        scrim: "#e6f6f2e9"      // paper @ 90 % — tracing paper, not a dimmer
        scrim2: "#e6f6f2e9"
    }
    readonly property Palette pLedgerDark: Palette {
        paper: "#16140F"
        paperRaise: "#1D1A15"
        paperSunk: "#100F0B"    // sunk is DARKER than the card in dusk
        paperEdge: "#25211A"
        wash: "#100F0B"
        wash2: "#25211A"
        ink: "#EDE6D7"
        ink2: "#ADA593"
        ink3: "#867E6D"
        ink4: "#5E5749"
        rule: "#2F2B23"
        rule2: "#463F34"
        accent: "#8FB3D9"
        accentSoft: "#6E93BC"
        accentWash: "#1B2530"
        onAccent: "#15130F"
        link: "#8FB3D9"
        linkWash: "#1B2530"
        alert: "#D97B62"
        alertSoft: "#B85F47"
        alertWash: "#2C1B16"
        seal: "#D97B62"
        sealWash: "#2C1B16"
        selection: "#1B2530"
        scrim: "#e616140f"
        scrim2: "#e616140f"
    }

    // -- broadsheet ----------------------------------------------------------
    readonly property Palette pBroadsheetLight: Palette {
        paper: "#F6F2E9"
        paperRaise: "#F6F2E9"
        paperSunk: "#EFEADD"    // paper2 — inset cards, control rest fill
        paperEdge: "#DCD3BE"    // paper4 — press
        wash: "#E6DFCE"         // paper3 — hover
        wash2: "#DCD3BE"
        ink: "#241F1A"
        ink2: "#57503F"
        ink3: "#7E7565"
        ink4: "#B0A794"
        rule: "#CFC6B2"
        rule2: "#B3A991"
        accent: "#7B2A24"       // oxblood
        accentSoft: "#7B2A24"
        accentWash: "#F0E4DF"
        onAccent: "#F6F2E9"
        link: "#27456E"         // ink blue — "connected to something out there"
        linkWash: "#E2E6EE"
        alert: "#7B2A24"        // failure is oxblood; warning is sepia (seal)
        alertSoft: "#8A6A3B"
        alertWash: "#F0E4DF"
        seal: "#8A6A3B"         // sepia
        sealWash: "#EFE7D6"
        selection: "#DED6C2"
        scrim: "#8c1c1813"      // warm dark @ 55 %; the wallpaper survives
        scrim2: "#b81c1813"     // @ 72 %
    }
    readonly property Palette pBroadsheetDark: Palette {
        paper: "#17140F"
        paperRaise: "#17140F"
        paperSunk: "#1E1A14"
        paperEdge: "#302A21"
        wash: "#26211A"
        wash2: "#302A21"
        ink: "#EDE6D8"
        ink2: "#C3BAA8"
        ink3: "#938A79"
        ink4: "#6A6252"
        rule: "#39322A"
        rule2: "#564E42"
        accent: "#C9736A"
        accentSoft: "#C9736A"
        accentWash: "#2E211E"
        onAccent: "#17140F"
        link: "#93B0D4"
        linkWash: "#1B2029"
        alert: "#C9736A"
        alertSoft: "#C6A470"
        alertWash: "#2E211E"
        seal: "#C6A470"
        sealWash: "#26201A"
        selection: "#2C261E"
        scrim: "#8c080705"
        scrim2: "#c7080705"
    }

    /// The live palette. Prefer the flat accessors below; this is here for code
    /// that wants to pass a whole palette around.
    readonly property Palette palette: root.isLedger ? (root.dark ? root.pLedgerDark : root.pLedgerLight) : root.isBroadsheet ? (root.dark ? root.pBroadsheetDark : root.pBroadsheetLight) : (root.dark ? root.pHairlineDark : root.pHairlineLight)

    // Flat colour accessors — this is the surface-facing API.
    readonly property color paper: root.palette.paper
    readonly property color paperRaise: root.palette.paperRaise
    readonly property color paperSunk: root.palette.paperSunk
    readonly property color paperEdge: root.palette.paperEdge
    readonly property color wash: root.palette.wash
    readonly property color wash2: root.palette.wash2
    readonly property color ink: root.palette.ink
    readonly property color ink2: root.palette.ink2
    readonly property color ink3: root.palette.ink3
    readonly property color ink4: root.palette.ink4
    readonly property color rule: root.palette.rule
    readonly property color rule2: root.palette.rule2
    readonly property color accent: root.palette.accent
    readonly property color accentSoft: root.palette.accentSoft
    readonly property color accentWash: root.palette.accentWash
    readonly property color onAccent: root.palette.onAccent
    readonly property color link: root.palette.link
    readonly property color linkWash: root.palette.linkWash
    readonly property color alert: root.palette.alert
    readonly property color alertSoft: root.palette.alertSoft
    readonly property color alertWash: root.palette.alertWash
    readonly property color seal: root.palette.seal
    readonly property color sealWash: root.palette.sealWash
    readonly property color selection: root.palette.selection
    readonly property color scrim: root.palette.scrim
    readonly property color scrim2: root.palette.scrim2

    // ------------------------------------------------------------------ fonts
    //
    // Bundled under assets/fonts (see HANDOFF.md §Fonts):
    //   Inter      — hairline body face. Bundled (Light/Regular/Medium, v4.1)
    //                because Fedora does not ship google-inter-fonts here.
    //   XCharter   — ledger title face. Michael Sharpe's TTF/OTF extension of
    //                Bitstream Charter (same Carter design, real oldstyle
    //                figures and small caps). Bitstream Charter IS installed on
    //                this machine but only as Type 1 .pfb, which Qt renders
    //                badly at 15–16 px — hence the bundle. SUBSTITUTION NOTED:
    //                the spec says "Bitstream Charter"; we ship XCharter.
    // Installed system-wide and used as-is:
    //   Adwaita Sans, JetBrains Mono, Source Code Pro, TeX Gyre Pagella, Lato.

    FontLoader {
        id: interLight
        source: Qt.resolvedUrl(Quickshell.shellPath("assets/fonts/Inter-Light.ttf"))
    }
    FontLoader {
        id: interRegular
        source: Qt.resolvedUrl(Quickshell.shellPath("assets/fonts/Inter-Regular.ttf"))
    }
    FontLoader {
        id: interMedium
        source: Qt.resolvedUrl(Quickshell.shellPath("assets/fonts/Inter-Medium.ttf"))
    }
    FontLoader {
        id: charterRoman
        source: Qt.resolvedUrl(Quickshell.shellPath("assets/fonts/XCharter-Roman.otf"))
    }
    FontLoader {
        id: charterBold
        source: Qt.resolvedUrl(Quickshell.shellPath("assets/fonts/XCharter-Bold.otf"))
    }
    FontLoader {
        id: charterItalic
        source: Qt.resolvedUrl(Quickshell.shellPath("assets/fonts/XCharter-Italic.otf"))
    }

    // Inter is Adwaita Sans' ancestor, so the fallback is visually near-identical.
    readonly property string familyInter: interRegular.status === FontLoader.Ready ? interRegular.name : "Adwaita Sans"
    readonly property string familyCharter: charterRoman.status === FontLoader.Ready ? charterRoman.name : "Bitstream Charter"
    readonly property string familyAdwaita: "Adwaita Sans"
    readonly property string familyLato: "Lato"
    readonly property string familyPagella: "TeX Gyre Pagella"
    readonly property string familyJetBrains: "JetBrains Mono"
    readonly property string familySourceCode: "Source Code Pro"

    /// UI / body face. hairline: Inter · ledger: Adwaita Sans · broadsheet: Lato
    readonly property string fontSans: root.pick(root.familyInter, root.familyAdwaita, root.familyLato)
    /// Title / display face. hairline has NO display face — titles are the body
    /// face in micro-caps — so this resolves to the sans there.
    readonly property string fontSerif: root.pick(root.familyInter, root.familyCharter, root.familyPagella)
    /// Figures / identifiers / paths / log output.
    readonly property string fontMono: root.pick(root.familyJetBrains, root.familySourceCode, root.familySourceCode)

    // Role aliases — write these in surface code.
    readonly property string fontBody: root.fontSans
    readonly property string fontTitle: root.fontSerif
    /// The face numerals are set in. Broadsheet sets figures in Pagella with
    /// oldstyle+tabular features; the other two use the mono face.
    readonly property string fontFigure: root.pick(root.familyJetBrains, root.familySourceCode, root.familyPagella)
    /// Placeholders / "busy" / empty states. Broadsheet sets these in Pagella
    /// italic; the others use plain body type in ink4 (`italicPlaceholders`).
    readonly property string fontFootnote: root.pick(root.familyInter, root.familyAdwaita, root.familyPagella)

    /// true when the variant expresses hierarchy with Pagella small caps rather
    /// than letterspaced uppercase. Broadsheet only.
    readonly property bool titleIsSmallCaps: root.isBroadsheet
    /// true when placeholders / hints / empty states are set in italic. C only.
    readonly property bool italicPlaceholders: root.isBroadsheet

    readonly property QtObject font: QtObject {
        /// Sizes, unified across the three type scales. Off-scale sizes stay
        /// off-scale — write the literal and comment it, as the SPECs do.
        readonly property QtObject size: QtObject {
            /// Section labels, kickers, verbs, accelerators, chips. UPPERCASE.
            readonly property int micro: 10
            /// Times, statuses, hints, captions, agate.
            readonly property int meta: 11
            /// Secondary lines, notification bodies, control labels.
            readonly property int small: 12
            /// Default body, list-row titles, calendar days.
            readonly property int body: 13
            /// Row titles, notification summaries, media title.
            readonly property int lead: root.pick(15, 14, 15)
            /// Panel titles, popup headings, bar clock.
            readonly property int title: root.pick(18, 16, 17)
            /// Overlay headings, search query, big single values.
            readonly property int headline: root.pick(20, 20, 21)
            /// The SESSION masthead.
            readonly property int display: root.pick(24, 30, 26)
            /// The pomodoro digits — the only display figure in the shell.
            readonly property int folio: root.pick(40, 40, 46)
        }
        readonly property QtObject weight: QtObject {
            /// Large type only (the optical weight rule: size up, weight down).
            readonly property int light: root.pick(Font.Light, Font.Light, Font.Normal)
            readonly property int normal: Font.Normal
            /// Micro-caps, row titles.
            readonly property int medium: root.pick(Font.Medium, Font.Medium, Font.DemiBold)
            /// The heaviest weight the variant permits. hairline has NO bold.
            readonly property int bold: root.pick(Font.Medium, Font.DemiBold, Font.Bold)
            /// Title face weight for headings.
            readonly property int title: root.pick(Font.Medium, Font.Bold, Font.Normal)
        }
        /// Tracking is specified in em by the SPECs; QML letterSpacing is in px.
        /// Use `PaperTheme.tracking(em, pixelSize)`, or these presets.
        readonly property QtObject trackingEm: QtObject {
            readonly property real micro: root.pick(0.16, 0.13, 0.15)
            readonly property real display: root.pick(0.18, 0.0, 0.18)
        }
        /// Ready-made letterSpacing for a 10 px micro-caps label.
        readonly property real microLetterSpacing: root.font.trackingEm.micro * root.font.size.micro
        /// OpenType feature sets. Qt 6.7+ `font.features`.
        readonly property QtObject features: QtObject {
            /// Every numeral run. Without tnum the bar clock jitters.
            readonly property var figures: root.isBroadsheet ? ({
                    "onum": 1,
                    "tnum": 1
                }) : ({
                    "tnum": 1
                })
            /// Big aligned figures (the pomodoro) — lining, tabular.
            readonly property var lining: root.isBroadsheet ? ({
                    "lnum": 1,
                    "tnum": 1
                }) : ({
                    "tnum": 1
                })
            /// Real small caps. Broadsheet only; empty elsewhere (those
            /// variants use uppercase + tracking instead).
            readonly property var smallCaps: root.isBroadsheet ? ({
                    "smcp": 1,
                    "c2sc": 1
                }) : ({})
            readonly property var none: ({})
        }
    }

    /// em → px for a given optical size.
    function tracking(em: real, pixelSize: real): real {
        return em * pixelSize;
    }

    // ------------------------------------------------------------ rules, radii

    /// The hairline. One value; the pixel family's 2/3 px triple is gone.
    readonly property int ruleWidth: 1
    /// The selection mark: an underline or a left gutter rule.
    /// hairline draws it 1 px in ink; ledger and broadsheet 2 px in accent.
    readonly property int markWidth: root.pick(1, 2, 2)
    /// The change bar / selected-row left gutter.
    readonly property int changeBarWidth: root.pick(1, 2, 2)
    /// How far a selected row is indented by its gutter.
    readonly property int changeBarIndent: root.pick(11, 8, 9)
    /// Oxford rule: `oxfordThick` ink + 1 px gap + 1 px rule2. Broadsheet only.
    readonly property int oxfordThick: 2
    readonly property int ruleGap: 1

    readonly property int radiusControl: root.pick(0, 2, 2)
    readonly property int radiusSheet: root.pick(0, 3, 0)
    readonly property int radiusCard: root.pick(0, 2, 0)
    /// Medallions (battery, OSD glyph, profile markers). Broadsheet only.
    readonly property int radiusPill: root.pick(0, 0, 999)

    // ------------------------------------------------------------- ornament
    //
    // Structural switches. Branch on these rather than on `variant` when what
    // you need is "does this variant do X".

    readonly property QtObject ornament: QtObject {
        /// A fractal-noise tile multiplied over every paper ground.
        readonly property bool grain: !root.isHairline
        readonly property real grainOpacity: root.isLedger ? (root.dark ? 0.055 : 0.03) : root.isBroadsheet ? 0.055 : 0.0
        /// Floating surfaces get a whisper of shadow. Docked ones never do.
        readonly property bool shadow: !root.isHairline
        /// 6 × 6 px corner L-ticks on a floating or focused sheet.
        readonly property bool cornerTicks: root.isBroadsheet
        /// 1 px + gap + 1 px, closing a block that owns a whole section.
        readonly property bool doubleRules: root.isBroadsheet
        /// 2 px ink + gap + 1 px rule2, under every masthead and the bar.
        readonly property bool oxfordRules: root.isBroadsheet
        /// PaperStamp draws a real rubber stamp (rotated, framed, washed).
        readonly property bool stamps: !root.isHairline
        readonly property real stampRotation: root.isLedger ? -1.1 : -3.5
        /// PaperKV draws a dotted leader between key and value.
        readonly property bool dottedLeaders: root.isLedger
        /// PaperMeter draws tick marks along the track.
        readonly property bool meterTicks: !root.isHairline
        /// PaperMeter draws a head dot at the value (hairline's readability trick).
        readonly property bool meterHead: root.isHairline
        /// Disabled controls take a dotted rule instead of an opacity drop.
        readonly property bool dottedDisabled: root.isBroadsheet
        /// Controls draw a visible frame at rest. False in hairline: a button
        /// there IS its label.
        readonly property bool framedControls: !root.isHairline
        /// A tinted fill may be used to say "on".
        readonly property bool tintedFills: !root.isHairline
    }

    readonly property QtObject shadow: QtObject {
        readonly property color color: root.dark ? "#66000000" : (root.isLedger ? "#1a22201c" : "#17241f1a")
        readonly property real radius: root.isBroadsheet ? 26 : 14
        readonly property real verticalOffset: root.isBroadsheet ? 10 : 5
    }

    // ------------------------------------------------------------ spacing

    readonly property QtObject spacing: QtObject {
        readonly property int hair: 2
        readonly property int tiny: 4
        readonly property int xs: 6
        readonly property int small: 8
        readonly property int sm: 10
        readonly property int medium: 12
        readonly property int large: 16
        readonly property int xl: 20
        readonly property int xxl: 24
        readonly property int huge: 32
    }

    /// Padding presets, per variant. Hairline substitutes whitespace for the
    /// borders it removed, so it pads roughly twice as much as the others.
    readonly property QtObject pad: QtObject {
        /// Popups, toasts, OSD, floating sheets.
        readonly property int sheet: root.pick(20, 12, 14)
        /// Docked sidebars (quick settings, displays).
        readonly property int panel: root.pick(24, 12, 14)
        /// Inline cards. 0 in hairline — there are no cards.
        readonly property int card: root.pick(0, 9, 10)
        /// Bar content inset, left and right.
        readonly property int bar: root.pick(20, 14, 12)
        /// Modal dialogs (worktrees).
        readonly property int dialog: root.pick(24, 14, 14)
    }

    readonly property QtObject gap: QtObject {
        /// Between two sections separated by a rule.
        readonly property int section: root.pick(24, 10, 12)
        /// Between rows in a list.
        readonly property int row: root.pick(8, 8, 8)
        /// Icon to its label.
        readonly property int icon: root.pick(4, 6, 8)
        /// Label to its value.
        readonly property int value: root.pick(8, 6, 6)
        /// Between chips / buttons in a row.
        readonly property int chip: root.pick(24, 6, 6)
        /// Between stacked cards / tiles.
        readonly property int tile: root.pick(8, 6, 6)
    }

    // ------------------------------------------------------------- sizes

    /// Bar height AND exclusive zone.
    readonly property int barHeight: root.pick(38, 34, 42)
    /// How far a bar hover popup or the media card hangs below the bar.
    readonly property int barPopupOffset: root.barHeight + root.pick(8, 6, 6)

    readonly property QtObject size: QtObject {
        readonly property int quickSettings: root.pick(380, 340, 360)
        readonly property int monitors: root.pick(400, 360, 380)
        readonly property int notificationWindow: root.pick(400, 368, 380)
        readonly property int toast: root.pick(372, 344, 356)
        readonly property int toastGap: root.pick(12, 10, 10)
        readonly property int toastTop: root.barHeight + root.pick(12, 12, 16)
        readonly property int mediaWidth: root.pick(480, 440, 460)
        readonly property int mediaCollapsed: root.pick(168, 164, 172)
        readonly property int mediaExpanded: root.pick(392, 370, 388)
        readonly property int albumArt: root.pick(128, 132, 132)
        readonly property int searchWidth: root.pick(600, 560, 560)
        readonly property int searchResultsMax: root.pick(520, 480, 520)
        readonly property int worktrees: root.pick(480, 460, 440)
        readonly property int worktreesMax: root.pick(900, 880, 900)
        readonly property int osdWidth: root.pick(300, 268, 300)
        readonly property int osdHeight: root.pick(62, 60, 62)
        readonly property int osdTop: root.barHeight + root.pick(14, 14, 14)
        /// Session: hairline uses 120 px columns divided by full-height rules;
        /// the others use square tiles.
        readonly property int sessionTile: root.pick(120, 116, 128)
        readonly property int sessionGap: root.pick(0, 16, 18)
        readonly property int workspaceCellWidth: root.pick(26, 22, 26)
        readonly property int workspaceCellHeight: root.pick(26, 24, 24)
        readonly property int workspaceGap: root.pick(10, 4, 5)
        /// Standard control heights.
        readonly property int button: root.pick(24, 26, 30)
        readonly property int iconButton: root.pick(24, 26, 26)
        readonly property int field: root.pick(26, 28, 30)
        readonly property int listRow: root.pick(44, 38, 40)
        readonly property int toggleRow: root.pick(56, 42, 48)
        readonly property int chip: root.pick(20, 20, 24)
        /// The 6 px state dot / marker.
        readonly property int dot: 6
    }

    // -------------------------------------------------------------- icons

    readonly property QtObject icon: QtObject {
        /// Apparent stroke width in PIXELS — constant at every optical size.
        /// PaperIcon compensates for its own scale, so this is what you see.
        readonly property real stroke: 1.25
        /// Broadsheet thickens the pen slightly above `strokeLargeAbove` px.
        readonly property real strokeLarge: root.isBroadsheet ? 1.4 : 1.25
        readonly property real strokeLargeAbove: 26
        /// All three variants specify round caps and joins.
        readonly property bool roundCaps: true

        readonly property int tiny: 12
        readonly property int row: 14
        readonly property int control: root.pick(16, 15, 16)
        readonly property int large: 20
        readonly property int session: root.pick(28, 28, 38)
        readonly property int tray: root.pick(15, 15, 19)
    }

    /// App icons: everything is desaturated; hairline additionally multiplies
    /// the result toward ink2, broadsheet duotones ink2 → paper.
    readonly property QtObject appIcon: QtObject {
        readonly property real desaturation: root.pick(1.0, 0.55, 1.0)
        readonly property real contrast: root.pick(0.0, -0.05, 0.0)
        /// Multiply the desaturated icon toward this ink. "transparent"
        /// disables the step.
        readonly property color tint: root.isLedger ? "transparent" : root.ink2
        readonly property real tintStrength: root.pick(1.0, 0.0, 0.72)
        /// Third-party icons sit in a hairline plate.
        readonly property bool plate: !root.isHairline
    }

    // ------------------------------------------------------------- motion

    readonly property QtObject motion: QtObject {
        /// Tint washes: hover, press, icon colour.
        readonly property int fast: 90
        /// Selection marks, underline draw, switch travel, workspace indicator.
        readonly property int base: root.pick(140, 140, 160)
        /// Section reveal, overlay cover, notification enter/exit.
        readonly property int slow: root.pick(240, 260, 280)
        /// The media card growing lyrics.
        readonly property int card: root.pick(280, 300, 280)
        /// Lyrics auto-scroll (suspended 4 s after a manual scroll).
        readonly property int scroll: root.pick(400, 420, 420)
        readonly property int scrollSuspend: 4000
        /// Hard ceiling on any slide. Nothing travels further than this.
        readonly property int maxTravel: 4

        /// Everything entering or changing state.
        readonly property int type: Easing.BezierSpline
        readonly property list<real> bezierCurve: root.isHairline ? [0.2, 0, 0, 1, 1, 1] : [0.2, 0.7, 0.3, 1, 1, 1]
        /// Everything leaving. Only hairline distinguishes an exit curve.
        readonly property list<real> exitBezierCurve: root.isHairline ? [0.4, 0, 1, 1, 1, 1] : [0.2, 0.7, 0.3, 1, 1, 1]
    }

    // Tooltip timings are identical in all three variants (and to PixTooltip).
    readonly property QtObject tooltip: QtObject {
        readonly property int showDelay: 350
        readonly property int hideDebounce: 120
        readonly property int gap: root.pick(10, 14, 14)
    }
}
