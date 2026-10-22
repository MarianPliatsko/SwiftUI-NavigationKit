import IOSNavigationKit
import SwiftUI

// All colors, fonts, layout, interaction, and accessibility are demo-owned.
@MainActor
struct ToastView: View {
    let toast: ToastMessage
    @Environment(\.presentationContext) private var presentation

    var body: some View {
        Button {
            presentation.dismissToast(id: toast.id)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.mint)
                Text(toast.message).multilineTextAlignment(.leading)
                Image(systemName: "xmark").font(.caption.bold())
            }
            .font(.callout.weight(.medium))
            .foregroundStyle(.white)
            .padding(18)
            .background(Color.indigo.gradient, in: .rect(cornerRadius: 18))
            .shadow(color: .black.opacity(0.15), radius: 16, y: 6)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(toast.message)
        .accessibilityHint("Dismisses this toast")
        .accessibilityIdentifier("demo.toast")
    }
}

@MainActor
struct AlertView: View {
    let alert: AlertRequest
    @Environment(\.presentationContext) private var presentation
    @AccessibilityFocusState private var titleIsFocused: Bool

    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .accessibilityHidden(true)
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Image(systemName: "bubble.left.and.bubble.right.fill")
                        .font(.title)
                        .foregroundStyle(.indigo)
                        .accessibilityHidden(true)
                    Text(alert.title)
                        .font(.title2.bold())
                        .accessibilityAddTraits(.isHeader)
                        .accessibilityFocused($titleIsFocused)
                    if let message = alert.message {
                        Text(message).foregroundStyle(.secondary)
                    }
                    ForEach(alert.actions) { action in
                        Button(action.title, role: action.role) {
                            presentation.perform(action, for: alert)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                    }
                    if alert.actions.isEmpty {
                        Button("Close") { presentation.dismissAlert(id: alert.id) }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(24)
            }
            .background(Color(uiColor: .systemBackground), in: .rect(cornerRadius: 24))
            .frame(maxWidth: 440, maxHeight: 450)
            .padding(24)
            .accessibilityElement(children: .contain)
            .accessibilityAddTraits(.isModal)
            .accessibilityIdentifier("demo.alert")
        }
        .onAppear { titleIsFocused = true }
    }
}
