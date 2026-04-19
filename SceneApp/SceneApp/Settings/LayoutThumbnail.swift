import SwiftUI
import SceneCore

/// Pure SwiftUI renderer that draws a `CustomLayout`'s slot proportions as
/// accent-colored rounded rects. Source of truth is `LayoutTemplate.slots(proportions:)`,
/// so the thumbnail always matches the live layout preview in `LayoutEditorView`.
///
/// Used at 3 sizes:
///   - 24×16 : menu bar dropdown
///   - 32×22 : Settings → Layouts tab list row
///   - 40×26 : Workspace editor's `LayoutPickerView`
struct LayoutThumbnail: View {
    let layout: CustomLayout
    var size: CGSize = CGSize(width: 24, height: 16)

    var body: some View {
        Canvas { ctx, canvasSize in
            let template = layout.template
            let slots = template.slots(proportions: layout.slotProportions)
            for slot in slots {
                let rect = CGRect(
                    x: slot.rect.minX * canvasSize.width,
                    y: slot.rect.minY * canvasSize.height,
                    width: slot.rect.width * canvasSize.width,
                    height: slot.rect.height * canvasSize.height
                ).insetBy(dx: 0.5, dy: 0.5)
                let path = Path(roundedRect: rect, cornerRadius: 1.5)
                ctx.fill(path, with: .color(Color.accentColor.opacity(0.7)))
            }
        }
        .frame(width: size.width, height: size.height)
        .accessibilityHidden(true)
    }
}
