import Foundation

/// Fragt den gleichen Endpoint ab, den `/usage` in der Claude-Code-CLI nutzt.
/// Undokumentiert, aber Community-Standard; Poll-Intervall mindestens 180 s.
/// Einziger Netzwerk-Call der gesamten App.
final class RateLimitClient {
    enum ClientError: LocalizedError {
        case httpError(Int)
        case invalidResponse

        var errorDescription: String? {
            switch self {
            case .httpError(let code) where code == 401:
                return "Token expired — run Claude Code once and it will refresh."
            case .httpError(let code):
                return "Anthropic API responded with HTTP \(code)."
            case .invalidResponse:
                return "Unexpected response from the Anthropic API."
            }
        }
    }

    static let minimumPollInterval: TimeInterval = 180

    private static let host = "api.anthropic.com"
    private let endpoint = URL(string: "https://api.anthropic.com/api/oauth/usage")!
    private let session: URLSession
    private let redirectGuard = RedirectGuard()

    init() {
        let config = URLSessionConfiguration.ephemeral // kein Cookie-/Cache-Persistieren
        config.timeoutIntervalForRequest = 20
        session = URLSession(configuration: config, delegate: redirectGuard, delegateQueue: nil)
    }

    /// Verhindert, dass das Bearer-Token bei einem Redirect an einen fremden
    /// Host weitergereicht wird — Foundation strippt den Authorization-Header
    /// (anders als curl) nicht automatisch. Off-Host-Redirects werden gekappt.
    private final class RedirectGuard: NSObject, URLSessionTaskDelegate {
        func urlSession(_ session: URLSession, task: URLSessionTask,
                        willPerformHTTPRedirection response: HTTPURLResponse,
                        newRequest request: URLRequest,
                        completionHandler: @escaping (URLRequest?) -> Void) {
            if request.url?.host == RateLimitClient.host {
                completionHandler(request)
            } else {
                completionHandler(nil) // Redirect nicht folgen
            }
        }
    }

    func fetch() async throws -> UsageSnapshot.RateLimits {
        // Keychain-Zugriff abseits des MainActors: SecItemCopyMatching blockiert,
        // solange der Berechtigungs-Dialog offen ist.
        let token = try await Task.detached(priority: .userInitiated) {
            try KeychainTokenProvider.accessToken()
        }.value

        var request = URLRequest(url: endpoint)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")
        request.setValue("claude-code/2.1.173 (external, cli)", forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw ClientError.invalidResponse }
        guard http.statusCode == 200 else { throw ClientError.httpError(http.statusCode) }

        let api = try JSONDecoder().decode(APIResponse.self, from: data)
        return UsageSnapshot.RateLimits(
            fiveHourPercent: api.five_hour?.utilization ?? 0,
            fiveHourResetsAt: Self.parseDate(api.five_hour?.resets_at),
            sevenDayPercent: api.seven_day?.utilization ?? 0,
            sevenDayResetsAt: Self.parseDate(api.seven_day?.resets_at),
            sevenDayOpusPercent: api.seven_day_opus?.utilization,
            sevenDaySonnetPercent: api.seven_day_sonnet?.utilization,
            extraUsageEnabled: api.extra_usage?.is_enabled ?? false,
            extraUsagePercent: api.extra_usage?.utilization,
            fetchedAt: Date()
        )
    }

    private static let isoFractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    private static let isoPlain = ISO8601DateFormatter()

    private static func parseDate(_ s: String?) -> Date? {
        guard let s else { return nil }
        return isoFractional.date(from: s) ?? isoPlain.date(from: s)
    }

    private struct APIResponse: Decodable {
        struct Bucket: Decodable {
            let utilization: Double?
            let resets_at: String?
        }
        struct Extra: Decodable {
            let is_enabled: Bool?
            let utilization: Double?
        }
        let five_hour: Bucket?
        let seven_day: Bucket?
        let seven_day_opus: Bucket?
        let seven_day_sonnet: Bucket?
        let extra_usage: Extra?
    }
}
