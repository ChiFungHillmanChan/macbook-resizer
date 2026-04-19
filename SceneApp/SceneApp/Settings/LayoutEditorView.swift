import SwiftUI
import SceneCore

struct LayoutEditorView: View {
    @Binding var draft: CustomLayout
    let onSave: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            TextField("Name", text: $draft.name)
                .textFieldStyle(.roundedBorder)

            Picker("Template", selection: $draft.template) {
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
                Button("Cancel", action: onCancel)
                Button("Save", action: onSave).keyboardShortcut(.defaultAction)
            }
        }
        .padding()
    }

    private func displayName(_ tpl: LayoutTemplate) -> String {
        switch tpl {
        case .single:        return "Single"
        case .twoCol:        return "2 Columns"
        case .threeCol:      return "3 Columns"
        case .twoRow:        return "2 Rows"
        case .threeRow:      return "3 Rows"
        case .grid2x2:       return "2 \u{00D7} 2 Grid"
        case .grid3x2:       return "3 \u{00D7} 2 Grid"
        case .lShapeLeft:    return "L-shape (Main Left)"
        case .lShapeRight:   return "L-shape (Main Right)"
        case .lShapeTop:     return "L-shape (Main Top)"
        case .lShapeBottom:  return "L-shape (Main Bottom)"
        }
    }

    private func sliderLabel(template: LayoutTemplate, index: Int) -> String {
        switch template {
        case .twoCol, .threeCol:                return "Column divider \(index + 1)"
        case .twoRow, .threeRow:                return "Row divider \(index + 1)"
        case .grid2x2:                          return index == 0 ? "Column split" : "Row split"
        case .grid3x2:                          return index < 2 ? "Column divider \(index + 1)" : "Row split"
        case .lShapeLeft, .lShapeRight:         return index == 0 ? "Main width" : "Stack split"
        case .lShapeTop, .lShapeBottom:         return index == 0 ? "Main height" : "Pair split"
        case .single:                           return ""
        }
    }
}
