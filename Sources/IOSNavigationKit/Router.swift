import Foundation
import Observation

public typealias UnifiedRouter<Route: Hashable> = Router<Route, Route, Route>
public typealias PreviewRouter = UnifiedRouter<Never>

@MainActor
public protocol Routable {
    associatedtype PushRoute: Hashable
    associatedtype SheetRoute: Hashable
    associatedtype FullScreenRoute: Hashable

    var path: [PushRoute] { get set }
    var sheet: SheetRoute? { get set }
    var fullScreenCover: FullScreenRoute? { get set }
    var alert: AlertPresentation? { get set }

    func push(_ route: PushRoute)
    func pop()
    func pop(_ count: Int)
    func popToRoot()
    func presentSheet(_ route: SheetRoute)
    func presentFullScreenCover(_ route: FullScreenRoute)
    func present(_ alert: AlertPresentation)
    func dismiss()
    func dismissAllPresentations()
}

@MainActor
@Observable
public final class Router<PushRoute: Hashable, SheetRoute: Hashable, FullScreenRoute: Hashable>: Routable {

    public var path: [PushRoute]
    public var sheet: SheetRoute?
    public var fullScreenCover: FullScreenRoute?
    public var alert: AlertPresentation?
    public var toast: ToastData?

    public init(
        path: [PushRoute] = [],
        sheet: SheetRoute? = nil,
        fullScreenCover: FullScreenRoute? = nil,
        alert: AlertPresentation? = nil
    ) {
        self.path = path
        self.sheet = sheet
        self.fullScreenCover = fullScreenCover
        self.alert = alert
    }

    public func push(_ route: PushRoute) {
        path.append(route)
    }

    public func pop() {
        guard !path.isEmpty else { return }
        path.removeLast()
    }

    public func pop(_ count: Int) {
        guard count > 0 else { return }
        let steps = min(count, path.count)
        guard steps > 0 else { return }
        path.removeLast(steps)
    }

    public func popToRoot() {
        path.removeAll()
    }

    public func presentSheet(_ route: SheetRoute) {
        sheet = route
    }

    public func dismiss() {
        if alert != nil {
            alert = nil
            return
        }

        if sheet != nil {
            sheet = nil
            return
        }

        if fullScreenCover != nil {
            fullScreenCover = nil
            return
        }
    }

    public func presentFullScreenCover(_ route: FullScreenRoute) {
        fullScreenCover = route
    }

    public func present(_ alert: AlertPresentation) {
        self.alert = alert
    }

    public func present(toast data: ToastData) {
        toast = data
    }

    public func dismissAllPresentations() {
        sheet = nil
        fullScreenCover = nil
        alert = nil
        toast = nil
    }
}

extension Router where PushRoute == Never, SheetRoute == Never, FullScreenRoute == Never {
    public static var previewValue: Self {
        .init()
    }
}
