import AVFoundation
import Combine

@MainActor final class PermissionManager: ObservableObject {
    @Published private(set) var status: AVAudioSession.RecordPermission = AVAudioSession.sharedInstance().recordPermission

    func refresh() { status = AVAudioSession.sharedInstance().recordPermission }

    func requestMicrophone() async -> Bool {
        refresh()
        if status == .granted { return true }
        if status == .denied { return false }
        let granted = await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { continuation.resume(returning: $0) }
        }
        refresh()
        return granted
    }
}
