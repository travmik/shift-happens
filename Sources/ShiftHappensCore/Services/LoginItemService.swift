import Foundation
import ServiceManagement

/// Registers/unregisters the app as a login item via SMAppService (macOS 13+).
/// The system is the source of truth — status is queried live, never persisted in
/// settings, so the state stays correct even if the user flips the switch in
/// System Settings → General → Login Items. Requires a proper .app bundle; the
/// bare `swift run` executable cannot be registered and setEnabled will throw.
public final class LoginItemService: LoginItemServicing {
    public init() {}

    public var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    public func setEnabled(_ enabled: Bool) throws {
        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }
}
