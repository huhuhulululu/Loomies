import Testing
import SwiftData
import Foundation
@testable import ClosetUI
import ClosetModel
import ClosetCore

@MainActor
struct OnboardingViewModelTests {

    func makeContext() throws -> ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Person.self, Wardrobe.self, StorageLocation.self, Item.self,
            Outfit.self, WearRecord.self, CalendarPlan.self, PersonBodyProfile.self,
            configurations: config)
        return ModelContext(container)
    }

    @Test func cannotFinishWithoutNameAndCity() {
        let vm = OnboardingViewModel()
        #expect(!vm.canFinish)
        vm.displayName = "Alex"
        #expect(!vm.canFinish)
        vm.city = "New York"
        #expect(vm.canFinish)
    }

    @Test func finishCreatesPersonAndWardrobe() throws {
        let ctx = try makeContext()
        let vm = OnboardingViewModel()
        vm.displayName = "Alex"
        vm.city = "New York"
        #expect(vm.finish(in: ctx))
        #expect(vm.completed)
        #expect(vm.person?.name == "Alex")
        #expect(vm.wardrobe?.locationCity == "New York")
        #expect(vm.wardrobe?.owner?.id == vm.person?.id)
        #expect(vm.bodyProfile == nil)
        #expect(!vm.bodyShapeReady)
    }

    @Test func finishWithPartialBodyStillNoFFIT() throws {
        let ctx = try makeContext()
        let vm = OnboardingViewModel()
        vm.displayName = "Alex"; vm.city = "NYC"
        vm.bustInches = 36; vm.waistInches = 28  // incomplete
        #expect(vm.finish(in: ctx))
        #expect(vm.bodyProfile != nil)
        #expect(!vm.bodyShapeReady)
        #expect(vm.bodyShape == nil)
    }

    @Test func finishWithFullBodyActivatesFFIT() throws {
        let ctx = try makeContext()
        let vm = OnboardingViewModel()
        vm.displayName = "Alex"; vm.city = "NYC"
        vm.bustInches = 36; vm.waistInches = 26
        vm.hipInches = 36; vm.highHipInches = 34
        #expect(vm.finish(in: ctx))
        #expect(vm.bodyShapeReady)
        #expect(vm.bodyShape != nil)
    }

    @Test func finishWithVisualPickOnly() throws {
        let ctx = try makeContext()
        let vm = OnboardingViewModel()
        vm.displayName = "Alex"; vm.city = "NYC"
        vm.popularShapePick = .pear
        #expect(vm.finish(in: ctx))
        #expect(vm.bodyProfile != nil)
        #expect(!vm.bodyShapeReady)
        #expect(vm.hasBodyReference)
        #expect(vm.bodyProfile?.popularShapeOverrideRaw == PopularShape.pear.rawValue)
        #expect(vm.bodyShape == .triangle)
    }
}
