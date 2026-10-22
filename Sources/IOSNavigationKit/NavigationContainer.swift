import SwiftUI

#if os(iOS)

@MainActor
public struct NavigationContainer<
    PushRoute: Hashable,
    SheetRoute: Hashable,
    FullScreenRoute: Hashable,
    Root: View,
    PushDestination: View,
    SheetDestination: View,
    FullScreenDestination: View
>: View {

    public var router: Router<PushRoute, SheetRoute, FullScreenRoute>
    private let root: Root
    private let destination: (PushRoute) -> PushDestination
    private let sheetDestination: (SheetRoute) -> SheetDestination
    private let fullScreenDestination: (FullScreenRoute) -> FullScreenDestination

    public init(
        router: Router<PushRoute, SheetRoute, FullScreenRoute>,
        @ViewBuilder root: () -> Root,
        @ViewBuilder destination: @escaping (PushRoute) -> PushDestination,
        @ViewBuilder sheetDestination: @escaping (SheetRoute) -> SheetDestination,
        @ViewBuilder fullScreenDestination: @escaping (FullScreenRoute) -> FullScreenDestination
    ) {
        self.router = router
        self.root = root()
        self.destination = destination
        self.sheetDestination = sheetDestination
        self.fullScreenDestination = fullScreenDestination
    }

    public var body: some View {
        @Bindable var router = router

        NavigationStack(path: $router.path) {
            root
                .navigationDestination(for: PushRoute.self) { route in
                    destination(route)
                }
        }
        .sheet(item: sheetBinding(for: router)) { presentation in
            sheetDestination(presentation.route)
                .modifier(PresentationHostModifier())
        }
        .fullScreenCover(item: fullScreenCoverBinding(for: router)) { presentation in
            fullScreenDestination(presentation.route)
                .modifier(PresentationHostModifier())
        }
        .modifier(PresentationHostModifier())
        .modifier(NavigationToastModifier(toast: $router.toast))
        .modifier(NavigationAlertModifier(presentation: $router.alert))
    }

    private func sheetBinding(
        for router: Router<PushRoute, SheetRoute, FullScreenRoute>
    ) -> Binding<PresentedRoute<SheetRoute>?> {
        Binding(
            get: {
                router.sheet.map(PresentedRoute.init(route:))
            },
            set: { presentation in
                router.sheet = presentation?.route
            }
        )
    }

    private func fullScreenCoverBinding(
        for router: Router<PushRoute, SheetRoute, FullScreenRoute>
    ) -> Binding<PresentedRoute<FullScreenRoute>?> {
        Binding(
            get: {
                router.fullScreenCover.map(PresentedRoute.init(route:))
            },
            set: { presentation in
                router.fullScreenCover = presentation?.route
            }
        )
    }
}

private func emptyDestination<Route>(_ route: Route) -> EmptyView {
    EmptyView()
}

extension NavigationContainer where PushRoute == SheetRoute, SheetRoute == FullScreenRoute {
    public init(
        router: Router<PushRoute, SheetRoute, FullScreenRoute>,
        @ViewBuilder root: () -> Root,
        @ViewBuilder destination: @escaping (PushRoute) -> PushDestination
    ) where SheetDestination == PushDestination, FullScreenDestination == PushDestination {
        self.init(
            router: router,
            root: root,
            destination: destination,
            sheetDestination: destination,
            fullScreenDestination: destination
        )
    }
}

extension NavigationContainer where PushRoute == Never, PushDestination == EmptyView {
    public init(
        router: Router<PushRoute, SheetRoute, FullScreenRoute>,
        @ViewBuilder root: () -> Root,
        @ViewBuilder sheetDestination: @escaping (SheetRoute) -> SheetDestination,
        @ViewBuilder fullScreenDestination: @escaping (FullScreenRoute) -> FullScreenDestination
    ) {
        self.init(
            router: router,
            root: root,
            destination: emptyDestination,
            sheetDestination: sheetDestination,
            fullScreenDestination: fullScreenDestination
        )
    }
}

extension NavigationContainer where SheetRoute == Never, SheetDestination == EmptyView {
    public init(
        router: Router<PushRoute, SheetRoute, FullScreenRoute>,
        @ViewBuilder root: () -> Root,
        @ViewBuilder destination: @escaping (PushRoute) -> PushDestination,
        @ViewBuilder fullScreenDestination: @escaping (FullScreenRoute) -> FullScreenDestination
    ) {
        self.init(
            router: router,
            root: root,
            destination: destination,
            sheetDestination: emptyDestination,
            fullScreenDestination: fullScreenDestination
        )
    }
}

extension NavigationContainer where FullScreenRoute == Never, FullScreenDestination == EmptyView {
    public init(
        router: Router<PushRoute, SheetRoute, FullScreenRoute>,
        @ViewBuilder root: () -> Root,
        @ViewBuilder destination: @escaping (PushRoute) -> PushDestination,
        @ViewBuilder sheetDestination: @escaping (SheetRoute) -> SheetDestination
    ) {
        self.init(
            router: router,
            root: root,
            destination: destination,
            sheetDestination: sheetDestination,
            fullScreenDestination: emptyDestination
        )
    }
}

extension NavigationContainer where PushRoute == Never, SheetRoute == Never, PushDestination == EmptyView, SheetDestination == EmptyView {
    public init(
        router: Router<PushRoute, SheetRoute, FullScreenRoute>,
        @ViewBuilder root: () -> Root,
        @ViewBuilder fullScreenDestination: @escaping (FullScreenRoute) -> FullScreenDestination
    ) {
        self.init(
            router: router,
            root: root,
            destination: emptyDestination,
            sheetDestination: emptyDestination,
            fullScreenDestination: fullScreenDestination
        )
    }
}

extension NavigationContainer where PushRoute == Never, FullScreenRoute == Never, PushDestination == EmptyView, FullScreenDestination == EmptyView {
    public init(
        router: Router<PushRoute, SheetRoute, FullScreenRoute>,
        @ViewBuilder root: () -> Root,
        @ViewBuilder sheetDestination: @escaping (SheetRoute) -> SheetDestination
    ) {
        self.init(
            router: router,
            root: root,
            destination: emptyDestination,
            sheetDestination: sheetDestination,
            fullScreenDestination: emptyDestination
        )
    }
}

extension NavigationContainer where SheetRoute == Never, FullScreenRoute == Never, SheetDestination == EmptyView, FullScreenDestination == EmptyView {
    public init(
        router: Router<PushRoute, SheetRoute, FullScreenRoute>,
        @ViewBuilder root: () -> Root,
        @ViewBuilder destination: @escaping (PushRoute) -> PushDestination
    ) {
        self.init(
            router: router,
            root: root,
            destination: destination,
            sheetDestination: emptyDestination,
            fullScreenDestination: emptyDestination
        )
    }
}

extension NavigationContainer where PushRoute == Never, SheetRoute == Never, FullScreenRoute == Never, PushDestination == EmptyView, SheetDestination == EmptyView, FullScreenDestination == EmptyView {
    public init(
        router: Router<PushRoute, SheetRoute, FullScreenRoute>,
        @ViewBuilder root: () -> Root
    ) {
        self.init(
            router: router,
            root: root,
            destination: emptyDestination,
            sheetDestination: emptyDestination,
            fullScreenDestination: emptyDestination
        )
    }
}

#endif
