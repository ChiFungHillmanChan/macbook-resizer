import SwiftUI
import SceneCore

struct AnimationTab: View {
    @EnvironmentObject var settingsVM: SettingsStoreViewModel
    @State private var previewToggle: Bool = false

    var body: some View {
        Form {
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
            set: { newVal in
                let cur = settingsVM.animation
                try? settingsVM.store.setAnimation(AnimationConfig(enabled: newVal, durationMs: cur.durationMs, easing: cur.easing))
            }
        )
    }

    private var durationBinding: Binding<Double> {
        Binding(
            get: { Double(settingsVM.animation.durationMs) },
            set: { newVal in
                let cur = settingsVM.animation
                try? settingsVM.store.setAnimation(AnimationConfig(enabled: cur.enabled, durationMs: Int(newVal), easing: cur.easing))
            }
        )
    }

    private var easingBinding: Binding<EasingCurve> {
        Binding(
            get: { settingsVM.animation.easing },
            set: { newVal in
                let cur = settingsVM.animation
                try? settingsVM.store.setAnimation(AnimationConfig(enabled: cur.enabled, durationMs: cur.durationMs, easing: newVal))
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
