import qs.modules.paper.common
import qs.modules.paper.widgets

/**
 * The vertical hairline that separates two bar clusters.
 * 1 × 14 in hairline, 1 × 16 in ledger, 1 × 18 in broadsheet — the cluster gap
 * that goes either side of it is `PaperTheme.pick(20, 12, 13)`, which the bar
 * exposes as `PaperBar`'s `clusterGap`.
 */
PaperRule {
    vertical: true
    length: PaperTheme.pick(14, 16, 18)
}
