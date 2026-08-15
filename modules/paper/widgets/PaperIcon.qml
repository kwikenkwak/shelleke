import QtQuick
import QtQuick.Shapes
import qs.modules.paper.common
import "../common/paper_icons_data.js" as PaperIcons

/**
 * A thin-stroke line icon from the active variant's set, drawn with Qt Quick
 * Shapes. Replaces PixIcon's 7 × 7 bitmaps.
 *
 * The characteristic rule of the whole family: the APPARENT stroke is constant
 * at every optical size (1.25 px; 1.4 px above 26 px in broadsheet). A 38 px
 * session glyph is drawn with the same pen as a 12 px row glyph, so large icons
 * read as engravings rather than as heavy pictograms. `PaperIcon` divides the
 * theme's stroke token by its own scale factor to achieve that, which is why
 * you must set `size` and never `scale` or `width`/`height`.
 *
 * Usage:
 *   PaperIcon { name: "wifi" }                                   // 16 px, ink2
 *   PaperIcon { name: "power"; size: PaperTheme.icon.session
 *               color: PaperTheme.accent }
 *
 * `name` accepts any spelling the SPECs use — kebab-case hairline names
 * ("chev-d", "speaker-x"), ledger/broadsheet camelCase ("chevD", "speakeroff"),
 * and the aliases "bt", "monitor", "expand", "fullscr". Unknown names draw
 * nothing (they do NOT fall back to another glyph — a missing icon should be
 * visible as a hole in review, not silently wrong).
 *
 * The three variants each keep their own drawings; a glyph one variant does not
 * draw falls back to another variant's drawing rather than disappearing.
 * See paper_icons_data.js for the inventory.
 */
Item {
    id: root

    /// Glyph name. See PaperIcons.names for the full list.
    property string name: ""
    /// Rendered edge length in px. Both dimensions; glyphs are square.
    property real size: PaperTheme.icon.control
    property color color: PaperTheme.ink2
    /// Override the variant this glyph is drawn from. Empty = follow the theme.
    property string variantOverride: ""
    /// Apparent stroke width in px. Defaults to the theme token, thickened for
    /// large broadsheet glyphs.
    property real strokeWidth: root.size > PaperTheme.icon.strokeLargeAbove ? PaperTheme.icon.strokeLarge : PaperTheme.icon.stroke

    readonly property string activeVariant: root.variantOverride !== "" ? root.variantOverride : PaperTheme.variant
    readonly property var glyph: PaperIcons.paths(root.activeVariant, root.name)
    /// The unit grid this variant draws on (16 for hairline/ledger, 20 for
    /// broadsheet). Exposed so callers can align to the same grid if they must.
    readonly property real viewBox: root.glyph.vb
    readonly property real unit: root.size / root.viewBox

    implicitWidth: root.size
    implicitHeight: root.size

    Shape {
        id: shape
        width: root.viewBox
        height: root.viewBox
        preferredRendererType: Shape.CurveRenderer
        // Scale the 16- or 20-unit drawing up to `size`. The stroke width below
        // is divided by the same factor, so what lands on screen is exactly
        // `strokeWidth` px regardless of the glyph's grid.
        transform: Scale {
            xScale: root.unit
            yScale: root.unit
        }

        // Stroked parts — the body of every glyph.
        ShapePath {
            strokeColor: root.color
            strokeWidth: root.strokeWidth / root.unit
            fillColor: "transparent"
            capStyle: PaperTheme.icon.roundCaps ? ShapePath.RoundCap : ShapePath.FlatCap
            joinStyle: ShapePath.RoundJoin
            PathSvg {
                path: root.glyph.stroke
            }
        }

        // Solid parts — the Wi-Fi dot, ledger's transport triangles, list
        // bullets. Deliberately a separate path: they take no stroke at all.
        ShapePath {
            strokeColor: "transparent"
            strokeWidth: 0
            fillColor: root.color
            fillRule: ShapePath.WindingFill
            PathSvg {
                path: root.glyph.fill
            }
        }
    }
}
