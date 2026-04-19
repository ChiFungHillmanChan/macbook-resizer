import SwiftUI
import SceneCore

struct InteractionTab: View {
    @EnvironmentObject var settingsVM: SettingsStoreViewModel
    @State private var previewToggle: Bool = false

    var body: some View {
        Form {
            Section("Animation") {
                Toggle("Enable smooth animation", isOn: enabledBinding)
                Slider(value: durationBinding, in: 100...500, step: 25) {
                    Text("Duration")
                } minimumValueLabel: {
                    Text("100ms")
                } maximumValueLabel: {
                    Text("500ms")
                }
                .disabled(!settingsVM.animation.enabled)

                Text("\(settingsVM.animation.durationMs)ms")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .trailing)

                Picker("Easing", selection: easingBinding) {
                    ForEach(EasingCurve.allCases, id: \.self) { curve in
                        Text(label(for: curve)).tag(curve)
                    }
                }
                .pickerStyle(.segmented)
                .disabled(!settingsVM.animation.enabled)

                previewSection
            }

            Section("Drag-to-Swap") {
                Toggle("Enable drag-to-swap", isOn: dragSwapEnabledBinding)
                Slider(value: dragSwapThresholdBinding, in: 10...100, step: 5) {
                    Text("Drag distance threshold")
                } minimumValueLabel: {
                    Text("10pt")
                } maximumValueLabel: {
                    Text("100pt")
                }
                .disabled(!settingsVM.dragSwap.enabled)

                Text("\(Int(settingsVM.dragSwap.distanceThresholdPt))pt")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .trailing)

                Text("Hold ⌥ while dragging to temporarily bypass drag-to-swap.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
    }

    private var previewSection: some View {
        VStack(alignment: .leading) {
            Text("Preview").font(.headline)
            GeometryReader { geo in
                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: 8).fill(Color.black.opacity(0.05))
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.accentColor)
                        .frame(width: 60, height: 30)
                        .offset(x: previewToggle ? geo.size.width - 70 : 10, y: 10)
                        .animation(swiftUIAnimation, value: previewToggle)
                }
            }
            .frame(height: 60)
            Button("Run preview") { previewToggle.toggle() }
        }
        .padding(.vertical)
    }

    private var swiftUIAnimation: Animation {
        let dur = Double(settingsVM.animation.durationMs) / 1000.0
        switch settingsVM.animation.easing {
        case .linear:  return .linear(duration: dur)
        case .easeOut: return .easeOut(duration: dur)
        case .spring:  return .spring(duration: dur, bounce: 0.3)
        }
    }

    private var enabledBinding: Binding<Bool> {
        Binding(
            get: { settingsVM.animation.enabled },
            set: { v in
                let c = settingsVM.animation
                try? settingsVM.store.setAnimation(AnimationConfig(enabled: v, durationMs: c.durationMs, easing: c.easing))
            }
        )
    }

    private var durationBinding: Binding<Double> {
        Binding(
            get: { Double(settingsVM.animation.durationMs) },
            set: { v in
                let c = settingsVM.animation
                try? settingsVM.store.setAnimation(AnimationConfig(enabled: c.enabled, durationMs: Int(v), easing: c.easing))
            }
        )
    }

    private var easingBinding: Binding<EasingCurve> {
        Binding(
            get: { settingsVM.animation.easing },
            set: { v in
                let c = settingsVM.animation
                try? settingsVM.store.setAnimation(AnimationConfig(enabled: c.enabled, durationMs: c.durationMs, easing: v))
            }
        )
    }

    private var dragSwapEnabledBinding: Binding<Bool> {
        Binding(
            get: { settingsVM.dragSwap.enabled },
            set: { v in
                let c = settingsVM.dragSwap
                try? settingsVM.store.setDragSwap(DragSwapConfig(enabled: v, distanceThresholdPt: c.distanceThresholdPt))
            }
        )
    }

    private var dragSwapThresholdBinding: Binding<Double> {
        Binding(
            get: { Double(settingsVM.dragSwap.distanceThresholdPt) },
            set: { v in
                let c = settingsVM.dragSwap
                try? settingsVM.store.setDragSwap(DragSwapConfig(enabled: c.enabled, distanceThresholdPt: CGFloat(v)))
            }
        )
    }

    private func label(for curve: EasingCurve) -> String {
        switch curve {
        case .linear:  return "Linear"
        case .easeOut: return "Ease Out"
        case .spring:  return "Spring"
        }
    }
}
