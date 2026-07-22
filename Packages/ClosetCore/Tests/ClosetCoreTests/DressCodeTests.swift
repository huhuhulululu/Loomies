import Testing
@testable import ClosetCore

struct DressCodeTests {

    @Test func galaExpectsFormal() {
        #expect(DressCode.expectedFormality(.gala).contains(.formal))
        #expect(!DressCode.expectedFormality(.gala).contains(.veryCasual))
    }

    @Test func casualExpectsLow() {
        #expect(DressCode.expectedFormality(.casual).contains(.casual))
        #expect(!DressCode.expectedFormality(.casual).contains(.formal))
    }

    @Test func businessFormalRejectsUnderdressed() {
        #expect(!DressCode.fits(itemFormality: .veryCasual, occasion: .businessFormal))
        #expect(DressCode.fits(itemFormality: .business, occasion: .businessFormal))
    }

    @Test func businessCasualBand() {
        #expect(DressCode.fits(itemFormality: .smart, occasion: .businessCasual))
        #expect(DressCode.fits(itemFormality: .business, occasion: .businessCasual))
        #expect(!DressCode.fits(itemFormality: .veryCasual, occasion: .businessCasual))
    }

    @Test func formalityLevelOrdering() {
        #expect(FormalityLevel.veryCasual < FormalityLevel.formal)
        #expect(FormalityLevel.business > FormalityLevel.smart)
    }

    @Test func outfitFormalityIsMostCasualPiece() {
        // 正式 blazer(.formal) + 休闲鞋(.casual) → 整体读作 .casual
        #expect(DressCode.outfitFormality([.formal, .business, .casual]) == .casual)
    }

    @Test func outfitFormalityNilWhenEmpty() {
        #expect(DressCode.outfitFormality([]) == nil)
    }

    @Test func outfitFitsByOverallFormality() {
        // 一套里有休闲鞋把整体拉到 .casual → 不契合 business formal
        #expect(!DressCode.outfitFits([.formal, .casual], occasion: .businessFormal))
        // 全 business 级 → 契合 business formal
        #expect(DressCode.outfitFits([.business, .business], occasion: .businessFormal))
    }
}
