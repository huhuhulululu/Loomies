import Foundation

/// Public-domain **reference** apparel size bridges (US market first).
/// Not brand-true sizing — vanity sizing means labels are not interchangeable.
/// Use for UX hints / intake autocomplete only; fit decisions stay on measurements (research/07).
public enum PublicSizeReference: Sendable {

    public enum ApparelKind: String, Sendable, CaseIterable {
        case womensTop, womensBottom, mensTop, mensBottom, unisexAlpha
    }

    /// US numeric dress/waist → approximate EU / UK labels (common e-commerce tables).
    public static func womensNumericBridge(us: Int) -> (eu: Int, uk: Int)? {
        // Rough RTW bridge used by many US retailers (not ISO certified).
        let table: [Int: (Int, Int)] = [
            0: (30, 4), 2: (32, 6), 4: (34, 8), 6: (36, 10),
            8: (38, 12), 10: (40, 14), 12: (42, 16), 14: (44, 18),
            16: (46, 20), 18: (48, 22),
        ]
        return table[us]
    }

    /// Alpha S/M/L… → rough US women’s numeric midpoint (display only).
    public static func alphaToUSWomensMidpoint(_ alpha: String) -> Int? {
        switch alpha.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() {
        case "XXS": return 0
        case "XS": return 2
        case "S": return 4
        case "M": return 8
        case "L": return 12
        case "XL": return 16
        case "XXL", "2XL": return 18
        default: return nil
        }
    }

    /// Men’s US chest (in) rough band → alpha (public chart style).
    public static func mensChestInchesToAlpha(_ chestIn: Double) -> String? {
        switch chestIn {
        case ..<35: return "XS"
        case 35..<38: return "S"
        case 38..<41: return "M"
        case 41..<44: return "L"
        case 44..<48: return "XL"
        case 48..<52: return "XXL"
        default: return chestIn >= 52 ? "3XL" : nil
        }
    }

    /// Parse a raw size label into system + token for display hints.
    public static func parseLabel(_ raw: String) -> (system: SizeSystem, token: String)? {
        let t = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return nil }
        let upper = t.uppercased()
        if upper.hasPrefix("EU") || upper.hasPrefix("EUR") {
            return (.eu, t)
        }
        if upper.hasPrefix("UK") {
            return (.uk, t)
        }
        if upper.hasPrefix("US") || upper.hasPrefix("USA") {
            return (.us, t)
        }
        if ["XXS", "XS", "S", "M", "L", "XL", "XXL", "2XL", "3XL"].contains(upper) {
            return (.intl, upper)
        }
        if Int(t) != nil {
            return (.us, t) // default US market assumption
        }
        return (.intl, t)
    }

    /// Gate Open*Facts `quantity` → garment size: accept S/M/L / US 8 / EU 38; reject pack/weight strings.
    public static func looksLikeApparelSize(_ raw: String) -> Bool {
        let t = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty, t.count <= 16 else { return false }
        let lower = t.lowercased()
        // Pack / mass / volume — common OFF quantity values, not clothing size.
        let rejectFragments = [
            "pack", "pcs", "pc ", "pieces", "piece", "ct ", "count",
            "ml", "cl ", "liter", "litre", "fl oz", "oz", "lb", "kg",
            "gram", "grams", "mg",
        ]
        if rejectFragments.contains(where: { lower.contains($0) }) { return false }
        // "500g", "12 g"
        if lower.range(of: #"\d\s*g\b"#, options: .regularExpression) != nil { return false }

        let upper = t.uppercased()
        if ["XXS", "XS", "S", "M", "L", "XL", "XXL", "2XL", "3XL", "ONE SIZE", "ONESIZE", "OS"]
            .contains(upper) { return true }
        if upper.hasPrefix("EU") || upper.hasPrefix("EUR")
            || upper.hasPrefix("UK") || upper.hasPrefix("US") || upper.hasPrefix("USA") {
            return upper.rangeOfCharacter(from: .decimalDigits) != nil || upper.count <= 6
        }
        // Bare numeric dress/waist (US default market).
        if Int(t) != nil { return true }
        // "US 8", "EU38" already covered by prefix; "W32" / "32W" common jeans.
        if upper.range(of: #"^W?\d{1,3}W?$"#, options: .regularExpression) != nil { return true }
        return false
    }

    /// One-line human hint for Me / intake (never claims true fit).
    public static func displayHint(forLabel raw: String) -> String? {
        guard let parsed = parseLabel(raw) else { return nil }
        if parsed.system == .intl,
           let us = alphaToUSWomensMidpoint(parsed.token),
           let bridge = womensNumericBridge(us: us) {
            return "Ref. chart ≈ US \(us) / EU \(bridge.eu) / UK \(bridge.uk) (not brand-true)"
        }
        if parsed.system == .us, let n = Int(parsed.token.filter(\.isNumber)),
           let bridge = womensNumericBridge(us: n) {
            return "Ref. chart ≈ EU \(bridge.eu) / UK \(bridge.uk) (not brand-true)"
        }
        return "Size label kept as-is — fit uses body & garment measures"
    }
}
