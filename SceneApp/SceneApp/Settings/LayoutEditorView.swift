import SwiftUI
import SceneCore

struct LayoutEditorView: View {
    @Binding var draft: CustomLayout
    let onSave: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            TextField("layouts.editor.name", text: $draft.name)
                .textFieldStyle(.roundedBorder)

            Picker("layouts.editor.template", selection: $draft.template) {
                ForEach(LayoutTemplate.allCases, id: \.self) { tpl in
                    Text(displayName(tpl)).tag(tpl)
                }
            }
            .onChange(of: draft.template) { _, newTpl in
                draft.slotProportions = newTpl.defaultProportions
            }

            ForEach(0..<draft.template.expectedProportionsCount, id: \.self) { i in
                HStack {
                    Text(sliderLabel(template: draft.template, index: i))
                        .frame(width: 120, alignment: .leading)
                    Slider(value: Binding(
                        get: { draft.slotProportions.indices.contains(i) ? draft.slotProportions[i] : draft.template.defaultProportions[i] },
                        set: { newVal in
                            while draft.slotProportions.count <= i {
                                draft.slotProportions.append(0.5)
                            }
                            draft.slotProportions[i] = newVal
                        }
                    ), in: 0.1...0.9)
                    Text(String(format: "%.0f%%", (draft.slotProportions.indices.contains(i) ? draft.slotProportions[i] : 0) * 100))
                        .frame(width: 40)
                }
            }

            GeometryReader { geo in
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.black.opacity(0.05))
                    ForEach(Array(draft.template.slots(proportions: draft.slotProportions).enumerated()), id: \.offset) { _, slot in
                        let r = slot.rect
                        RoundedRectangle(cornerRadius: 4)
                            .strokeBorder(Color.accentColor, lineWidth: 1.5)
                            .background(RoundedRectangle(cornerRadius: 4).fill(Color.accentColor.opacity(0.12)))
                            .frame(width: max(0, geo.size.width * r.width - 4), height: max(0, geo.size.height * r.height - 4))
                            .position(x: geo.size.width * (r.minX + r.width / 2),
                                      y: geo.size.height * (r.minY + r.height / 2))
                    }
                }
            }
            .frame(maxHeight: 200)

            HStack {
                Spacer()
                Button("settings.action.cancel", action: onCancel)
                Button("settings.action.save", action: onSave).keyboardShortcut(.defaultAction)
            }
        }
        .padding()
    }

    private func displayName(_ tpl: LayoutTemplate) -> String {
        switch tpl {
        case .single:        return String(localized: "layouts.template.single")
        case .twoCol:        return String(localized: "layouts.template.two_col")
        case .threeCol:      return String(localized: "layouts.template.three_col")
        case .twoRow:        return String(localized: "layouts.template.two_row")
        case .threeRow:      return String(localized: "layouts.template.three_row")
        case .grid2x2:       return String(localized: "layouts.template.grid_2x2")
        case .grid3x2:       return String(localized: "layouts.template.grid_3x2")
        case .lShapeLeft:    return String(localized: "layouts.template.l_left")
        case .lShapeRight:   return String(localized: "layouts.template.l_right")
        case .lShapeTop:     return String(localized: "layouts.template.l_top")
        case .lShapeBottom:  return String(localized: "layouts.template.l_bottom")
        }
    }

    private func sliderLabel(template: LayoutTemplate, index: Int) -> String {
        switch template {
        case .twoCol, .threeCol:                return String(format: String(localized: "layouts.slider.column_divider"), index + 1)
        case .twoRow, .threeRow:                return String(format: String(localized: "layouts.slider.row_divider"), index + 1)
        case .grid2x2:                          return index == 0 ? String(localized: "layouts.slider.column_split") : String(localized: "layouts.slider.row_split")
        case .grid3x2:                          return index < 2 ? String(format: String(localized: "layouts.slider.column_divider"), index + 1) : String(localized: "layouts.slider.row_split")
        case .lShapeLeft, .lShapeRight:         return index == 0 ? String(localized: "layouts.slider.main_width") : String(localized: "layouts.slider.stack_split")
        case .lShapeTop, .lShapeBottom:         return index == 0 ? String(localized: "layouts.slider.main_height") : String(localized: "layouts.slider.pair_split")
        case .single:                           return ""
        }
    }
}
