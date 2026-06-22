import Foundation
import AVFoundation
import AppKit
import ApplicationServices
import CoreGraphics

/// Checks and requests the permissions the app needs:
/// the microphone (to hear you), Accessibility (to type into other apps), and
/// Input Monitoring (to detect the global dictation shortcut).
@MainActor
final class PermissionsManager: ObservableObject {
    static let shared = PermissionsManager()

    @Published var microphoneGranted: Bool = false
    @Published var accessibilityGranted: Bool = false
    @Published var inputMonitoringGranted: Bool = false

    private init() {
        refresh()
    }

    /// Re-read the current status of all permissions.
    func refresh() {
        microphoneGranted = AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
        accessibilityGranted = AXIsProcessTrusted()
        inputMonitoringGranted = CGPreflightListenEventAccess()
    }

    /// True only when all permissions are granted.
    var allGranted: Bool {
        microphoneGranted && accessibilityGranted && inputMonitoringGranted
    }

    /// Ask the system for microphone access. Shows the standard prompt the first
    /// time, then returns the saved decision on later calls.
    func requestMicrophone() async -> Bool {
        let granted = await AVCaptureDevice.requestAccess(for: .audio)
        microphoneGranted = granted
        return granted
    }

    /// Ask for Accessibility access. macOS does not show an in app prompt here;
    /// it shows a system alert that deep links to Settings, and the user must
    /// toggle the app on themselves.
    func requestAccessibility() {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let options = [key: true] as CFDictionary
        accessibilityGranted = AXIsProcessTrustedWithOptions(options)
    }

    /// Ask for Input Monitoring access. Shows the system prompt the first time.
    func requestInputMonitoring() {
        inputMonitoringGranted = CGRequestListenEventAccess()
    }

    /// Open the Accessibility pane of System Settings directly.
    func openAccessibilitySettings() {
        let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        )!
        NSWorkspace.shared.open(url)
    }

    /// Open the Input Monitoring pane of System Settings directly.
    func openInputMonitoringSettings() {
        let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent"
        )!
        NSWorkspace.shared.open(url)
    }

    /// Open the Microphone pane of System Settings directly.
    func openMicrophoneSettings() {
        let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone"
        )!
        NSWorkspace.shared.open(url)
    }
}
