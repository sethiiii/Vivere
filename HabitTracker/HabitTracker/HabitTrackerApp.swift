import SwiftUI

@main
struct HabitTrackerApp: App {
    @StateObject private var persistence = PersistenceController.shared
    @AppStorage("appearance") private var appearance = "system"
    @AppStorage("onboarding.completed") private var onboardingCompleted = false

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext,
                              persistence.container.viewContext)
                // Apply theme here, on the root view
                .preferredColorScheme(
                    appearance == "light" ? .light :
                    appearance == "dark"  ? .dark  : nil
                )
                .fullScreenCover(isPresented: Binding(
                    get: { !onboardingCompleted },
                    set: { if !$0 { onboardingCompleted = true } }
                )) {
                    OnboardingView(isComplete: $onboardingCompleted)
                }
                .alert(
                    "Unable to Open Your Data",
                    isPresented: Binding(
                        get: { persistence.loadErrorMessage != nil },
                        set: { if !$0 { persistence.dismissLoadError() } }
                    )
                ) {
                    Button("OK", role: .cancel) { persistence.dismissLoadError() }
                } message: {
                    Text(persistence.loadErrorMessage ?? "An unknown storage error occurred.")
                }
        }
    }
}
