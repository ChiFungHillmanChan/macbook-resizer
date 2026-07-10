import CoreGraphics

/// Pure math for the V0.6 "seam drag" feature: given a window's new frame
/// after the user resized one of its edges, infer which inner seam of the
/// surrounding tiled layout moved and return updated `proportions` for the
/// template. The caller then re-renders the other slot(s) by calling
/// `template.slots(proportions:)` and pushing the neighbor frame(s) to AX.
///
/// Intentionally does NOT return a new `Layout`; callers already have a
/// `LayoutTemplate` on hand and it's the proportions that vary session-to-
/// session. Clamping matches `LayoutEditorView`'s slider range `[0.1, 0.9]`
/// and respects `LayoutTemplate.proportionMinGap` for 3-way splits so the
/// middle slot never collapses.
///
/// Coordinate convention: `newWindowFrame` and `visibleFrame` are in NS
/// coordinates (bottom-left origin, y-up). Proportions, however, live in the
/// unit slot space, which is authored **top-left origin** (y-down) — see
/// `Slot.absoluteRect(in:)`, which performs the flip when materializing.
/// This function is the inverse map, so `yFrac` measures from the TOP of the
/// visibleFrame: for row templates, slot 0 is the topmost band on screen and
/// its seam is the window's NS bottom edge (`minY`). The x-axis needs no
/// flip — both spaces agree on left-to-right.
///
/// V0.6 scope:
/// - Supported: `.twoCol`, `.twoRow`, `.threeCol`, `.threeRow` (single
///   unambiguous seam per non-middle slot; two seams for the middle slot of
///   a three-way split, disambiguated by which edge moved more).
/// - Unsupported (returns `nil`): `.single`, `.grid2x2`, `.grid3x2`, and all
///   L-shape templates. These have ambiguous or multi-axis seams; deferred
///   to a later release.
public enum LayoutReflow {
    /// Returns updated proportions reflecting the dragged edge's new position,
    /// or `nil` when the template isn't supported, `slotIdx` is out of range,
    /// `proportions.count` doesn't match the template, or `visibleFrame` is
    /// degenerate. Callers should treat `nil` as "skip the reflow, leave the
    /// layout as-is this tick".
    public static func reflow(
        template: LayoutTemplate,
        proportions: [Double],
        slotIdx: Int,
        newWindowFrame: CGRect,
        visibleFrame: CGRect
    ) -> [Double]? {
        guard visibleFrame.width > 0, visibleFrame.height > 0 else { return nil }
        guard proportions.count == template.expectedProportionsCount else { return nil }

        guard let inferred = inferSeam(
            template: template,
            proportions: proportions,
            slotIdx: slotIdx,
            newWindowFrame: newWindowFrame,
            visibleFrame: visibleFrame
        ) else { return nil }

        var next = proportions
        next[inferred.proportionIdx] = clamp(
            value: inferred.newValue,
            proportionIdx: inferred.proportionIdx,
            existing: proportions,
            template: template
        )
        return next
    }

    // MARK: - Private

    private struct InferredSeam {
        let proportionIdx: Int
        let newValue: Double
    }

    private static func inferSeam(
        template: LayoutTemplate,
        proportions: [Double],
        slotIdx: Int,
        newWindowFrame: CGRect,
        visibleFrame: CGRect
    ) -> InferredSeam? {
        let xFrac: (CGFloat) -> Double = { abs in
            Double((abs - visibleFrame.minX) / visibleFrame.width)
        }
        // Unit y is measured from the TOP of the visibleFrame (top-left-origin
        // authoring space), while `abs` is an NS (bottom-left-origin) y value.
        let yFrac: (CGFloat) -> Double = { abs in
            Double((visibleFrame.maxY - abs) / visibleFrame.height)
        }

        switch template {
        case .twoCol:
            switch slotIdx {
            case 0: return InferredSeam(proportionIdx: 0, newValue: xFrac(newWindowFrame.maxX))
            case 1: return InferredSeam(proportionIdx: 0, newValue: xFrac(newWindowFrame.minX))
            default: return nil
            }

        case .twoRow:
            // Slot 0 = TOP band on screen: its seam is its NS bottom edge (minY).
            // Slot 1 = BOTTOM band: its seam is its NS top edge (maxY).
            switch slotIdx {
            case 0: return InferredSeam(proportionIdx: 0, newValue: yFrac(newWindowFrame.minY))
            case 1: return InferredSeam(proportionIdx: 0, newValue: yFrac(newWindowFrame.maxY))
            default: return nil
            }

        case .threeCol:
            switch slotIdx {
            case 0:
                return InferredSeam(proportionIdx: 0, newValue: xFrac(newWindowFrame.maxX))
            case 1:
                // Middle slot — two seams. Pick whichever edge moved more
                // from its original position. Ties go to the left seam (idx 0)
                // so the behavior is deterministic for tests.
                let origLeftAbs  = visibleFrame.minX + CGFloat(proportions[0]) * visibleFrame.width
                let origRightAbs = visibleFrame.minX + CGFloat(proportions[1]) * visibleFrame.width
                let leftDelta  = abs(newWindowFrame.minX - origLeftAbs)
                let rightDelta = abs(newWindowFrame.maxX - origRightAbs)
                if leftDelta >= rightDelta {
                    return InferredSeam(proportionIdx: 0, newValue: xFrac(newWindowFrame.minX))
                } else {
                    return InferredSeam(proportionIdx: 1, newValue: xFrac(newWindowFrame.maxX))
                }
            case 2:
                return InferredSeam(proportionIdx: 1, newValue: xFrac(newWindowFrame.minX))
            default:
                return nil
            }

        case .threeRow:
            // Slot 0 = TOP band, slot 2 = BOTTOM band. p[0] is the upper seam
            // (between slots 0/1), p[1] the lower seam (between slots 1/2) —
            // both measured from the top. In NS space the upper seam is the
            // middle window's maxY and the lower seam its minY.
            switch slotIdx {
            case 0:
                return InferredSeam(proportionIdx: 0, newValue: yFrac(newWindowFrame.minY))
            case 1:
                let origUpperAbs = visibleFrame.maxY - CGFloat(proportions[0]) * visibleFrame.height
                let origLowerAbs = visibleFrame.maxY - CGFloat(proportions[1]) * visibleFrame.height
                let upperDelta = abs(newWindowFrame.maxY - origUpperAbs)
                let lowerDelta = abs(newWindowFrame.minY - origLowerAbs)
                if upperDelta >= lowerDelta {
                    return InferredSeam(proportionIdx: 0, newValue: yFrac(newWindowFrame.maxY))
                } else {
                    return InferredSeam(proportionIdx: 1, newValue: yFrac(newWindowFrame.minY))
                }
            case 2:
                return InferredSeam(proportionIdx: 1, newValue: yFrac(newWindowFrame.maxY))
            default:
                return nil
            }

        case .single, .grid2x2, .grid3x2,
             .lShapeLeft, .lShapeRight, .lShapeTop, .lShapeBottom:
            return nil
        }
    }

    /// Clamp to the editor's `[0.1, 0.9]` range. For 3-way splits, also enforce
    /// `proportionMinGap` so the middle slot retains a non-trivial width/height
    /// and so we never invert the two handles (`p[0] < p[1]`).
    private static func clamp(
        value: Double,
        proportionIdx: Int,
        existing: [Double],
        template: LayoutTemplate
    ) -> Double {
        let basic = min(max(value, 0.1), 0.9)
        switch template {
        case .threeCol, .threeRow:
            let gap = LayoutTemplate.proportionMinGap
            if proportionIdx == 0 {
                return min(basic, existing[1] - gap)
            } else if proportionIdx == 1 {
                return max(basic, existing[0] + gap)
            }
            return basic
        default:
            return basic
        }
    }
}
