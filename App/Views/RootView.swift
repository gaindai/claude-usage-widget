import SwiftUI

struct RootView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        if state.onboardingCompleted {
            StatusView()
        } else {
            OnboardingView()
        }
    }
}
