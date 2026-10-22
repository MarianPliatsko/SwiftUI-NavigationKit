import Foundation
@testable import IOSNavigationKit
import Testing

@MainActor
struct PresentationSurfacesTests {
    @Test func deepestSurfaceRendersAndParentResumesAfterDismissal() {
        let surfaces = PresentationSurfaces()
        let root = UUID()
        let stackB = UUID()
        let nestedSheet = UUID()

        surfaces.appear(id: root, depth: 0)
        #expect(surfaces.activeID == root)

        surfaces.appear(id: stackB, depth: 1)
        #expect(surfaces.activeID == stackB)

        surfaces.appear(id: nestedSheet, depth: 2)
        #expect(surfaces.activeID == nestedSheet)

        surfaces.disappear(id: nestedSheet)
        #expect(surfaces.activeID == stackB)

        surfaces.disappear(id: stackB)
        #expect(surfaces.activeID == root)
    }
}
