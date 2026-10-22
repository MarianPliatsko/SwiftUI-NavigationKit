import Foundation
import Observation

/// Shared presentation state, independent of routers and visual rendering.
@MainActor
@Observable
public final class PresentationContext {
    public private(set) var toast: ToastMessage?
    public private(set) var alert: AlertRequest?

    @ObservationIgnored private var toastTask: Task<Void, Never>?
    @ObservationIgnored private var toastGeneration = UUID()
    @ObservationIgnored private let sleep: @MainActor (TimeInterval) async throws -> Void

    public convenience init() {
        self.init(sleep: { try await Task.sleep(for: .seconds($0)) })
    }

    // Injected internally so lifecycle tests do not depend on wall-clock delays.
    init(sleep: @escaping @MainActor (TimeInterval) async throws -> Void) {
        self.sleep = sleep
    }

    deinit { toastTask?.cancel() }

    /// Replaces only the toast, restarting its timer even when the same value is shown again.
    public func showToast(_ toast: ToastMessage) {
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
    public func dismissToast(id: ToastMessage.ID? = nil) {
        if let id, toast?.id != id { return }
        toastTask?.cancel()
        toastTask = nil
        toastGeneration = UUID()
        toast = nil
    }

    public func showAlert(_ alert: AlertRequest) {
        self.alert = alert
    }

    /// Dismissal never runs action handlers. An ID guards against stale UI callbacks.
    public func dismissAlert(id: AlertRequest.ID? = nil) {
        if let id, alert?.id != id { return }
        alert = nil
    }

    /// Runs an action only while its request is current, then dismisses only that request.
    /// A new alert installed synchronously by the handler is preserved.
    public func perform(_ action: AlertRequest.Action, for request: AlertRequest) {
        guard alert?.id == request.id,
              request.actions.contains(where: { $0.id == action.id }) else { return }
        action.handler()
        dismissAlert(id: request.id)
    }
}
