import SwiftUI

/// Wählbare Akzentfarbe des Widgets. Die Wahl wird in der App getroffen und
/// im Snapshot mitgespeichert, den das Widget liest — bewusst KEINE
/// AppIntents-/Widget-Konfiguration, da deren System-Cache bei selbst
/// gebauten, ad-hoc-signierten Widgets und beim Config-Typ-Wechsel unzuverlässig
/// ist (kein unterstützter Static→AppIntent-In-Place-Migrationspfad).
///
/// Eine Farbe färbt ALLE Elemente einheitlich (Gauges + Balken) — bewusst keine
/// Ampel-Logik mehr, die Gauges und Balken unterschiedlich einfärben würde.
enum WidgetAccent: String, Codable, CaseIterable, Identifiable {
    case cyan, blue, purple, magenta, green, orange, graphite

    /// Default + Fallback für unbekannte/ältere Werte (z. B. das frühere "auto").
    static let `default`: WidgetAccent = .cyan

    static func from(_ raw: String?) -> WidgetAccent {
        raw.flatMap(WidgetAccent.init(rawValue:)) ?? .default
    }

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .cyan: return "Cyan · gaind.ai"
        case .blue: return "Blue · gaind.ai"
        case .purple: return "Purple · gaind.ai"
        case .magenta: return "Magenta · gaind.ai"
        case .green: return "Green"
        case .orange: return "Orange"
        case .graphite: return "Graphite"
        }
    }

    /// gaind-Markenfarbe (aus dem Signet-Gradient)?
    var isBrandColor: Bool {
        switch self {
        case .cyan, .blue, .purple, .magenta: return true
        default: return false
        }
    }

    /// Akzentfarbe — gilt einheitlich für Gauges und Balken.
    var color: Color {
        switch self {
        case .cyan: return Color(accentHex: 0x6EAAF0)    // gaind Cyan
        case .blue: return Color(accentHex: 0x0C4AB2)    // gaind Deep Blue
        case .purple: return Color(accentHex: 0x5748D4)  // gaind Lila
        case .magenta: return Color(accentHex: 0xA945F8) // gaind Magenta
        case .green: return .green
        case .orange: return .orange
        case .graphite: return Color(white: 0.6)
        }
    }
}

extension Color {
    init(accentHex hex: UInt32) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: 1)
    }
}
