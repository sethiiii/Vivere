import Combine
import Foundation
import WatchConnectivity
import WatchKit

struct WatchHabit: Codable, Equatable, Identifiable {
    let id: UUID
    let name: String
    let iconName: String
    let tintHex: String
    var isComplete: Bool
}

struct WatchHabitSnapshot: Codable, Equatable {
    var generatedAt: Date
    var completedCount: Int
    var totalCount: Int
    var habits: [WatchHabit]

    static let empty = WatchHabitSnapshot(generatedAt: .now, completedCount: 0, totalCount: 0, habits: [])

    func toggling(_ id: UUID) -> WatchHabitSnapshot {
        var copy = self
        guard let index = copy.habits.firstIndex(where: { $0.id == id }) else { return copy }
        copy.habits[index].isComplete.toggle()
        copy.completedCount = copy.habits.lazy.filter(\.isComplete).count
        copy.totalCount = copy.habits.count
        copy.generatedAt = .now
        return copy
    }
}

@MainActor
final class WatchHabitStore: NSObject, ObservableObject, WCSessionDelegate {
    @Published private(set) var snapshot: WatchHabitSnapshot
    @Published private(set) var isReachable = false
    @Published private(set) var pendingHabitIDs: Set<UUID> = []

    private let cacheKey = "watch.today.snapshot.v1"

    var progress: Double {
        guard snapshot.totalCount > 0 else { return 0 }
        return Double(snapshot.completedCount) / Double(snapshot.totalCount)
    }

    override init() {
        if
            let data = UserDefaults.standard.data(forKey: cacheKey),
            let cached = try? JSONDecoder().decode(WatchHabitSnapshot.self, from: data)
        {
            snapshot = cached
        } else {
            snapshot = .empty
        }
        super.init()
        activate()
    }

    func toggle(_ habit: WatchHabit) {
        let previous = snapshot
        snapshot = snapshot.toggling(habit.id)
        pendingHabitIDs.insert(habit.id)
        persist()
        let isNowComplete = snapshot.habits.first(where: { $0.id == habit.id })?.isComplete == true
        WKInterfaceDevice.current().play(isNowComplete ? .success : .click)

        guard WCSession.isSupported() else {
            snapshot = previous
            pendingHabitIDs.remove(habit.id)
            return
        }
        let session = WCSession.default
        let request: [String: Any] = [
            "toggleHabitID": habit.id.uuidString,
            "requestID": UUID().uuidString
        ]
        if session.isReachable {
            session.sendMessage(request, replyHandler: nil) { _ in
                WCSession.default.transferUserInfo(request)
            }
        } else {
            session.transferUserInfo(request)
        }
    }

    private func activate() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
    }

    private func requestSnapshot() {
        let session = WCSession.default
        isReachable = session.isReachable
        if session.isReachable {
            session.sendMessage(["requestSnapshot": true], replyHandler: nil)
        }
    }

    private func receive(_ data: Data) {
        guard let incoming = try? JSONDecoder().decode(WatchHabitSnapshot.self, from: data) else { return }
        snapshot = incoming
        pendingHabitIDs.removeAll()
        persist()
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        UserDefaults.standard.set(data, forKey: cacheKey)
    }

    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        Task { @MainActor [weak self] in
            guard activationState == .activated else { return }
            self?.requestSnapshot()
            if let data = session.receivedApplicationContext["todaySnapshot"] as? Data {
                self?.receive(data)
            }
        }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor [weak self] in self?.requestSnapshot() }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        guard let data = applicationContext["todaySnapshot"] as? Data else { return }
        Task { @MainActor [weak self] in self?.receive(data) }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        guard let data = message["todaySnapshot"] as? Data else { return }
        Task { @MainActor [weak self] in self?.receive(data) }
    }
}

extension WatchHabitStore {
    static var preview: WatchHabitStore {
        let store = WatchHabitStore()
        store.snapshot = WatchHabitSnapshot(
            generatedAt: .now,
            completedCount: 1,
            totalCount: 3,
            habits: [
                WatchHabit(id: UUID(), name: "Morning walk", iconName: "figure.walk", tintHex: "#4E7BD9", isComplete: true),
                WatchHabit(id: UUID(), name: "Read", iconName: "book.fill", tintHex: "#7A62C9", isComplete: false),
                WatchHabit(id: UUID(), name: "Drink water", iconName: "drop.fill", tintHex: "#2D9CDB", isComplete: false)
            ]
        )
        return store
    }
}
