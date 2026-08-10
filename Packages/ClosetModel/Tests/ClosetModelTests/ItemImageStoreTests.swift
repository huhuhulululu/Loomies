import Testing
import Foundation
@testable import ClosetModel

// .serialized：共享 ItemImageStore.rootDirectory 真盘目录，须与其他触盘套件互斥。
@Suite(.serialized) struct ItemImageStoreTests {

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
