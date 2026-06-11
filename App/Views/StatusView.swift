import SwiftUI

/// Status window after onboarding: current values, settings and manual refresh.
struct StatusView: View {
    @EnvironmentObject var state: AppState
    @State private var refreshing = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Claude Usage").font(.title2.bold())
                Spacer()
                if let last = state.lastRefresh {
                    Text("Updated \(last.formatted(date: .omitted, time: .shortened))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Button {
                    refreshing = true
                    Task {
                        await state.refresh(force: true)
                        refreshing = false
                    }
                } label: {
                    if refreshing {
                        ProgressView().controlSize(.small)
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                }
                .disabled(refreshing)
            }

            if let rl = state.snapshot?.rateLimits {
                GroupBox("Limits") {
                    HStack(spacing: 28) {
                        Metric(label: "5-hour window", value: Format.percent(rl.fiveHourPercent))
                        Metric(label: "Week", value: Format.percent(rl.sevenDayPercent))
                        if let opus = rl.sevenDayOpusPercent {
                            Metric(label: "Opus/week", value: Format.percent(opus))
                        }
                        if rl.extraUsageEnabled, let extra = rl.extraUsagePercent {
                            Metric(label: "Extra usage", value: Format.percent(extra))
                        }
                        Spacer()
                    }
                    .padding(.vertical, 4)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else if state.rateLimitsEnabled, let error = state.rateLimitError {
                GroupBox("Limits") {
                    Text(error).font(.caption).foregroundStyle(.orange)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            if let local = state.snapshot?.local {
                GroupBox("Local (from session logs)") {
                    HStack(spacing: 24) {
                        Metric(label: "Tokens today", value: Format.tokens(local.today?.tokens ?? 0))
                        Metric(label: "Tokens 7 days", value: Format.tokens(local.weekTokens))
                        Metric(label: "Tokens 30 days", value: Format.tokens(local.monthTokens))
                        Metric(label: "Messages today", value: "\(local.today?.messageCount ?? 0)")
                        Metric(label: "Sessions today", value: "\(local.today?.sessionCount ?? 0)")
                        Spacer()
                    }
                    .padding(.vertical, 4)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            GroupBox("Settings") {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Widget accent color")
                        Spacer()
                        Picker("", selection: Binding(
                            get: { state.accent },
                            set: { state.setAccent($0) }
                        )) {
                            ForEach(WidgetAccent.allCases) { accent in
                                Text(accent.displayName).tag(accent)
                            }
                        }
                        .labelsHidden()
                        .frame(maxWidth: 220)
                    }
                    HStack(spacing: 4) {
                        Text("Brand palette by")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Link("gaind.ai", destination: URL(string: "https://gaind.ai")!)
                            .font(.caption2)
                    }
                    Toggle("Launch at login", isOn: Binding(
                        get: { state.loginItemEnabled },
                        set: { state.setLoginItem($0) }
                    ))
                    Toggle("Fetch session/weekly limits (keychain)", isOn: Binding(
                        get: { state.rateLimitsEnabled },
                        set: { enabled in
                            if enabled {
                                Task { await state.connectRateLimits() }
                            } else {
                                state.disconnectRateLimits()
                            }
                        }
                    ))
                    Button("Show onboarding again") {
                        state.onboardingCompleted = false
                    }
                    .buttonStyle(.link)
                }
                .padding(.vertical, 4)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Spacer()

            VStack(alignment: .leading, spacing: 4) {
                Text("Read-only on ~/.claude · token stays in the keychain · only network call: api.anthropic.com")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                HStack(spacing: 4) {
                    Text("Made by")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Link("gaind.ai", destination: URL(string: "https://gaind.ai")!)
                        .font(.caption2)
                    Text("·")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Link("Julian Hermes", destination: URL(string: "https://www.linkedin.com/in/julianhermes")!)
                        .font(.caption2)
                }
            }
        }
        .padding(20)
        .frame(minWidth: 540, minHeight: 480)
    }
}
