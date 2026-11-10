import Combine
import Foundation
import ServiceManagement

@MainActor
final class LoginItem: ObservableObject {
    static let shared = LoginItem()

    @Published var isEnabled: Bool {
        didSet {
            guard isEnabled != (SMAppService.mainApp.status == .enabled) else { return }
            do {
                if isEnabled {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                lastError = error.localizedDescription
                isEnabled = SMAppService.mainApp.status == .enabled
            }
        }
    }

    @Published private(set) var lastError: String?

    init() {
        isEnabled = SMAppService.mainApp.status == .enabled
    }
}
