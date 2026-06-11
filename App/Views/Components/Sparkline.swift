import SwiftUI
import Charts

/// 7-Tage-Token-Trend als weiche Area+Line mit hervorgehobenem Heute-Punkt.
/// Nur im App-Target (Swift Charts) — das Widget behält seine abhängigkeitsfreien
/// DayBars. Mit `showsAxes` bekommt die Linie eine Wochentags-Achse (Zeitraum)
/// und eine dezente Token-Skala links (Maßstab) — beide rendert Swift Charts
/// intern, daher exakt zur Plotfläche ausgerichtet.
struct Sparkline: View {
    let days: [UsageSnapshot.DayStat]
    let accent: WidgetAccent
    var height: CGFloat = 44
    var showsAxes = false

    var body: some View {
        let points = Array(days.enumerated())
        let maxTokens = max(days.map(\.tokens).max() ?? 1, 1)
        Chart {
            ForEach(points, id: \.offset) { idx, day in
                AreaMark(
                    x: .value("Day", idx),
                    y: .value("Tokens", day.tokens)
                )
                .interpolationMethod(.monotone)
                .foregroundStyle(accent.areaStyle)

                LineMark(
                    x: .value("Day", idx),
                    y: .value("Tokens", day.tokens)
                )
                .interpolationMethod(.monotone)
                .foregroundStyle(accent.lineColor)
                .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))

                if idx == points.count - 1 {
                    PointMark(
                        x: .value("Day", idx),
                        y: .value("Tokens", day.tokens)
                    )
                    .foregroundStyle(accent.lineColor)
                    .symbolSize(42)
                }
            }
        }
        // Headroom, damit der Heute-Punkt nicht oben anstößt.
        .chartYScale(domain: 0...Double(maxTokens) * 1.15)
        .chartXAxis {
            if showsAxes {
                AxisMarks(values: Array(0..<days.count)) { value in
                    AxisValueLabel {
                        if let idx = value.as(Int.self), idx >= 0, idx < days.count {
                            Text(idx == days.count - 1 ? "Today" : weekday(days[idx].date))
                                .font(.system(size: 9))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .chartYAxis {
            if showsAxes {
                AxisMarks(position: .leading, values: [0, maxTokens / 2, maxTokens]) { value in
                    AxisGridLine().foregroundStyle(Color.secondary.opacity(0.12))
                    AxisValueLabel {
                        if let v = value.as(Int.self) {
                            Text(Format.tokens(v))
                                .font(.system(size: 8))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .frame(height: height)
    }

    private func weekday(_ dateString: String) -> String {
        let parser = DateFormatter()
        parser.locale = Locale(identifier: "en_US_POSIX")
        parser.dateFormat = "yyyy-MM-dd"
        guard let date = parser.date(from: dateString) else { return "" }
        let out = DateFormatter()
        out.dateFormat = "EE"
        return out.string(from: date)
    }
}
