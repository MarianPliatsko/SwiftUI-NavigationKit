/// Modal identity is the complete route value, including associated payloads.
/// Equal routes retain equal identity across binding reads.
public struct PresentedRoute<Route: Hashable>: Identifiable {
    public let route: Route
    public var id: Route { route }

    public init(route: Route) {
        self.route = route
    }
}
