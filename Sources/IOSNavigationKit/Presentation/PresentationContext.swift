import Foundation
import Observation

/// Shared presentation state, independent of routers and visual rendering.
@MainActor
@Observable
public final class PresentationContext {
    public private(set) var alert: AlertRequest?

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
