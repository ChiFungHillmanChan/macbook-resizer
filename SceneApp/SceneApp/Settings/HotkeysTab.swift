import SwiftUI
import SceneCore

struct HotkeysTab: View {
    @EnvironmentObject var layoutVM: LayoutStoreViewModel
    @State private var recordingForID: UUID?
    @State private var errorMessage: String?

    var body: some View {
        List {
            ForEach(layoutVM.layouts) { layout in
                HStack {
                    Text(layout.name).frame(width: 180, alignment: .leading)
                    if recordingForID == layout.id {
                        HotkeyCaptureView { binding in
                            attempt(binding: binding, on: layout)
                        }
                        .frame(height: 28)
                    } else {
                        Text(layout.hotkey?.displayString ?? "\u{2014}")
                            .frame(width: 100, alignment: .leading)
                            .foregroundStyle(layout.hotkey == nil ? .secondary : .primary)
                    }
                    Spacer()
                    Button(recordingForID == layout.id
                           ? LocalizedStringKey("settings.action.cancel")
                           : LocalizedStringKey("hotkeys.record")) {
                        recordingForID = (recordingForID == layout.id ? nil : layout.id)
                    }
                    Button("hotkeys.clear") {
                        var copy = layout
                        copy.hotkey = nil
                        do { try layoutVM.store.update(copy) }
                        catch { errorMessage = String(describing: error) }
                    }
                    .disabled(layout.hotkey == nil)
                }
                .padding(.vertical, 2)
            }
        }
        .alert("common.error", isPresented: .constant(errorMessage != nil)) {
            Button("common.ok") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func attempt(binding: HotkeyBinding, on layout: CustomLayout) {
        var copy = layout
        copy.hotkey = binding
        do {
            try layoutVM.store.update(copy)
            recordingForID = nil
        } catch let LayoutStoreError.hotkeyConflict(existingResource) {
            errorMessage = String(format: String(localized: "hotkeys.conflict"), existingResource)
        } catch {
            errorMessage = String(describing: error)
        }
    }
}
