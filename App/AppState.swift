import Foundation
import SwiftUI
import WidgetKit

/// Zentraler Zustand: orchestriert Collector, Rate-Limit-Client und Snapshot,
/// und liefert den Live-Status für Onboarding und Statusfenster.
@MainActor
final class AppState: ObservableObject {
    @Published var snapshot: UsageSnapshot?
    @Published var lastRefresh: Date?
    @Published var rateLimitError: String?
    /// Ein automatischer Fetch bräuchte den Keychain-Dialog (Claude-Code-
    /// Token-Refresh hat die Freigabe zurückgesetzt). Statt zu prompten bietet
    /// die UI ein ruhiges „Reconnect" an.
    @Published var rateLimitNeedsReconnect = false
    @Published var keychainConnected = false
    @Published var loginItemEnabled = LoginItemManager.isEnabled
    @Published var loginItemNeedsApproval = false
    @Published var localDataAvailable = false
    /// Liegt mindestens ein Widget auf dem Schreibtisch? Steuert den „Widget
    /// hinzufügen"-Hinweis im Statusfenster — er verschwindet automatisch, sobald
    /// eines platziert ist. Default true, damit der Hinweis nicht aufblitzt, bevor
    /// WidgetKit geantwortet hat.
    @Published var widgetPlaced = true

    // Bewusst @Published + UserDefaults statt @AppStorage: @AppStorage in einem
    // ObservableObject triggert objectWillChange nicht zuverlässig.
    @Published var onboardingCompleted: Bool {
        didSet { UserDefaults.standard.set(onboardingCompleted, forKey: "onboardingCompleted") }
    }
    @Published var rateLimitsEnabled: Bool {
        didSet { UserDefaults.standard.set(rateLimitsEnabled, forKey: "rateLimitsEnabled") }
    }
    @Published var accent: WidgetAccent {
        didSet { UserDefaults.standard.set(accent.rawValue, forKey: "accent") }
    }

    private let collector = UsageCollector()
    private let rateLimitClient = RateLimitClient()
    private var scheduler: NSBackgroundActivityScheduler?
    private var lastRateLimitFetch: Date = .distantPast
    private var cachedRateLimits: UsageSnapshot.RateLimits?
    private var currentRefresh: Task<Void, Never>?
    private var lastWidgetFingerprint = ""
    private var started = false

    /// Ohne erfolgreichen Fetch innerhalb dieser Zeit gelten Limits als veraltet
    /// und verschwinden aus dem Snapshot (Widget fällt auf lokale Daten zurück).
    static let rateLimitTTL: TimeInterval = 30 * 60
    /// Auch manuelle Refreshes fragen den Endpoint höchstens alle 30 s ab.
    static let forcedPollFloor: TimeInterval = 30

    init() {
        onboardingCompleted = UserDefaults.standard.bool(forKey: "onboardingCompleted")
        rateLimitsEnabled = UserDefaults.standard.bool(forKey: "rateLimitsEnabled")
        accent = WidgetAccent.from(UserDefaults.standard.string(forKey: "accent"))
        localDataAvailable = collector.localDataAvailable
    }

    /// Akzentfarbe wählen: persistieren und sofort in den Snapshot schreiben,
    /// damit das Widget die neue Farbe beim nächsten Render liest.
    func setAccent(_ accent: WidgetAccent) {
        self.accent = accent
        Task { await refresh(force: true) }
    }

    func start() {
        guard !started else { return }
        started = true
        snapshot = SnapshotLocation.read()
        checkWidgetPlaced()

        // Selbstheilung: Ad-hoc-Signaturen ändern sich mit jedem Build, was die
        // Login-Item-Registrierung invalidieren kann — bei gewünschtem Autostart
        // erneut registrieren.
        if UserDefaults.standard.bool(forKey: "loginItemDesired"), !LoginItemManager.isEnabled {
            LoginItemManager.setEnabled(true)
            loginItemEnabled = LoginItemManager.isEnabled
        }

        Task { await refresh() }

        // App-Nap-fester Scheduler — ein Timer würde in einer fensterlosen
        // LSUIElement-App gedrosselt.
        let s = NSBackgroundActivityScheduler(identifier: "ai.gaind.claudeusage.refresh")
        s.repeats = true
        s.interval = RateLimitClient.minimumPollInterval
        s.tolerance = 30
        s.schedule { completion in
            Task { @MainActor [weak self] in
                await self?.refresh()
                completion(.finished)
            }
        }
        scheduler = s
    }

    /// Onboarding-Schritt 2: einmaliger Verbindungsversuch. `rateLimitsEnabled`
    /// wird erst nach dem ersten ERFOLGREICHEN Fetch persistiert — ein
    /// verweigerter Keychain-Dialog führt sonst zu einem Prompt alle 3 Minuten.
    func connectRateLimits() async {
        do {
            cachedRateLimits = try await rateLimitClient.fetch(allowUI: true)
            lastRateLimitFetch = Date()
            keychainConnected = true
            rateLimitError = nil
            rateLimitsEnabled = true
            rateLimitNeedsReconnect = false
            await refresh(force: true)
        } catch {
            rateLimitError = error.localizedDescription
            keychainConnected = false
            rateLimitsEnabled = false
        }
    }

    func disconnectRateLimits() {
        rateLimitsEnabled = false
        cachedRateLimits = nil
        keychainConnected = false
        rateLimitError = nil
        Task { await refresh(force: true) }
    }

    func setLoginItem(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: "loginItemDesired")
        LoginItemManager.setEnabled(enabled)
        loginItemEnabled = LoginItemManager.isEnabled
        loginItemNeedsApproval = enabled && !loginItemEnabled && LoginItemManager.needsApproval
    }

    /// Fragt WidgetKit, ob mindestens ein Widget dieser App auf dem Schreibtisch
    /// liegt — steuert den „Widget hinzufügen"-Hinweis im Statusfenster.
    func checkWidgetPlaced() {
        WidgetCenter.shared.getCurrentConfigurations { result in
            Task { @MainActor [weak self] in
                if case .success(let infos) = result {
                    self?.widgetPlaced = !infos.isEmpty
                }
            }
        }
    }

    /// Refresh-Läufe sind serialisiert: ein laufender Lauf wird abgewartet;
    /// nur force startet danach einen weiteren (z. B. Refresh-Button).
    func refresh(force: Bool = false) async {
        if let running = currentRefresh {
            await running.value
            if !force { return }
        }
        let task = Task { await self.performRefresh(force: force) }
        currentRefresh = task
        await task.value
        if currentRefresh == task { currentRefresh = nil }
    }

    private func performRefresh(force: Bool) async {
        localDataAvailable = collector.localDataAvailable
        checkWidgetPlaced()
        let local = await collector.collect()

        if rateLimitsEnabled {
            let elapsed = Date().timeIntervalSince(lastRateLimitFetch)
            let due = elapsed >= RateLimitClient.minimumPollInterval
                || (force && elapsed >= Self.forcedPollFloor)
            if due {
                lastRateLimitFetch = Date()
                do {
                    cachedRateLimits = try await rateLimitClient.fetch(allowUI: force)
                    keychainConnected = true
                    rateLimitError = nil
                    rateLimitNeedsReconnect = false
                } catch let error as KeychainTokenProvider.TokenError {
                    switch error {
                    case .interactionRequired:
                        // Nur automatische Fetches (allowUI=false) landen hier:
                        // die Freigabe wurde zurückgesetzt. Still zurückziehen und
                        // ein ruhiges „Reconnect" anbieten — KEIN Überraschungs-Dialog.
                        rateLimitNeedsReconnect = true
                    case .accessDenied:
                        // Aktiv verweigert: Abfrage deaktivieren statt alle
                        // 3 Minuten erneut zu prompten; Re-Aktivierung über
                        // Einstellungen/Onboarding.
                        rateLimitError = error.localizedDescription
                        rateLimitsEnabled = false
                        keychainConnected = false
                    default:
                        rateLimitError = error.localizedDescription
                    }
                } catch {
                    rateLimitError = error.localizedDescription
                }
            }
        }

        // Veraltete Limits (Claude Code abgemeldet, Endpoint weg) nicht
        // unbegrenzt als aktuell ausgeben.
        if let cached = cachedRateLimits,
           Date().timeIntervalSince(cached.fetchedAt) > Self.rateLimitTTL {
            cachedRateLimits = nil
        }

        let snap = UsageSnapshot(generatedAt: Date(), rateLimits: cachedRateLimits, local: local, accent: accent)
        snapshot = snap
        lastRefresh = Date()
        do {
            try SnapshotStore.write(snap)
        } catch {
            rateLimitError = "Could not write snapshot: \(error.localizedDescription)"
        }

        // WidgetKit-Reload-Budget schonen: Hintergrund-Apps haben ein begrenztes
        // Tagesbudget an Reloads — nur anstoßen, wenn sich angezeigte Werte
        // tatsächlich geändert haben. Frische erkennt das Widget über seine
        // eigene Timeline (liest generatedAt direkt aus der Datei).
        let fingerprint = Self.widgetFingerprint(snap)
        if fingerprint != lastWidgetFingerprint {
            lastWidgetFingerprint = fingerprint
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    /// Alle Werte, die in irgendeiner Widget-Größe sichtbar sind, in
    /// Anzeige-Granularität.
    private static func widgetFingerprint(_ s: UsageSnapshot) -> String {
        var parts: [String] = [WidgetAccent.from(s.accent?.rawValue).rawValue]
        if let rl = s.rateLimits {
            parts.append("\(Int(rl.fiveHourPercent.rounded()))|\(Int(rl.sevenDayPercent.rounded()))")
            parts.append(rl.fiveHourResetsAt.map { String(Int($0.timeIntervalSince1970)) } ?? "-")
            parts.append(rl.extraUsagePercent.map { String(Int($0.rounded())) } ?? "-")
        } else {
            parts.append("nolimits")
        }
        for day in s.local.days {
            parts.append("\(day.date):\(Format.tokens(day.tokens)):\(day.messageCount):\(day.sessionCount)")
        }
        return parts.joined(separator: ";")
    }
}
