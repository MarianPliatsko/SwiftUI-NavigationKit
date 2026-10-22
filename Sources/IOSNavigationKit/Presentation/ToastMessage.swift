import Foundation

/// Design-free content for an application-rendered toast.
public struct ToastMessage: Identifiable, Sendable {
    public let id = UUID()
    public let message: String
    /// Seconds from `showToast`. Nil, nonpositive, or nonfinite values persist until dismissed.
    public let duration: TimeInterval?
    /// Distance in points from the bottom edge of the scene.
    public let bottomPadding: CGFloat

    public init(_ message: String, duration: TimeInterval? = 3, bottomPadding: CGFloat = 50) {
        self.message = message
        self.duration = duration
        self.bottomPadding = bottomPadding
    }
}
