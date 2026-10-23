import Foundation
import Observation

/// Typed shared toast state for an application's semantic toast kinds.
@MainActor
@Observable
public final class ToastStore<Kind: Sendable> {
    public private(set) var toast: ToastMessage<Kind>?

    @ObservationIgnored private var toastTask: Task<Void, Never>?
    @ObservationIgnored private var toastGeneration = UUID()
    @ObservationIgnored private let sleep: @MainActor (TimeInterval) async throws -> Void

    public convenience init() {
        self.init(sleep: { try await Task.sleep(for: .seconds($0)) })
    }

    init(sleep: @escaping @MainActor (TimeInterval) async throws -> Void) {
        self.sleep = sleep
    }

    deinit { toastTask?.cancel() }

    /// Replaces the current toast and restarts its timer.
    public func showToast(_ toast: ToastMessage<Kind>) {
        dismissToast()
        self.toast = toast
        guard let duration = toast.duration, duration.isFinite, duration > 0 else { return }
        let generation = toastGeneration
        let sleep = sleep
        toastTask = Task { [weak self] in
            do { try await sleep(duration) }
            catch { return }
            guard !Task.isCancelled, let self, self.toastGeneration == generation else { return }
            self.dismissToast()
        }
    }

    /// An ID guards against a stale view dismissing a replacement toast.
    public func dismissToast(id: ToastMessage<Kind>.ID? = nil) {
        if let id, toast?.id != id { return }
        toastTask?.cancel()
        toastTask = nil
        toastGeneration = UUID()
        toast = nil
    }
}
