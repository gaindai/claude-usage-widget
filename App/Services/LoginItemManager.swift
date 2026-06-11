import Foundation
import ServiceManagement

/// Registriert die App als Login-Item, damit der Snapshot auch nach einem
/// Neustart ohne manuelles Öffnen aktuell bleibt.
enum LoginItemManager {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    /// macOS verlangt eine Bestätigung in den Systemeinstellungen
    /// (Anmeldeobjekte), z. B. nach Signaturwechseln.
    static var needsApproval: Bool {
        SMAppService.mainApp.status == .requiresApproval
    }

    static func openSystemSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }

    @discardableResult
    static func setEnabled(_ enabled: Bool) -> Bool {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            return true
        } catch {
            return false
        }
    }
}
