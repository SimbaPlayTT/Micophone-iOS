import SwiftUI

@MainActor struct MainView: View {
    @ObservedObject var model: ConnectionManager
    @ObservedObject var settings: SettingsManager
    @ObservedObject var permissions: PermissionManager
    @State private var showingSettings = false
    @FocusState private var editing: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    VStack(spacing: 10) {
                        Image(systemName: model.isRecording ? "waveform.circle.fill" : "mic.circle")
                            .font(.system(size: 78, weight: .light))
                            .foregroundStyle(model.isRecording ? Color.mint : Color.secondary)
                            .accessibilityHidden(true)
                        Label(model.statusText, systemImage: model.isConnected ? "wifi" : "circle.dotted")
                            .font(.headline).multilineTextAlignment(.center)
                        Text(model.message).font(.subheadline).foregroundStyle(.secondary)
                            .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity).padding(.top, 12)

                    VStack(alignment: .leading, spacing: 14) {
                        Text("YOUR WINDOWS PC").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                        HStack {
                            TextField("PC IPv4 address", text: $settings.host)
                                .keyboardType(.decimalPad).textInputAutocapitalization(.never).autocorrectionDisabled()
                                .accessibilityLabel("PC IP address").focused($editing)
                            Divider().frame(height: 24)
                            TextField("50005", text: $settings.port).keyboardType(.numberPad)
                                .frame(width: 76).accessibilityLabel("PC port").focused($editing)
                        }
                        .padding(12).background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 10))
                        .disabled(model.hasLink || model.hasSession)
                        Button {
                            editing = false
                            if model.hasLink { model.disconnect() } else { model.connect() }
                        } label: {
                            Label(model.hasLink ? "Disconnect PC" : "Connect to PC", systemImage: model.hasLink ? "wifi.slash" : "wifi")
                                .frame(maxWidth: .infinity)
                        }.buttonStyle(.bordered).disabled(model.hasSession)
                    }.card()

                    VStack(spacing: 18) {
                        HStack {
                            Label(model.isRecording ? (model.muted ? "MUTED · CAPTURE ACTIVE" : "MICROPHONE ACTIVE") : "MICROPHONE OFF",
                                  systemImage: model.muted ? "mic.slash.fill" : "mic.fill")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(model.isRecording ? Color.mint : Color.secondary)
                            Spacer()
                            Text(settings.quality.rawValue).font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                        }
                        LevelMeter(level: model.level)
                        Button {
                            editing = false
                            if model.hasSession { model.stop() } else { Task { await model.start() } }
                        } label: {
                            Label(model.hasSession ? "Stop microphone" : "Start microphone",
                                  systemImage: model.hasSession ? "stop.fill" : "mic.fill")
                                .font(.headline).frame(maxWidth: .infinity).padding(.vertical, 10)
                        }
                        .buttonStyle(.borderedProminent).tint(model.hasSession ? .red : .mint)
                        .foregroundStyle(model.hasSession ? .white : .black)
                        Button { model.toggleMute() } label: {
                            Label(model.muted ? "Unmute microphone" : "Mute microphone",
                                  systemImage: model.muted ? "mic.fill" : "mic.slash.fill")
                                .frame(maxWidth: .infinity)
                        }.buttonStyle(.bordered).disabled(!model.isRecording)
                        HStack {
                            Text("Software gain").font(.caption)
                            Slider(value: $settings.gain, in: 0...2, step: 0.05).accessibilityLabel("Software microphone gain")
                            Text(String(format: "%.2f×", settings.gain)).font(.caption.monospacedDigit()).frame(width: 42)
                        }
                        Text(model.route).font(.caption).foregroundStyle(.secondary)
                        if model.hasLink {
                            Text("\(settings.host):\(settings.port) · \(model.sent) packets · \(model.dropped) queue drops")
                                .font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
                        }
                    }.card()

                    Label("Start here before locking your iPhone. Background recording is configured; physical-device validation is still required.",
                          systemImage: "lock.iphone")
                        .font(.caption).foregroundStyle(.secondary).padding(.horizontal, 4)
                }.padding(20)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Micophone iOS")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showingSettings = true } label: { Image(systemName: "gearshape") }.accessibilityLabel("Settings")
                }
                ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("Done") { editing = false } }
            }
            .sheet(isPresented: $showingSettings) { SettingsView(settings: settings, permissions: permissions, streaming: model.hasSession || model.hasLink) }
        }
    }
}

private struct LevelMeter: View {
    let level: Float
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.secondary.opacity(0.15))
                Capsule().fill(level > 0.9 ? Color.orange : Color.mint)
                    .frame(width: max(0, geometry.size.width * CGFloat(min(1, max(0, level)))))
            }
        }.frame(height: 12)
            .accessibilityElement().accessibilityLabel("Microphone level")
            .accessibilityValue("\(Int(level * 100)) percent")
    }
}

private extension View {
    func card() -> some View {
        padding(18).background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18))
    }
}
