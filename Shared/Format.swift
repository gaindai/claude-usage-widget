import Foundation

enum Format {
    static func tokens(_ n: Int) -> String {
        let d = Double(n)
        switch d {
        case 1_000_000_000...: return String(format: "%.1fB", d / 1_000_000_000)
        case 1_000_000...: return String(format: "%.1fM", d / 1_000_000)
        case 1_000...: return String(format: "%.0fK", d / 1_000)
        default: return "\(n)"
        }
    }

    static func percent(_ v: Double) -> String {
        String(format: "%.0f %%", v)
    }
}
