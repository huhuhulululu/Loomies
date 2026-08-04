import Testing
@testable import ClosetUI

@Suite("AvatarBackdrop")
struct AvatarBackdropTests {
    @Test func resolvesKnownOccasions() {
        #expect(AvatarBackdrop.resolved(from: "work") == .work)
        #expect(AvatarBackdrop.resolved(from: "Work") == .work)
        #expect(AvatarBackdrop.resolved(from: "date") == .date)
        #expect(AvatarBackdrop.resolved(from: "gala") == .gala)
        #expect(AvatarBackdrop.resolved(from: "casual") == .casual)
        #expect(AvatarBackdrop.resolved(from: "office") == .work)
        #expect(AvatarBackdrop.resolved(from: "party") == .gala)
    }

    @Test func unknownOrEmptyFallsBackToStudio() {
        #expect(AvatarBackdrop.resolved(from: nil) == .studio)
        #expect(AvatarBackdrop.resolved(from: "") == .studio)
        #expect(AvatarBackdrop.resolved(from: "  ") == .studio)
        #expect(AvatarBackdrop.resolved(from: "unknown_scene") == .studio)
    }

    @Test func rawValueAliases() {
        #expect(AvatarBackdrop.resolved(from: "studio") == .studio)
        #expect(AvatarBackdrop.resolved(from: "studio") == AvatarBackdrop(rawValue: "studio"))
    }

    @Test func allCasesStable() {
        let names = AvatarBackdrop.allCases.map(\.rawValue)
        #expect(names.contains("studio"))
        #expect(names.contains("work"))
        #expect(names.contains("date"))
        #expect(names.contains("gala"))
        #expect(names.contains("casual"))
        #expect(Set(names).count == names.count)
    }
}
