import Foundation
import Security

/// Liest das OAuth-Token von Claude Code direkt aus dem macOS-Keychain.
/// Das Token wird ausschließlich im Speicher gehalten — niemals auf Disk
/// geschrieben, niemals geloggt. Beim ersten Zugriff zeigt macOS einen
/// Berechtigungs-Dialog ("Immer erlauben" merkt sich die Entscheidung).
enum KeychainTokenProvider {
    enum TokenError: LocalizedError {
        case notFound
        case accessDenied(OSStatus)
        case parseFailed

        var errorDescription: String? {
            switch self {
            case .notFound:
                return "No Claude Code login found. Run `claude` in a terminal once and log in."
            case .accessDenied(let status):
                return "Keychain access denied (status \(status))."
            case .parseFailed:
                return "The keychain entry has an unexpected format."
            }
        }
    }

    /// Claude Code verwendete je nach Version unterschiedliche Service-Namen.
    private static let serviceNames = ["Claude Code-credentials", "Claude Code"]

    static func accessToken() throws -> String {
        // Ein Deny (z. B. errSecAuthFailed) hat Vorrang vor einem NotFound des
        // zweiten Service-Namens — sonst entsteht eine irreführende Meldung.
        var deniedStatus: OSStatus?
        for service in serviceNames {
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service,
                kSecReturnData as String: true,
                kSecMatchLimit as String: kSecMatchLimitOne,
            ]
            var item: CFTypeRef?
            let status = SecItemCopyMatching(query as CFDictionary, &item)
            if status == errSecSuccess {
                guard let data = item as? Data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let oauth = json["claudeAiOauth"] as? [String: Any],
                      let token = oauth["accessToken"] as? String, !token.isEmpty else {
                    throw TokenError.parseFailed
                }
                return token
            }
            if status != errSecItemNotFound {
                deniedStatus = status
            }
        }
        if let deniedStatus {
            throw TokenError.accessDenied(deniedStatus)
        }
        throw TokenError.notFound
    }
}
