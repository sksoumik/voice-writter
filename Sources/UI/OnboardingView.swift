import SwiftUI

/// First run setup: grant permissions and wait for the models to download.
struct OnboardingView: View {
    @ObservedObject var permissions = PermissionsManager.shared
    @ObservedObject var controller = DictationController.shared
    @ObservedObject var settings = AppSettings.shared

    /// Called when the user taps Done. The window controller closes the window.
    var onClose: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Welcome to Voice Writter")
                    .font(.title2).bold()
                Text("Dictate anywhere on your Mac. Your speech is turned into text and the grammar is cleaned up, all on device.")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Divider()

            stepRow(
                number: 1,
                title: "Allow the microphone",
                done: permissions.microphoneGranted
            ) {
                Button("Allow microphone") {
                    Task { await permissions.requestMicrophone() }
                }
                .disabled(permissions.microphoneGranted)
            }

            stepRow(
                number: 2,
                title: "Allow Accessibility",
                done: permissions.accessibilityGranted,
                detail: "This lets Voice Writter type the text into other apps. Turn on Voice Writter in the list, then come back."
            ) {
                HStack {
                    Button("Request access") { permissions.requestAccessibility() }
                    Button("Open Settings") { permissions.openAccessibilitySettings() }
                }
            }

            stepRow(
                number: 3,
                title: "Allow Input Monitoring",
                done: permissions.inputMonitoringGranted,
                detail: "This lets Voice Writter detect the Right Command key (and the optional Option + Q shortcut). Turn on Voice Writter in the list, then come back."
            ) {
                HStack {
                    Button("Request access") { permissions.requestInputMonitoring() }
                    Button("Open Settings") { permissions.openInputMonitoringSettings() }
                }
            }

            stepRow(
                number: 4,
                title: "Download the models",
                done: controller.modelsReady,
                detail: "About 2 to 3 GB total, downloaded once."
            ) {
                VStack(alignment: .leading, spacing: 6) {
                    progressLine("Transcription", value: controller.whisperProgress)
                    progressLine("Grammar", value: controller.grammarProgress)
                }
            }

            stepRow(
                number: 5,
                title: "How to use it",
                done: true,
                detail: "Tap the Right Command (⌘) key to start listening, then tap it again to stop. Voice Writter types the cleaned text where your cursor is. Press Escape to cancel. You can also set an optional key combo in Settings."
            ) { EmptyView() }

            Divider()

            HStack {
                Button("Re-check permissions") { permissions.refresh() }
                Spacer()
                Button("Done") {
                    settings.didCompleteOnboarding = true
                    onClose()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!permissions.allGranted)
            }
        }
        .padding(24)
        .frame(width: 520)
        .onAppear { permissions.refresh() }
        .onReceive(timer) { _ in permissions.refresh() }
    }

    // Refresh permission status periodically while this window is open, because
    // the user grants Accessibility outside the app.
    private let timer = Timer.publish(every: 1.5, on: .main, in: .common).autoconnect()

    @ViewBuilder
    private func stepRow<Content: View>(
        number: Int,
        title: String,
        done: Bool,
        detail: String? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(done ? Color.green : Color.secondary.opacity(0.25))
                    .frame(width: 26, height: 26)
                if done {
                    Image(systemName: "checkmark").font(.caption.bold()).foregroundStyle(.white)
                } else {
                    Text("\(number)").font(.caption.bold())
                }
            }
            VStack(alignment: .leading, spacing: 6) {
                Text(title).font(.headline)
                if let detail {
                    Text(detail).font(.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                content()
            }
            Spacer()
        }
    }

    private func progressLine(_ label: String, value: Double) -> some View {
        HStack {
            Text(label).frame(width: 90, alignment: .leading).font(.caption)
            ProgressView(value: max(0, min(value, 1)))
        }
    }
}
