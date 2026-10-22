import SwiftUI

/// Toast state retained for compatibility with the reference router.
/// Equality deliberately excludes background and leading content.
public struct ToastData: Hashable {
    public enum TrailingContent {
        case loadingIndicator
    }

    public let leadingContent: TrailingContent?
    public let content: String
    public let background: Color
    public let duration: TimeInterval?
    public let bottomPadding: CGFloat

    public init(
        leadingContent: TrailingContent? = nil,
        content: String,
        background: Color,
        duration: TimeInterval? = 3.0,
        bottomPadding: CGFloat = 50
    ) {
        self.leadingContent = leadingContent
        self.content = content
        self.background = background
        self.duration = duration
        self.bottomPadding = bottomPadding
    }

    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.content == rhs.content && lhs.duration == rhs.duration && lhs.bottomPadding == rhs.bottomPadding
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(content)
        hasher.combine(duration)
        hasher.combine(bottomPadding)
    }
}
