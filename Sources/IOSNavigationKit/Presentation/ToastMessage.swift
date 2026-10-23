import Foundation

/// Design-free content for an application-rendered toast.
public struct ToastMessage<Kind: Sendable>: Identifiable, Sendable {
    public let id = UUID()
    public let message: String
    public let kind: Kind
    /// Seconds from `showToast`. Nil, nonpositive, or nonfinite values persist until dismissed.
    public let duration: TimeInterval?
    /// Suggested distance in points from the scene's bottom edge; the app decides how to apply it.
    public let bottomPadding: CGFloat

    public init(
        _ message: String,
        kind: Kind,
        duration: TimeInterval? = 3,
        bottomPadding: CGFloat = 50
    ) {
        self.message = message
        self.kind = kind
        self.duration = duration
        self.bottomPadding = bottomPadding
    }
}
