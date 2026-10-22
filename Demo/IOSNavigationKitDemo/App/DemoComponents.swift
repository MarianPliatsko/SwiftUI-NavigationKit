import IOSNavigationKit
import SwiftUI

@MainActor
struct DemoPage<Content: View>: View {
    let title: String
    let subtitle: String
    let symbol: String
    @ViewBuilder let content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Image(systemName: symbol)
                    .font(.largeTitle)
                    .foregroundStyle(.indigo)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 8) {
                    Text(title).font(.largeTitle.bold()).accessibilityAddTraits(.isHeader)
                    Text(subtitle).foregroundStyle(.secondary)
                }
                content
            }
            .frame(maxWidth: 600, alignment: .leading)
            .padding(24)
            .frame(maxWidth: .infinity)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .buttonStyle(.bordered)
    }
}

@MainActor
struct DemoSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.headline).accessibilityAddTraits(.isHeader)
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: .rect(cornerRadius: 20))
    }
}

/// These controls intentionally read the environment inside feature screens.
@MainActor
struct PresentationActions: View {
    let source: String
    @Environment(\.presentationContext) private var presentation

    var body: some View {
        DemoSection("Shared presentations") {
            Button("Show 3-second toast") {
                presentation.showToast(.init("Hello from \(source)"))
            }
            Button("Show persistent toast") {
                presentation.showToast(.init("Saved from \(source) · tap to dismiss", duration: nil))
            }
            .accessibilityIdentifier("showPersistentToast.\(source)")
            Button("Show replacement alert demo", action: showReplacementAlert)
        }
    }

    private func showReplacementAlert() {
        presentation.showAlert(.init(
            title: "Continue from \(source)?",
            message: "Choose Continue to replace this alert with a new request.",
            actions: [
                .init(title: "Continue") {
                    presentation.showAlert(.init(
                        title: "Replacement alert",
                        message: "This alert survived the original action's dismissal. Requested from \(source).",
                        actions: [
                            .init(title: "Finish") {
                                presentation.showToast(.init("Completed from \(source)"))
                            },
                            .init(title: "Close", role: .cancel)
                        ]
                    ))
                },
                .init(title: "Cancel", role: .cancel)
            ]
        ))
    }
}
