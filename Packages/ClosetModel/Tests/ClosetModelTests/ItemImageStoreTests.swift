import Testing
import Foundation
@testable import ClosetModel

// .serialized：进程内共享 ItemImageStore 根目录，须与其他触盘套件互斥。
// 根目录已按进程隔离（ItemImageTestRoot.install → ITEM_IMAGE_ROOT 临时目录）。
@Suite(.serialized) struct ItemImageStoreTests {

    init() { ItemImageTestRoot.install() }

    @Test func saveLoadRoundTrip() {
        let id = UUID()
        let payload = Data([0xFF, 0xD8, 0xFF, 0x01, 0x02, 0x03])
        let rel = ItemImageStore.save(data: payload, for: id, ext: "jpg")
        #expect(rel != nil)
        #expect(rel!.contains(id.uuidString))
        let loaded = ItemImageStore.loadData(relativePath: rel)
        #expect(loaded == payload)
        ItemImageStore.delete(relativePath: rel)
        #expect(ItemImageStore.loadData(relativePath: rel) == nil)
    }

    @Test func absoluteURLNilWhenEmpty() {
        #expect(ItemImageStore.absoluteURL(relativePath: nil) == nil)
        #expect(ItemImageStore.absoluteURL(relativePath: "") == nil)
    }
}
