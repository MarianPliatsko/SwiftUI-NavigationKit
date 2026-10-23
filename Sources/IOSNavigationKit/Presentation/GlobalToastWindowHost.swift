#if os(iOS)
import SwiftUI
import UIKit

@MainActor
struct GlobalToastWindowHost<Kind: Sendable>: UIViewControllerRepresentable {
    let toastStore: ToastStore<Kind>
    let toastContent: @MainActor (ToastMessage<Kind>) -> AnyView

    func makeUIViewController(context: Context) -> GlobalToastWindowController<Kind> {
        GlobalToastWindowController(toastStore: toastStore, toastContent: toastContent)
    }

    func updateUIViewController(_ controller: GlobalToastWindowController<Kind>, context: Context) {
        controller.update(toastStore: toastStore, toastContent: toastContent)
    }

    static func dismantleUIViewController(_ controller: GlobalToastWindowController<Kind>, coordinator: ()) {
        controller.removeToastWindow()
    }
}

@MainActor
final class GlobalToastWindowController<Kind: Sendable>: UIViewController {
    private var toastStore: ToastStore<Kind>
    private var toastContent: @MainActor (ToastMessage<Kind>) -> AnyView
    private var toastWindow: PassthroughToastWindow?
    private var hostingController: UIHostingController<GlobalToastOverlay<Kind>>?

    init(
        toastStore: ToastStore<Kind>,
        toastContent: @escaping @MainActor (ToastMessage<Kind>) -> AnyView
    ) {
        self.toastStore = toastStore
        self.toastContent = toastContent
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        configureWindowIfNeeded()
    }

    func update(
        toastStore: ToastStore<Kind>,
        toastContent: @escaping @MainActor (ToastMessage<Kind>) -> AnyView
    ) {
        self.toastStore = toastStore
        self.toastContent = toastContent
        updateRootView()
        configureWindowIfNeeded()
    }

    func removeToastWindow() {
        toastWindow?.isHidden = true
        toastWindow?.rootViewController = nil
        toastWindow = nil
        hostingController = nil
    }

    private func configureWindowIfNeeded() {
        guard toastWindow == nil, let scene = view.window?.windowScene else { return }

        let window = PassthroughToastWindow(windowScene: scene)
        window.frame = scene.coordinateSpace.bounds
        window.windowLevel = .normal + 1
        window.backgroundColor = .clear
        window.isOpaque = false
        let host = UIHostingController(
            rootView: makeRootView()
        )
        host.view.backgroundColor = .clear
        host.view.frame = window.bounds
        window.rootViewController = host
        toastWindow = window
        hostingController = host
        window.isHidden = false
    }

    private func updateRootView() {
        hostingController?.rootView = makeRootView()
    }

    private func makeRootView() -> GlobalToastOverlay<Kind> {
        GlobalToastOverlay(
            toastStore: toastStore,
            toastContent: toastContent
        ) { [weak self] frame in
            self?.toastWindow?.interactiveFrame = frame.isNull ? nil : frame
        }
    }
}

private final class PassthroughToastWindow: UIWindow {
    var interactiveFrame: CGRect?

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard interactiveFrame?.contains(point) == true,
              isUserInteractionEnabled,
              let hitView = super.hitTest(point, with: event)
        else {
            return nil
        }

        return hitView
    }
}

@MainActor
private struct GlobalToastOverlay<Kind: Sendable>: View {
    @Bindable var toastStore: ToastStore<Kind>
    let toastContent: @MainActor (ToastMessage<Kind>) -> AnyView
    let onInteractiveFrameChange: @MainActor (CGRect) -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            if let toast = toastStore.toast {
                toastContent(toast)
                    .environment(toastStore)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: 540)
                    .padding(.horizontal, 20)
                    .padding(.bottom, toast.bottomPadding)
                    .background {
                        GeometryReader { toastGeometry in
                            Color.clear.preference(
                                key: ToastInteractiveFramePreferenceKey.self,
                                value: toastGeometry.frame(in: .named("toast-window"))
                            )
                        }
                    }
                    .id(toast.id)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .coordinateSpace(name: "toast-window")
        .onPreferenceChange(ToastInteractiveFramePreferenceKey.self, perform: onInteractiveFrameChange)
    }
}

private struct ToastInteractiveFramePreferenceKey: PreferenceKey {
    static let defaultValue: CGRect = .null

    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        value = nextValue()
    }
}
#endif
