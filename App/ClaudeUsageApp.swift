import SwiftUI

@main
struct ClaudeUsageApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // Die App läuft als Hintergrund-Agent (LSUIElement); das Fenster wird
        // vom AppDelegate verwaltet, damit Login-Item-Starts unsichtbar bleiben.
        Settings { EmptyView() }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let state = AppState()
    private var window: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        state.start()
        // Onboarding nur beim allerersten Start automatisch zeigen — sonst
        // poppt das Fenster bei jedem Login erneut auf, wenn jemand es ohne
        // „Fertig" geschlossen hat. Manuelles Öffnen geht jederzeit (Reopen).
        let didAutoShow = UserDefaults.standard.bool(forKey: "didAutoShowOnboarding")
        if !state.onboardingCompleted && !didAutoShow {
            UserDefaults.standard.set(true, forKey: "didAutoShowOnboarding")
            showWindow()
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showWindow()
        return true
    }

    func showWindow() {
        if window == nil {
            let hosting = NSHostingController(rootView: RootView().environmentObject(state))
            let w = NSWindow(contentViewController: hosting)
            w.title = "Claude Usage"
            w.styleMask = [.titled, .closable, .miniaturizable]
            w.setContentSize(NSSize(width: 540, height: 600))
            w.isReleasedWhenClosed = false
            w.center()
            window = w
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}
