import CoreData
import Foundation
import WatchConnectivity

private struct WatchSnapshot: Codable {
    let generatedAt: Date
    let completedCount: Int
    let totalCount: Int
    let habits: [WatchHabitItem]
}

private struct WatchHabitItem: Codable {
    let id: UUID
    let name: String
    let iconName: String
    let tintHex: String
    let isComplete: Bool
}

/// Bridges a compact Today snapshot to Apple Watch while Core Data remains
/// exclusively owned by the iPhone app.
@MainActor
final class WatchSyncService: NSObject, WCSessionDelegate {
    static let shared = WatchSyncService()

    private weak var context: NSManagedObjectContext?
    private let processedRequestKey = "watch.processedCompletionRequests.v1"
    private var isStarted = false

    private override init() {
        super.init()
    }

    func start(with context: NSManagedObjectContext) {
        self.context = context
        guard WCSession.isSupported() else { return }

        let session = WCSession.default
        if !isStarted {
            session.delegate = self
            session.activate()
            isStarted = true
        }
        refresh(from: context)
    }

    func refresh(from context: NSManagedObjectContext) {
        self.context = context
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        guard session.activationState == .activated, session.isPaired, session.isWatchAppInstalled else { return }

        do {
            let data = try JSONEncoder().encode(makeSnapshot(from: context))
            let payload: [String: Any] = ["todaySnapshot": data]
            try session.updateApplicationContext(payload)
            if session.isReachable {
                session.sendMessage(payload, replyHandler: nil)
            }
        } catch {
            // Companion sync must never block the iPhone app or its persistence.
        }
    }

    private func makeSnapshot(from context: NSManagedObjectContext, now: Date = .now) throws -> WatchSnapshot {
        let request: NSFetchRequest<Habit> = Habit.fetchRequest()
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \Habit.sortOrder, ascending: true),
            NSSortDescriptor(keyPath: \Habit.name, ascending: true)
        ]
        request.predicate = NSPredicate(format: "isArchived == NO AND isPaused == NO")
        let habits = try context.fetch(request).filter { $0.isScheduled(on: now) }
        let items = habits.compactMap { habit -> WatchHabitItem? in
            guard let id = habit.id else { return nil }
            return WatchHabitItem(
                id: id,
                name: habit.displayName,
                iconName: habit.displayIcon,
                tintHex: habit.tintHex ?? "#5B7CFA",
                isComplete: habit.isComplete(on: now)
            )
        }
        return WatchSnapshot(
            generatedAt: now,
            completedCount: items.lazy.filter(\.isComplete).count,
            totalCount: items.count,
            habits: items
        )
    }

    private func handleCompletionRequest(habitID: String, requestID: String) {
        guard !hasProcessed(requestID), let uuid = UUID(uuidString: habitID), let context else { return }

        let request: NSFetchRequest<Habit> = Habit.fetchRequest()
        request.fetchLimit = 1
        request.predicate = NSPredicate(format: "id == %@", uuid as CVarArg)
        guard let habit = try? context.fetch(request).first else { return }

        do {
            if habit.isComplete(on: .now) {
                _ = try HabitStore.toggleCompletion(for: habit, in: context)
            } else {
                switch habit.goal {
                case .count, .duration:
                    _ = try HabitStore.recordCompletion(
                        for: habit,
                        value: Double(max(1, habit.targetCount)),
                        note: "Completed from Apple Watch",
                        in: context
                    )
                case .checkIn, .avoidance:
                    _ = try HabitStore.toggleCompletion(for: habit, in: context)
                }
            }
            rememberProcessed(requestID)
            refresh(from: context)
        } catch {
            context.rollback()
        }
    }

    private func hasProcessed(_ requestID: String) -> Bool {
        Set(UserDefaults.standard.stringArray(forKey: processedRequestKey) ?? []).contains(requestID)
    }

    private func rememberProcessed(_ requestID: String) {
        var identifiers = UserDefaults.standard.stringArray(forKey: processedRequestKey) ?? []
        identifiers.append(requestID)
        UserDefaults.standard.set(Array(identifiers.suffix(100)), forKey: processedRequestKey)
    }

    private func receive(_ message: [String: Any]) {
        if message["requestSnapshot"] as? Bool == true, let context {
            refresh(from: context)
            return
        }
        guard
            let habitID = message["toggleHabitID"] as? String,
            let requestID = message["requestID"] as? String
        else { return }
        handleCompletionRequest(habitID: habitID, requestID: requestID)
    }

    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        Task { @MainActor [weak self] in
            guard activationState == .activated, let self, let context = self.context else { return }
            self.refresh(from: context)
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        Task { @MainActor [weak self] in self?.receive(message) }
    }

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        Task { @MainActor [weak self] in self?.receive(userInfo) }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }
}
