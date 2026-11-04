import SwiftUI
import AVFoundation

@MainActor struct SettingsView: View {
    @ObservedObject var settings: SettingsManager
    @ObservedObject var permissions: PermissionManager
    let streaming: Bool
    @Environment(\.dismiss) private var dismiss
    private var license: String {
        guard let url = Bundle.main.url(forResource: "LICENSE", withExtension: "txt"), let text = try? String(contentsOf: url) else { return "MIT License · Copyright 2026 Farzonline and Micophone iOS contributors" }
        return text
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Permissions") {
                    LabeledContent("Microphone", value: permissionLabel)
                    Button("Open iOS Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                    }
                    Text("Local Network access is requested when you connect to the PC. Enable it in iOS Settings if a connection cannot be made.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Section {
                    Picker("Audio quality", selection: $settings.quality) {
                        ForEach(AudioQuality.allCases) { Text($0.rawValue + " · 16-bit mono").tag($0) }
                    }
                    Picker("Capture buffering", selection: $settings.buffer) {
                        ForEach(BufferPreset.allCases) { Text($0.rawValue).tag($0) }
                    }
                    Text(settings.buffer.detail).font(.caption).foregroundStyle(.secondary)
                    Toggle("Allow Bluetooth microphone", isOn: $settings.bluetooth)
                    Text("Bluetooth call profiles may reduce microphone bandwidth. Hardware rate is converted to the selected wire format. Gain is software amplification, not a hardware gain guarantee.")
                        .font(.caption).foregroundStyle(.secondary)
                } header: { Text("Audio") } footer: {
                    Text("Disconnect before changing audio settings. Packets always contain 10 ms of audio. Adjust the PC receiver's jitter buffer separately.")
                }.disabled(streaming)
                Section("Connection") {
                    Toggle("Reconnect after Wi-Fi loss", isOn: $settings.reconnect).disabled(streaming)
                    Text("Wi-Fi only. Uses the address you enter; no automatic broadcast scanning. No accounts, cloud, advertising, analytics or audio files. The original protocol is unencrypted and unauthenticated; use a trusted private network.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Section("Screen off and interruptions") {
                    Text("Start microphone while this app is open. An active recording session is configured to continue when the screen locks or you switch apps. This build has not been validated on a physical iPhone.")
                    Text("Calls and other audio sessions can interrupt recording. Resumption is attempted only when iOS permits it. If it fails, return here and start again. Force quitting stops recording. Muting sends silence while the recording session stays active; Stop releases the microphone.")
                }.font(.footnote)
                Section("Open source") {
                    LabeledContent("Version", value: "\(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0") (\(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"))")
                    Link("Original Micophone source", destination: URL(string: "https://github.com/farzonline/micophone")!)
                    Text("Protocol v2 · upstream e7d977d · MIT").font(.caption)
                    DisclosureGroup("License notices") { Text(license).font(.caption).textSelection(.enabled) }
                }
            }.navigationTitle("Settings").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
                .onAppear { permissions.refresh() }
        }
    }

    private var permissionLabel: String {
        switch permissions.status {
        case .granted: return "Allowed"
        case .denied: return "Denied"
        default: return "Not requested"
        }
    }
}
