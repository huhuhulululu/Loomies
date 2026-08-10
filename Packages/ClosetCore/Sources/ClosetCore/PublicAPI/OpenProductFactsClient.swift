import Foundation

/// Product metadata from public Open*Facts catalogs (no API key).
/// - Open Product Facts: general goods / some apparel accessories
/// - Open Beauty Facts: personal care (often co-stored with wardrobe care)
/// - Open Food Facts: only if others miss (food-adjacent packaging OCR noise)
public protocol ProductLookupProviding: Sendable {
    func lookup(barcode: String) async throws -> PublicProductHit?
}

public struct PublicProductHit: Equatable, Sendable {
    public var barcode: String
    public var name: String?
    public var brand: String?
    public var quantity: String?
    public var categories: String?
    public var source: String

    public init(
        barcode: String,
        name: String? = nil,
        brand: String? = nil,
        quantity: String? = nil,
        categories: String? = nil,
        source: String
    ) {
        self.barcode = barcode
        self.name = name
        self.brand = brand
        self.quantity = quantity
        self.categories = categories
        self.source = source
    }

    /// Suggested closet item name: "Brand Name" or name or brand.
    public var suggestedItemName: String? {
        let b = brand?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let n = name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !b.isEmpty, !n.isEmpty { return "\(b) \(n)" }
        if !n.isEmpty { return n }
        if !b.isEmpty { return b }
        return nil
    }
}

/// HTTPS client for world.openproductsfacts.org / openbeautyfacts.org / openfoodfacts.org.
public struct OpenProductFactsClient: ProductLookupProviding, Sendable {
    public var transport: any PublicAPITransport
    public var hosts: [String]

    public init(
        transport: any PublicAPITransport = URLSessionTransport(),
        hosts: [String] = [
            "world.openproductsfacts.org",
            "world.openbeautyfacts.org",
            "world.openfoodfacts.org",
        ]
    ) {
        self.transport = transport
        self.hosts = hosts
    }

    public func lookup(barcode: String) async throws -> PublicProductHit? {
        let code = Self.normalizeBarcode(barcode)
        guard !code.isEmpty else { return nil }
        var lastError: Error?
        var anyCleanResponse = false
        for host in hosts {
            do {
                if let hit = try await fetch(host: host, code: code) { return hit }
                anyCleanResponse = true
            } catch is CancellationError {
                // 取消不是「该 host 失败」——向上传播，不静默换 host。
                throw CancellationError()
            } catch {
                // 瞬态故障（网络/5xx/decode）：记录并尝试下一个目录 host。
                AppLog.notice("product lookup host \(host) failed (\(error)); trying next host", .data)
                lastError = error
            }
        }
        // 全部 host 都失败才抛错；任一 host 干净响应（含 404 miss）则按未命中处理。
        if !anyCleanResponse, let lastError { throw lastError }
        return nil
    }

    public static func normalizeBarcode(_ raw: String) -> String {
        raw.filter(\.isNumber)
    }

    private func fetch(host: String, code: String) async throws -> PublicProductHit? {
        guard let url = URL(string: "https://\(host)/api/v2/product/\(code).json") else {
            throw PublicAPIError.invalidURL
        }
        let data: Data
        do {
            data = try await transport.get(url: url)
        } catch PublicAPIError.httpStatus(404) {
            return nil
        } catch PublicAPIError.notFound {
            return nil
        }
        return try OpenProductFactsJSON.parse(data, barcode: code, source: host)
    }
}

public enum OpenProductFactsJSON {
    public static func parse(_ data: Data, barcode: String, source: String) throws -> PublicProductHit? {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw PublicAPIError.decodeFailed
        }
        let status = root["status"] as? Int ?? (root["status"] as? NSNumber)?.intValue
        // v2: status 1 = found; status 0 = not found
        if status == 0 { return nil }
        guard let product = root["product"] as? [String: Any] else {
            if status == 1 { throw PublicAPIError.decodeFailed }
            return nil
        }
        let name = (product["product_name"] as? String)
            ?? (product["product_name_en"] as? String)
        let brand = product["brands"] as? String
        let qty = product["quantity"] as? String
        let cats = product["categories"] as? String
        if name == nil && brand == nil { return nil }
        return PublicProductHit(
            barcode: barcode,
            name: name,
            brand: brand,
            quantity: qty,
            categories: cats,
            source: source)
    }
}
