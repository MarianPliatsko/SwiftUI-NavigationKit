import SwiftUI

/// Application-rendered alert content. Unlike legacy `AlertPresentation`, actions are not truncated.
@MainActor
public struct AlertRequest: Identifiable {
    public struct Action: Identifiable {
        public let id = UUID()
        public let title: String
        public let role: ButtonRole?
        public let handler: @MainActor () -> Void

        public init(title: String, role: ButtonRole? = nil, handler: @escaping @MainActor () -> Void = {}) {
            self.title = title
            self.role = role
            self.handler = handler
        }
    }

    public let id = UUID()
    public let title: String
    public let message: String?
    public let actions: [Action]

    public init(title: String, message: String? = nil, actions: [Action] = []) {
        self.title = title
        self.message = message
        self.actions = actions
    }
}
