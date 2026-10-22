import SwiftUI

@MainActor
struct NavigationToastModifier: ViewModifier {
    @Binding var toast: ToastData?
    @State private var workItem: DispatchWorkItem?
    @State private var bottomPadding: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .frame(maxWidth: .infinity)
            .overlay {
                VStack {
                    Spacer()
                    if let toast {
                        HStack(spacing: toast.leadingContent != nil ? 10 : 0) {
                            if let leading = toast.leadingContent {
                                switch leading {
                                case .loadingIndicator: ProgressView()
                                }
                            }
                            Text(toast.content)
                                .font(.caption.bold())
                                .foregroundStyle(.primary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(toast.background, in: RoundedRectangle(cornerRadius: 8))
                    }
                }
                .padding(.bottom, toast != nil ? bottomPadding : bottomPadding / 2)
                .allowsHitTesting(false)
            }
            .simultaneousGesture(
                DragGesture(minimumDistance: 0).onChanged { _ in toast = nil },
                // An idle whole-stack drag can consume native Back taps on iOS 26.
                // Keep descendant gestures active when there is no toast to dismiss.
                including: toast == nil ? .subviews : .all
            )
            .animation(.smooth, value: toast)
            .onChange(of: toast, initial: true) { _, value in
                bottomPadding = value?.bottomPadding ?? 20
                scheduleDismissal()
            }
    }

    private func scheduleDismissal() {
        workItem?.cancel()
        workItem = nil
        guard let duration = toast?.duration, duration > 0 else { return }
        let item = DispatchWorkItem {
            // DispatchQueue.main executes this callback on the main actor's executor.
            MainActor.assumeIsolated {
                toast = nil
                workItem?.cancel()
                workItem = nil
            }
        }
        workItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + duration, execute: item)
    }
}
