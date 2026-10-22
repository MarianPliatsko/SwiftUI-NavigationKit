import SwiftUI

/// Alert content supplied by the application. At most three actions are retained.
@MainActor
public struct AlertPresentation: Identifiable {
    @MainActor
    public struct Action: Identifiable {
        public let id = UUID()
        public let title: String
        public let role: ButtonRole?
        public let handler: (@MainActor () -> Void)?

        public init(title: String, role: ButtonRole? = nil, handler: (@MainActor () -> Void)? = nil) {
            self.title = title
            self.role = role
            self.handler = handler
        }

        public static func `default`(_ title: String, handler: (@MainActor () -> Void)? = nil) -> Self {
            .init(title: title, handler: handler)
        }

        public static func cancel(_ title: String, handler: (@MainActor () -> Void)? = nil) -> Self {
            .init(title: title, role: .cancel, handler: handler)
        }

        public static func destructive(_ title: String, handler: (@MainActor () -> Void)? = nil) -> Self {
            .init(title: title, role: .destructive, handler: handler)
        }
    }

    public let id = UUID()
    public let title: String
    public let message: String?
    public let actions: [Action]

    public init(title: String, message: String? = nil, actions: [Action] = []) {
        self.title = title
        self.message = message
        self.actions = Array(actions.prefix(3))
    }
}

@MainActor
struct NavigationAlertModifier: ViewModifier {
    @Binding var presentation: AlertPresentation?

    func body(content: Content) -> some View {
        content.alert(
            presentation?.title ?? "",
            isPresented: Binding(
                get: { presentation != nil },
                set: { if !$0 { presentation = nil } }
            ),
            presenting: presentation
        ) { alert in
            if alert.actions.isEmpty {
                Button("OK", role: .cancel) { presentation = nil }
            } else {
                ForEach(alert.actions) { action in
                    Button(action.title, role: action.role) {
                        // Preserve reference ordering, including clearing a synchronous replacement.
                        action.handler?()
                        presentation = nil
                    }
                }
            }
        } message: { alert in
            if let message = alert.message { Text(message) }
        }
    }
}
