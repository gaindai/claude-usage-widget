import SwiftUI

/// Guided first launch in three steps, each with a live checkmark:
/// 1. Local data found (works without any permission)
/// 2. Connect limits (keychain, skippable)
/// 3. Add widget + autostart
struct OnboardingView: View {
    @EnvironmentObject var state: AppState
    @State private var connecting = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Welcome to Claude Usage")
                    .font(.title.bold())
                Text("Three steps, then your desktop shows your Claude Code usage.")
                    .foregroundStyle(.secondary)
                HStack(spacing: 4) {
                    Text("by")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Link("gaind.ai", destination: URL(string: "https://gaind.ai")!)
                        .font(.caption)
                }
            }
            .padding(24)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    step1
                    step2
                    step3
                }
                .padding(24)
            }

            Divider()

            HStack {
                Text("Everything stays on your Mac — the only network call goes to api.anthropic.com.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Done") {
                    state.onboardingCompleted = true
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding(16)
        }
        .frame(minWidth: 540, minHeight: 580)
    }

    private var step1: some View {
        StepBox(done: state.localDataAvailable, title: "1 · Local data") {
            if state.localDataAvailable {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Found your Claude Code data — here's your week:")
                    if let local = state.snapshot?.local {
                        HStack(spacing: 24) {
                            Metric(label: "Tokens (7 days)", value: Format.tokens(local.weekTokens))
                            Metric(label: "Messages (7 days)", value: "\(local.weekMessages)")
                            Metric(label: "Sessions today", value: "\(local.today?.sessionCount ?? 0)")
                        }
                    } else {
                        ProgressView().controlSize(.small)
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text("No ~/.claude directory found. Is Claude Code installed on this Mac and has it run at least once?")
                        .foregroundStyle(.orange)
                    Button("Check again") {
                        Task { await state.refresh(force: true) }
                    }
                }
            }
        }
    }

    private var step2: some View {
        StepBox(done: state.keychainConnected, title: "2 · Connect limits (optional)") {
            VStack(alignment: .leading, spacing: 8) {
                Text("Shows your 5-hour window and weekly limit, just like `/usage`. To do that the app reads the Claude Code token from the keychain — it is only ever sent to api.anthropic.com for this request and never stored or logged.")
                    .fixedSize(horizontal: false, vertical: true)
                if state.keychainConnected, let rl = state.snapshot?.rateLimits {
                    HStack(spacing: 24) {
                        Metric(label: "5-hour window", value: Format.percent(rl.fiveHourPercent))
                        Metric(label: "Week", value: Format.percent(rl.sevenDayPercent))
                    }
                } else {
                    HStack(spacing: 12) {
                        Button {
                            connecting = true
                            Task {
                                await state.connectRateLimits()
                                connecting = false
                            }
                        } label: {
                            if connecting {
                                ProgressView().controlSize(.small)
                            } else {
                                Text("Connect — choose “Always Allow” in the dialog")
                            }
                        }
                        .disabled(connecting)
                    }
                    if let error = state.rateLimitError {
                        Text(error).font(.caption).foregroundStyle(.orange)
                    }
                    Text("Skipping is fine — the widget then shows local data only.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var step3: some View {
        StepBox(done: state.loginItemEnabled, title: "3 · Add widget & autostart") {
            VStack(alignment: .leading, spacing: 8) {
                Text("Right-click the desktop → “Edit Widgets” → search for **Claude Usage** → pick a size and place it.")
                    .fixedSize(horizontal: false, vertical: true)
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
                    .frame(maxWidth: 200)
                }
                Toggle("Launch at login (recommended — keeps the widget current)",
                       isOn: Binding(
                        get: { state.loginItemEnabled },
                        set: { state.setLoginItem($0) }
                       ))
                if state.loginItemNeedsApproval {
                    HStack(spacing: 8) {
                        Text("macOS needs your approval under Login Items.")
                            .font(.caption)
                            .foregroundStyle(.orange)
                        Button("Open System Settings") {
                            LoginItemManager.openSystemSettings()
                        }
                        .controlSize(.small)
                    }
                }
            }
        }
    }
}

private struct StepBox<Content: View>: View {
    let done: Bool
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: done ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(done ? .green : .secondary)
                    .imageScale(.large)
                Text(title).font(.headline)
            }
            content
                .padding(.leading, 28)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 10))
    }
}

struct Metric: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(.title3.bold().monospacedDigit())
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
    }
}
