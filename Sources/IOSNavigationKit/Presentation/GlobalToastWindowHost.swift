#if os(iOS)
import SwiftUI
import UIKit

@MainActor
struct GlobalToastWindowHost: UIViewControllerRepresentable {
    let context: PresentationContext
    let toastContent: @MainActor (ToastMessage) -> AnyView

    func makeUIViewController(context: Context) -> GlobalToastWindowController {
        GlobalToastWindowController(presentationContext: self.context, toastContent: toastContent)
    }

    func updateUIViewController(_ controller: GlobalToastWindowController, context: Context) {
        controller.update(presentationContext: self.context, toastContent: toastContent)
    }

    static func dismantleUIViewController(_ controller: GlobalToastWindowController, coordinator: ()) {
        controller.removeToastWindow()
    }
}

@MainActor
final class GlobalToastWindowController: UIViewController {
    private var presentationContext: PresentationContext
    private var toastContent: @MainActor (ToastMessage) -> AnyView
    private var toastWindow: PassthroughToastWindow?
    private var hostingController: UIHostingController<GlobalToastOverlay>?

    init(
        presentationContext: PresentationContext,
        toastContent: @escaping @MainActor (ToastMessage) -> AnyView
    ) {
        self.presentationContext = presentationContext
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
        presentationContext: PresentationContext,
        toastContent: @escaping @MainActor (ToastMessage) -> AnyView
    ) {
        self.presentationContext = presentationContext
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

    private func makeRootView() -> GlobalToastOverlay {
        GlobalToastOverlay(
            context: presentationContext,
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
private struct GlobalToastOverlay: View {
    @Bindable var context: PresentationContext
    let toastContent: @MainActor (ToastMessage) -> AnyView
    let onInteractiveFrameChange: @MainActor (CGRect) -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            if let toast = context.toast {
                toastContent(toast)
                    .environment(\.installedPresentationContext, context)
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
        .ignoresSafeArea()
    }
}

private struct ToastInteractiveFramePreferenceKey: PreferenceKey {
    static let defaultValue: CGRect = .null

    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        value = nextValue()
    }
}
#endif
