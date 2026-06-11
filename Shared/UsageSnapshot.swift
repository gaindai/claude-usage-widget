import Foundation

/// Aggregierter Nutzungs-Snapshot — die einzige Datei, die App und Widget teilen.
/// Enthält ausschließlich Zahlen, niemals Tokens, Prompts oder Inhalte.
struct UsageSnapshot: Codable {
    var generatedAt: Date
    var rateLimits: RateLimits?
    var local: LocalUsage
    /// Vom Nutzer in der App gewählte Akzentfarbe; optional, damit ältere
    /// Snapshots ohne das Feld weiterhin dekodieren (Fallback: WidgetAccent.default).
    var accent: WidgetAccent?

    struct RateLimits: Codable {
        var fiveHourPercent: Double
        var fiveHourResetsAt: Date?
        var sevenDayPercent: Double
        var sevenDayResetsAt: Date?
        var sevenDayOpusPercent: Double?
        var sevenDaySonnetPercent: Double?
        var extraUsageEnabled: Bool
        var extraUsagePercent: Double?
        var fetchedAt: Date
    }

    struct LocalUsage: Codable {
        /// Letzte 7 Tage, älteste zuerst, letzter Eintrag = heute.
        var days: [DayStat]

        var today: DayStat? { days.last }
        var weekTokens: Int { days.reduce(0) { $0 + $1.tokens } }
        var weekMessages: Int { days.reduce(0) { $0 + $1.messageCount } }
    }

    struct DayStat: Codable {
        var date: String // yyyy-MM-dd, lokale Zeitzone
        var inputTokens: Int
        var outputTokens: Int
        var cacheReadTokens: Int
        var cacheWriteTokens: Int
        var messageCount: Int
        var sessionCount: Int

        /// Angezeigte Tokens = Input + Output ohne Cache — gleiche Definition
        /// wie „Total tokens" in Claude Codes /usage-Statistik.
        var tokens: Int { inputTokens + outputTokens }

        static func empty(date: String) -> DayStat {
            DayStat(date: date, inputTokens: 0, outputTokens: 0, cacheReadTokens: 0,
                    cacheWriteTokens: 0, messageCount: 0, sessionCount: 0)
        }
    }
}

enum SnapshotLocation {
    static let directoryRelativePath = "Library/Application Support/ClaudeUsage"
    static let fileName = "snapshot.json"

    /// Echtes Home-Verzeichnis — in der sandboxten Widget-Extension zeigt
    /// NSHomeDirectory() auf den Container, daher Auflösung über getpwuid.
    static var realHome: URL {
        if let pw = getpwuid(getuid()), let dir = pw.pointee.pw_dir {
            return URL(fileURLWithPath: String(cString: dir))
        }
        return FileManager.default.homeDirectoryForCurrentUser
    }

    static var directoryURL: URL { realHome.appendingPathComponent(directoryRelativePath) }
    static var fileURL: URL { directoryURL.appendingPathComponent(fileName) }

    static func makeEncoder() -> JSONEncoder {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.outputFormatting = [.sortedKeys]
        return e
    }

    static func makeDecoder() -> JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }

    static func read() -> UsageSnapshot? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return try? makeDecoder().decode(UsageSnapshot.self, from: data)
    }
}
