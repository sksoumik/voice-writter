import SwiftUI

/// The Settings window, reachable from the menu.
struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem { Label("General", systemImage: "gearshape") }
            ModelSettingsView()
                .tabItem { Label("Models", systemImage: "cpu") }
            PermissionsSettingsView()
                .tabItem { Label("Permissions", systemImage: "lock.shield") }
        }
        .frame(width: 540, height: 620)
        .padding()
    }
}

private struct GeneralSettingsView: View {
    @ObservedObject var settings = AppSettings.shared

    var body: some View {
        Form {
            Section("How to dictate") {
                Text("Press Option + Q to start listening, then press Option + Q again to stop and insert the cleaned text. Press Escape to cancel.")
                    .font(.callout)
            }

            Section("Grammar") {
                Toggle("Fix grammar automatically", isOn: $settings.grammarEnabled)
                Picker("Correction style", selection: $settings.correctionStyle) {
                    ForEach(CorrectionStyle.allCases) { style in
                        Text(style.title).tag(style)
                    }
                }
                .disabled(!settings.grammarEnabled)
            }

            Section("Custom instructions") {
                Text("Extra rules applied every time, on top of the style above. Put one rule per line.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextEditor(text: $settings.customInstructions)
                    .frame(minHeight: 96)
                    .font(.body)
                    .disabled(!settings.grammarEnabled)
                Text("Examples:\nUse British spelling.\nKeep a professional, friendly tone.\nRemove filler words like um, uh, like, you know.\nPrefer short, clear sentences.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Behavior") {
                Toggle("Show floating overlay while dictating", isOn: $settings.overlayEnabled)
                Toggle("Play start and stop sounds", isOn: $settings.playSounds)
                Toggle("Restore clipboard after inserting", isOn: $settings.restoreClipboard)
                TextField("Language code (blank = auto)", text: $settings.language)
                    .textFieldStyle(.roundedBorder)
            }
        }
        .formStyle(.grouped)
    }
}

private struct ModelSettingsView: View {
    @ObservedObject var settings = AppSettings.shared
    @ObservedObject var controller = DictationController.shared

    var body: some View {
        Form {
            Section("Transcription (Whisper)") {
                TextField("Whisper model (blank = automatic)", text: $settings.whisperModel)
                    .textFieldStyle(.roundedBorder)
                Text("Leave blank to let the app pick the best Whisper model for your Mac. Changing this takes effect after you restart the app.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if controller.whisperProgress > 0, controller.whisperProgress < 1 {
                    ProgressView(value: controller.whisperProgress) {
                        Text("Downloading transcription model")
                    }
                }
            }

            Section("Grammar (local language model)") {
                Picker("Grammar model", selection: $settings.grammarModelId) {
                    ForEach(AppSettings.grammarModelChoices) { choice in
                        Text(choice.label).tag(choice.id)
                    }
                }
                .onChange(of: settings.grammarModelId) { _, _ in
                    controller.reloadGrammarModel()
                }
                if controller.grammarProgress > 0, controller.grammarProgress < 1 {
                    ProgressView(value: controller.grammarProgress) {
                        Text("Downloading grammar model")
                    }
                }
            }

            Section {
                Text(controller.modelsReady ? "Models are loaded and ready." : "Models are loading…")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}

private struct PermissionsSettingsView: View {
    @ObservedObject var permissions = PermissionsManager.shared

    var body: some View {
        Form {
            Section("Microphone") {
                permissionRow(
                    granted: permissions.microphoneGranted,
                    text: "Needed to hear your voice.",
                    action: { permissions.openMicrophoneSettings() }
                )
            }
            Section("Accessibility") {
                permissionRow(
                    granted: permissions.accessibilityGranted,
                    text: "Needed to type the text into other apps.",
                    action: { permissions.openAccessibilitySettings() }
                )
            }
            Section("Input Monitoring") {
                permissionRow(
                    granted: permissions.inputMonitoringGranted,
                    text: "Needed to detect the fn key being held down.",
                    action: { permissions.openInputMonitoringSettings() }
                )
            }
            Section {
                Button("Re-check permissions") { permissions.refresh() }
            }
        }
        .formStyle(.grouped)
        .onAppear { permissions.refresh() }
    }

    private func permissionRow(granted: Bool, text: String, action: @escaping () -> Void) -> some View {
        HStack {
            Image(systemName: granted ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundStyle(granted ? .green : .orange)
            VStack(alignment: .leading) {
                Text(granted ? "Granted" : "Not granted")
                Text(text).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if !granted {
                Button("Open Settings", action: action)
            }
        }
    }
}
