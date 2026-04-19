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
                    Button(recordingForID == layout.id ? "Cancel" : "Record") {
                        recordingForID = (recordingForID == layout.id ? nil : layout.id)
                    }
                    Button("Clear") {
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
        .alert("Error", isPresented: .constant(errorMessage != nil)) {
            Button("OK") { errorMessage = nil }
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
        } catch let LayoutStoreError.hotkeyConflict(existingID) {
            let other = layoutVM.layouts.first(where: { $0.id == existingID })?.name ?? "another layout"
            errorMessage = "This chord is already used by \(other). Unbind it first or pick another."
        } catch {
            errorMessage = String(describing: error)
        }
    }
}
