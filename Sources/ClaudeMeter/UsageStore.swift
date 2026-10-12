import Foundation
import SwiftUI

@MainActor
final class UsageStore: ObservableObject {
    @Published private(set) var snapshot: UsageSnapshot?
    @Published private(set) var error: String?
    @Published private(set) var isLoading = false

    @Published var refreshMinutes: Double = UserDefaults.standard.object(forKey: "refreshMinutes") as? Double ?? 2 {
        didSet {
            UserDefaults.standard.set(refreshMinutes, forKey: "refreshMinutes")
            schedule()
        }
    }

    private let client = UsageClient()
    private var timer: Timer?
    private var backoffUntil: Date?

    init() {
        schedule()
        Task { await refresh() }
    }

    func schedule() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: max(60, refreshMinutes * 60), repeats: true) { [weak self] _ in
            Task { @MainActor in await self?.refresh() }
        }
    }

    /// `force` bypasses the soft throttle used when the menu is opened.
    func refresh(force: Bool = true) async {
        if isLoading { return }
        if let until = backoffUntil, Date() < until { return }
        if !force, let last = snapshot?.fetchedAt, Date().timeIntervalSince(last) < 20 { return }

        isLoading = true
        defer { isLoading = false }
        do {
            snapshot = try await client.fetch()
            error = nil
            backoffUntil = nil
        } catch UsageError.rateLimited(let retry) {
            backoffUntil = Date().addingTimeInterval(retry ?? 300)
            error = UsageError.rateLimited(retryAfter: retry).localizedDescription
        } catch {
            self.error = error.localizedDescription
        }
    }
}
