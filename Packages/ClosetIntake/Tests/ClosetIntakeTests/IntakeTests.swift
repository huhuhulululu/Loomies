import Testing
import SwiftData
import Foundation
@testable import ClosetIntake
import ClosetModel
import ClosetCore

@MainActor
struct IntakeTests {

    func makeContext() throws -> ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Person.self, Wardrobe.self, StorageLocation.self, Item.self,
            Outfit.self, WearRecord.self, CalendarPlan.self, PersonBodyProfile.self,
            configurations: config)
        return ModelContext(container)
    }

    func makeVM(_ tags: ItemTags, ocr: LabelInfo? = nil) -> IntakeViewModel {
        IntakeViewModel(
            matting: MockMattingService(),
            tagging: MockTaggingService(tags: tags),
            ocr: ocr.map { MockOCRService(info: $0) })
    }

    @Test func processBuildsDraftFromTags() async throws {
        let vm = makeVM(ItemTags(slot: .dress, color: GarmentColor(hueDegrees: 200, isNeutral: false),
                                 occasions: ["work"], warmth: .medium))
        await vm.process(Data([0x1, 0x2]))
        #expect(vm.draft?.slot == .dress)
        #expect(vm.draft?.color?.hueDegrees == 200)
        #expect(vm.draft?.occasions == ["work"])
        #expect(vm.draft?.warmth == .medium)
        #expect(vm.mattedImage != nil)
        #expect(vm.draft?.name == "Dress") // slot display title prefill
        #expect(vm.canConfirm)
        #expect(vm.lastError == nil)
    }

    @Test func processWithOCRFillsBrandSize() async throws {
        let vm = makeVM(ItemTags(slot: .top), ocr: LabelInfo(brand: "Sézane", size: "M", material: "wool"))
        await vm.process(Data([0x1]))
        #expect(vm.draft?.brand == "Sézane")
        #expect(vm.draft?.size == "M")
        #expect(vm.draft?.name == "Sézane Top")
    }

    @Test func processRejectsEmptyImage() async throws {
        let vm = makeVM(ItemTags(slot: .top))
        await vm.process(Data())
        #expect(vm.draft == nil)
        #expect(vm.mattedImage == nil)
        #expect(vm.lastError != nil)
        #expect(vm.canConfirm == false)
    }

    @Test func confirmCreatesAvailableItemInWardrobe() async throws {
        let ctx = try makeContext()
        let w = Wardrobe(name: "A"); ctx.insert(w); try ctx.save()
        let vm = makeVM(ItemTags(slot: .bottom, occasions: ["work"], warmth: .light))
        await vm.process(Data([0x1, 0x2, 0x3, 0x4]))
        vm.draft?.name = "grey trousers"
        let item = vm.confirm(into: w, context: ctx)
        #expect(item != nil)
        #expect(item?.name == "grey trousers")
        #expect(item?.slotRaw == "bottom")
        #expect(item?.statusRaw == "available")
        #expect(item?.wardrobe?.id == w.id)
        #expect(vm.draft == nil)   // 确认后清空
        #expect(item?.localImageRelativePath != nil)
        #expect(ItemImageStore.loadData(relativePath: item?.localImageRelativePath) != nil)
        #expect(try ctx.fetch(FetchDescriptor<Item>()).count == 1)
        ItemImageStore.delete(relativePath: item?.localImageRelativePath)
    }

    @Test func confirmWithoutDraftReturnsNil() async throws {
        let ctx = try makeContext()
        let w = Wardrobe(name: "A"); ctx.insert(w); try ctx.save()
        let vm = makeVM(ItemTags(slot: .top))
        #expect(vm.confirm(into: w, context: ctx) == nil)   // 无草稿
        #expect(vm.lastError != nil)
    }

    @Test func confirmRejectsBlankName() async throws {
        let ctx = try makeContext()
        let w = Wardrobe(name: "A"); ctx.insert(w); try ctx.save()
        let vm = makeVM(ItemTags(slot: .top))
        await vm.process(Data([0x1]))
        vm.draft?.name = "   "
        #expect(vm.canConfirm == false)
        #expect(vm.confirm(into: w, context: ctx) == nil)
        #expect(vm.lastError != nil)
        #expect(vm.draft != nil) // keep draft so user can fix name
        #expect(try ctx.fetch(FetchDescriptor<Item>()).isEmpty)
    }

    @Test func suggestedNameUsesBrandAndSlot() {
        var d = IntakeDraft(slot: .outerwear)
        d.brand = "Toteme"
        #expect(IntakeViewModel.suggestedName(for: d) == "Toteme Outerwear")
        d.brand = nil
        #expect(IntakeViewModel.suggestedName(for: d) == "Outerwear")
    }
}
