import Testing
@testable import ClosetCore

struct OutfitAssemblerTests {
    let top = CandidateItem(id: "t1", slot: .top)
    let bottom = CandidateItem(id: "b1", slot: .bottom)
    let shoes = CandidateItem(id: "sh", slot: .shoes)
    let coat = CandidateItem(id: "o1", slot: .outerwear, subtype: "coat")

    @Test func producesTopBottomShoes() {
        let out = OutfitAssembler.assemble(pool: [top, bottom, shoes], daytimeTempF: 75, maxOutfits: 3)
        #expect(out.count == 1)
        #expect(out[0].itemIDs == ["b1", "sh", "t1"])
    }

    @Test func addsOuterwearWhenCold() {
        let out = OutfitAssembler.assemble(pool: [top, bottom, shoes, coat], daytimeTempF: 50, maxOutfits: 3)
        #expect(out.count == 1)
        #expect(out[0].itemIDs.contains("o1"))
    }

    @Test func noOuterwearWhenWarm() {
        let out = OutfitAssembler.assemble(pool: [top, bottom, shoes, coat], daytimeTempF: 75, maxOutfits: 3)
        #expect(out.count == 1)
        #expect(!out[0].itemIDs.contains("o1"))
    }

    @Test func dressCombo() {
        let dress = CandidateItem(id: "d1", slot: .dress)
        let out = OutfitAssembler.assemble(pool: [dress, shoes], daytimeTempF: 75, maxOutfits: 3)
        #expect(out.count == 1)
        #expect(out[0].itemIDs == ["d1", "sh"])
    }

    @Test func respectsMaxOutfits() {
        let pool = [
            CandidateItem(id: "t1", slot: .top), CandidateItem(id: "t2", slot: .top),
            CandidateItem(id: "b1", slot: .bottom), CandidateItem(id: "b2", slot: .bottom),
            shoes]
        // 2×2 = 4 组基底，maxOutfits=2 → 取 2
        #expect(OutfitAssembler.assemble(pool: pool, daytimeTempF: 75, maxOutfits: 2).count == 2)
    }

    @Test func enumeratesShoesAndOuterwearVariety() {
        // G4：鞋（及冷天外套）进入枚举叉积——2 双鞋都要出现在产出里。
        let pool = [
            top, bottom,
            CandidateItem(id: "sh1", slot: .shoes),
            CandidateItem(id: "sh2", slot: .shoes)]
        let out = OutfitAssembler.assemble(pool: pool, daytimeTempF: 75, maxOutfits: 10)
        let allIDs = Set(out.flatMap(\.itemIDs))
        #expect(allIDs.contains("sh1"))
        #expect(allIDs.contains("sh2"))

        let coldPool = pool + [
            CandidateItem(id: "o1", slot: .outerwear, subtype: "coat"),
            CandidateItem(id: "o2", slot: .outerwear, subtype: "coat")]
        let coldOut = OutfitAssembler.assemble(pool: coldPool, daytimeTempF: 50, maxOutfits: 20)
        let coldIDs = Set(coldOut.flatMap(\.itemIDs))
        #expect(coldIDs.contains("sh1"))
        #expect(coldIDs.contains("sh2"))
        #expect(coldIDs.contains("o1"))
        #expect(coldIDs.contains("o2"))
    }

    @Test func emptyWithoutShoes() {
        #expect(OutfitAssembler.assemble(pool: [top, bottom], daytimeTempF: 75, maxOutfits: 3).isEmpty)
    }

    @Test func allAssembledAreGrammarValid() {
        let pool = [top, bottom, shoes, coat, CandidateItem(id: "d1", slot: .dress)]
        let out = OutfitAssembler.assemble(pool: pool, daytimeTempF: 50, maxOutfits: 10)
        #expect(!out.isEmpty)
        for o in out { #expect(OutfitGrammar.isValid(o.items)) }
    }
}
