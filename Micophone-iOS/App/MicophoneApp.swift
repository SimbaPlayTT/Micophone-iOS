import SwiftUI

@main @MainActor struct MicophoneApp: App {
    @StateObject private var settings: SettingsManager
    @StateObject private var permissions: PermissionManager
    @StateObject private var connection: ConnectionManager
    @Environment(\.scenePhase) private var scenePhase

    init() {
        let settings = SettingsManager()
        let permissions = PermissionManager()
        _settings = StateObject(wrappedValue: settings)
        _permissions = StateObject(wrappedValue: permissions)
        _connection = StateObject(wrappedValue: ConnectionManager(settings: settings, permissions: permissions))
    }

    var body: some Scene {
        WindowGroup {
            MainView(model: connection, settings: settings, permissions: permissions)
                .tint(.mint)
                .onChange(of: scenePhase) { phase in
                    // Permission alerts temporarily make the scene inactive. They must not cancel
                    // the explicit Start request; only an actual background transition is relevant.
                    if phase != .inactive { connection.sceneChanged(active: phase == .active) }
                }
                .onChange(of: settings.gain) { _ in connection.updateGain() }
        }
    }
}
