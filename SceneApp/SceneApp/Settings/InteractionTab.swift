import SwiftUI
import SceneCore

struct InteractionTab: View {
    @EnvironmentObject var settingsVM: SettingsStoreViewModel
    @State private var previewToggle: Bool = false

    var body: some View {
        Form {
            Section("interaction.animation.section") {
                Toggle("interaction.animation.enable", isOn: enabledBinding)
                Slider(value: durationBinding, in: 100...500, step: 25) {
                    Text("interaction.animation.duration")
                } minimumValueLabel: {
                    Text("interaction.animation.duration.min")
                } maximumValueLabel: {
                    Text("interaction.animation.duration.max")
                }
                .disabled(!settingsVM.animation.enabled)

                Text(String(format: String(localized: "interaction.animation.duration.value"), settingsVM.animation.durationMs))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .trailing)

                Picker("interaction.animation.easing", selection: easingBinding) {
                    ForEach(EasingCurve.allCases, id: \.self) { curve in
                        Text(label(for: curve)).tag(curve)
                    }
                }
                .pickerStyle(.segmented)
                .disabled(!settingsVM.animation.enabled)

                previewSection
            }

            Section("interaction.drag_swap.section") {
                Toggle("interaction.drag_swap.enable", isOn: dragSwapEnabledBinding)
                Slider(value: dragSwapThresholdBinding, in: 10...100, step: 5) {
                    Text("interaction.drag_swap.threshold")
                } minimumValueLabel: {
                    Text("interaction.drag_swap.threshold.min")
                } maximumValueLabel: {
                    Text("interaction.drag_swap.threshold.max")
                }
                .disabled(!settingsVM.dragSwap.enabled)

                Text(String(format: String(localized: "interaction.drag_swap.threshold.value"), Int(settingsVM.dragSwap.distanceThresholdPt)))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .trailing)

                Text("interaction.drag_swap.hint")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
    }

    private var previewSection: some View {
        VStack(alignment: .leading) {
            Text("interaction.animation.preview").font(.headline)
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
            Button("interaction.animation.preview.run") { previewToggle.toggle() }
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
        case .linear:  return String(localized: "interaction.animation.easing.linear")
        case .easeOut: return String(localized: "interaction.animation.easing.ease_out")
        case .spring:  return String(localized: "interaction.animation.easing.spring")
        }
    }
}
