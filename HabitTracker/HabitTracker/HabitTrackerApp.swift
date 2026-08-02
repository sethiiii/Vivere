import SwiftUI
import CoreData

@main
struct HabitTrackerApp: App {
    @StateObject private var persistence = PersistenceController.shared
    @AppStorage("appearance") private var appearance = "system"
    @AppStorage("onboarding.completed") private var onboardingCompleted = false
    private let isUITesting = ProcessInfo.processInfo.arguments.contains("-ui-testing")

    init() {
        if ProcessInfo.processInfo.arguments.contains("-ui-testing-gallery") {
            UserDefaults.standard.set(true, forKey: "feature.gallery")
        }
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if persistence.isReady {
                    ContentView()
                } else if let message = persistence.loadErrorMessage {
                    StorageUnavailableView(message: message, retry: persistence.retryLoading)
                } else {
                    ProgressView("Opening your private data…")
                        .controlSize(.large)
                }
            }
                .environment(\.managedObjectContext,
                              persistence.container.viewContext)
                .preferredColorScheme(
                    appearance == "light" ? .light :
                    appearance == "dark"  ? .dark  : nil
                )
                .fullScreenCover(isPresented: Binding(
                    get: { persistence.isReady && !onboardingCompleted && !isUITesting },
                    set: { if !$0 { onboardingCompleted = true } }
                )) {
                    OnboardingView(isComplete: $onboardingCompleted)
                }
                .alert("Your Data Needs Attention", isPresented: Binding(
                    get: { persistence.isReady && persistence.loadErrorMessage != nil },
                    set: { if !$0 { persistence.dismissLoadError() } }
                )) {
                    Button("OK") { persistence.dismissLoadError() }
                } message: {
                    Text(persistence.loadErrorMessage ?? "HabitTracker couldn’t finish preparing older records.")
                }
                .task(id: persistence.isReady) {
                    guard persistence.isReady else { return }
                    WidgetSnapshotService.refresh(from: persistence.container.viewContext)
                }
                .onReceive(NotificationCenter.default.publisher(
                    for: .NSManagedObjectContextDidSave,
                    object: persistence.container.viewContext
                )) { _ in
                    WidgetSnapshotService.refresh(from: persistence.container.viewContext)
                }
        }
    }
}

private struct StorageUnavailableView: View {
    let message: String
    let retry: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label("Your Data Is Protected", systemImage: "externaldrive.badge.exclamationmark")
        } description: {
            Text("HabitTracker couldn’t safely open its local database, so editing is paused to prevent data loss.\n\n\(message)")
        } actions: {
            Button("Try Again", action: retry)
                .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}
