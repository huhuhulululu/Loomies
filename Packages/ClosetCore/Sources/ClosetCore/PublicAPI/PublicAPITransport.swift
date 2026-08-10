import Foundation

/// Minimal GET transport so providers stay testable without live network.
public protocol PublicAPITransport: Sendable {
    func get(url: URL) async throws -> Data
}

public enum PublicAPIError: Error, Equatable, Sendable {
    case invalidURL
    case httpStatus(Int)
    case emptyResponse
    case decodeFailed
    case notFound
    case unavailable
}

/// Production transport (Foundation `URLSession` — works in macOS package tests when online).
public struct URLSessionTransport: PublicAPITransport {
    public var session: URLSession
    public var userAgent: String

    public init(
        session: URLSession = .shared,
        userAgent: String = "LoomiesCloset/0.1 (public-api; +https://github.com/)"
    ) {
        self.session = session
        self.userAgent = userAgent
    }

    public func get(url: URL) async throws -> Data {
        var req = URLRequest(url: url)
        req.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        req.timeoutInterval = 12
        let (data, response) = try await session.data(for: req)
        if let http = response as? HTTPURLResponse {
            guard (200...299).contains(http.statusCode) else {
                throw PublicAPIError.httpStatus(http.statusCode)
            }
        }
        guard !data.isEmpty else { throw PublicAPIError.emptyResponse }
        return data
    }
}

/// In-memory map for unit tests (exact URL absoluteString → body).
public struct FixtureTransport: PublicAPITransport {
    public var fixtures: [String: Data]
    public init(fixtures: [String: Data] = [:]) { self.fixtures = fixtures }

    public func get(url: URL) async throws -> Data {
        let s = url.absoluteString
        if let data = fixtures[s] { return data }
        // Substring keys: "geocoding-api.open-meteo.com", "api.open-meteo.com", …
        // Prefer the **longest** match so nested hosts don't collide
        // (`api.open-meteo.com` ⊂ `geocoding-api.open-meteo.com`).
        // (长度, 键名) 双键决胜：等长 key 同时命中时不得随 Dictionary hash 序串台
        let hit = fixtures
            .filter { s.contains($0.key) }
            .max(by: { ($0.key.count, $0.key) < ($1.key.count, $1.key) })
        if let data = hit?.value { return data }
        throw PublicAPIError.notFound
    }
}
