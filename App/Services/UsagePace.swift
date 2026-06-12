import Foundation

/// Beobachtet den Verlauf der 5-h-Auslastung über mehrere Abfragen und rechnet
/// linear auf den Reset-Zeitpunkt hoch: „Bei diesem Tempo landet das Fenster
/// bei ~X %." Die Auslastung selbst kommt exakt vom Server — nur die Steigung
/// wird lokal aus aufeinanderfolgenden Messpunkten geschätzt.
///
/// Bewusst nur im Speicher gehalten: Nach einem App-Neustart fehlt die
/// Hochrechnung für ein paar Minuten, bis genug Messpunkte da sind — das ist
/// ehrlicher als eine aus veralteten Werten fortgeschriebene Kurve.
struct UsagePace {
    private var samples: [(at: Date, percent: Double)] = []

    /// Messpunkte älter als dieses Fenster fließen nicht in die Steigung ein —
    /// die Hochrechnung soll das aktuelle Tempo zeigen, nicht den Durchschnitt
    /// seit Fensterbeginn.
    static let slopeWindow: TimeInterval = 45 * 60
    /// Mindestspanne zwischen ältestem und neuestem Messpunkt, bevor eine
    /// Steigung als belastbar gilt (Poll-Intervall ist 180 s — eine einzelne
    /// Intervall-Differenz wäre zu sprunghaft).
    static let minimumSpan: TimeInterval = 5 * 60

    mutating func record(percent: Double, at date: Date) {
        // Gesunkene Auslastung = das 5-h-Fenster wurde zurückgesetzt; alte
        // Messpunkte würden eine negative Steigung vortäuschen.
        if let last = samples.last, percent < last.percent {
            samples.removeAll()
        }
        samples.append((at: date, percent: percent))
        let cutoff = date.addingTimeInterval(-Self.slopeWindow)
        samples.removeAll { $0.at < cutoff }
    }

    /// Lineare Hochrechnung auf den Reset-Zeitpunkt, auf 100 % gekappt.
    /// nil, wenn kein Reset bekannt ist, die Spanne zu kurz ist oder die
    /// Auslastung nicht steigt (Leerlauf braucht keine Prognose).
    func projection(to reset: Date?) -> Double? {
        guard let reset,
              let first = samples.first, let last = samples.last,
              reset > last.at else { return nil }
        let span = last.at.timeIntervalSince(first.at)
        guard span >= Self.minimumSpan else { return nil }
        let rate = (last.percent - first.percent) / span // %-Punkte pro Sekunde
        guard rate > 0 else { return nil }
        return min(last.percent + rate * reset.timeIntervalSince(last.at), 100)
    }
}
