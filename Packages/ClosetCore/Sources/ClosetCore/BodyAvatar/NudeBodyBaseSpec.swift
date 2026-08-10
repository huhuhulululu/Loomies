import Foundation

/// **产品硬约束 D59/D63/D64（用户选方案 2 + 男女丁字裤）**
///
/// 人体底座 = **真实写实的真人照片** + **最小 catalog basewear**（可过审）：
/// - ♀：乳贴 + 丁字裤（pasties + thong）
/// - ♂：丁字裤（thong）— **不是 brief / 三角裤**
///
/// 明确禁止把以下当最终视觉：
/// - SceneKit 胶囊/椭球/程序化 mesh 作为主展示
/// - 穿衣模特、塑料假人、CG 剪影 raster 冒充实拍
///
/// 外衣/内衣只作为 **上层 2D 叠衣**。360° = 多角度 **真人照片切帧**。
///
/// 全裸为零远期 aspirational；当前产品 bar = catalog 丁字裤档认证。
/// `isHardRequirementMet` 看 `photorealFrontAssetsCertifiedCatalogBasewear`。
public enum NudeBodyBaseSpec: Sendable {
    public static let invariant =
        "Body base MUST be a real photoreal human photograph with MINIMAL catalog basewear "
        + "(♀ pasties+thong / ♂ thong — both wear thong, not brief), multi-phenotype. "
        + "NOT mesh/capsule as final. Clothes only as layers on top. "
        + "Full-nude zero covering is aspirational, not the product bar."

    public static let coveringPolicy = "minimal_basewear"

    /// 允许 catalog 最小 basewear（D59 方案 2）。
    public static let allowsMinimalCatalogBasewear = true

    /// 禁止任意衣物作底座（仅 pastie + thong 级）。
    public static let allowsAnyCovering = false

    /// 产品不要求全裸；全裸为可选远期。
    public static var requiresFullNude: Bool { false }

    public static let requiresPhotorealRealHuman = true

    public static let allowsMeshOrSimulationAsFinalVisual = false

    public static let allowsProceduralCapsuleAsFinalVisual = false

    public static let femaleBasewearDescription =
        "pasties + thong — real human photo, catalog-safe minimal basewear"
    public static let maleBasewearDescription =
        "thong — real human photo, catalog-safe minimal basewear (not brief)"

    public static func basewearDescription(for sex: AvatarBodySex) -> String {
        switch sex {
        case .female: return femaleBasewearDescription
        case .male: return maleBasewearDescription
        }
    }

    /// Bundle 真人 catalog 丁字裤档照片已认证。
    /// 现有 `photoreal_female_front` / `photoreal_male_front` 为该档入口（男图应丁字裤非 brief）。
    public static let photorealFrontAssetsCertifiedCatalogBasewear = true

    /// 全裸零遮盖认证（远期；当前 false，gen moderated + inpaint 不足）。
    public static let photorealFrontAssetsCertifiedFullNude = false

    public static let photoreal3DMeshCertifiedFullNude = false

    /// D59 产品硬要求：catalog basewear 真人照片已认证即可。
    public static var isHardRequirementMet: Bool {
        photorealFrontAssetsCertifiedCatalogBasewear
            && primaryRenderMode == .realHumanPhoto
            && !allowsMeshOrSimulationAsFinalVisual
    }

    public static var certificationGaps: [String] {
        var gaps: [String] = []
        if !photorealFrontAssetsCertifiedCatalogBasewear {
            gaps.append(
                "Missing certified real-human catalog basewear front photos "
                    + "(♀ pasties+thong / ♂ thong)")
        }
        if allowsMeshOrSimulationAsFinalVisual || allowsProceduralCapsuleAsFinalVisual {
            gaps.append("Mesh/capsule must not be allowed as final visual")
        }
        if allowsAnyCovering {
            gaps.append("allowsAnyCovering must stay false (only minimal catalog basewear)")
        }
        if primaryRenderMode != .realHumanPhoto {
            gaps.append("primaryRenderMode must be realHumanPhoto")
        }
        // Full nude is aspirational — not a product gap under D59.
        return gaps
    }

    public enum PrimaryRenderMode: String, Sendable {
        case realHumanPhoto
        case meshSimulationInterim
    }

    public static let primaryRenderMode: PrimaryRenderMode = .realHumanPhoto

    /// Catalog 认证后允许展示写实正面（含 pastie+thong / male thong 资产）。
    public static func mayUsePhotorealFrontAsset(named name: String) -> Bool {
        guard photorealFrontAssetsCertifiedCatalogBasewear || photorealFrontAssetsCertifiedFullNude
        else { return false }
        return isAllowedPhotorealFrontName(name)
    }

    public static let certFlipPrerequisites: [String] = [
        "Real-human photograph (not mesh/capsule/CG silhouette raster)",
        "MINIMAL catalog basewear: ♀ pasties+thong / ♂ thong (both thong; no brief as product bar)",
        "At least photoreal_female_front + photoreal_male_front (multi-phenotype preferred)",
        "Optional multi-angle: photoreal_{sex}_{phenotype}_yaw{000…315}",
        "Human visual QA signed off for catalog basewear path (D59/D64)",
        "primaryRenderMode remains realHumanPhoto; allowsAnyCovering remains false",
        "DO NOT flip photorealFrontAssetsCertifiedFullNude while pastie/thong remain",
        "DO NOT set coveringPolicy=none or requiresFullNude=true without user re-approval (D59 locked)",
        "DO NOT describe male basewear as brief — product is thong for both sexes (D64)",
    ]

    public static var minimumCertFrontNames: [String] {
        AvatarBodySex.allCases.map { BodyAvatarAsset.photorealFrontName(sex: $0) }
    }

    public static func requiredPhotorealFrontName(sex: AvatarBodySex) -> String {
        BodyAvatarAsset.photorealFrontName(sex: sex)
    }

    public static func photorealFrontName(sex: AvatarBodySex, phenotype: AvatarBodyPhenotype) -> String {
        "photoreal_\(sex.rawValue)_\(phenotype.rawValue)_front"
    }

    public static func requiredNudeMeshName(sex: AvatarBodySex) -> String {
        MannequinMeshCatalog.usdzResourceName(for: sex)
    }

    public static func nudeMeshName(sex: AvatarBodySex, phenotype: AvatarBodyPhenotype) -> String {
        "nude_body_\(sex.rawValue)_\(phenotype.rawValue)"
    }

    public static var allPhenotypePhotorealFrontNames: [String] {
        AvatarBodySex.allCases.flatMap { sex in
            AvatarBodyPhenotype.allCases.map { photorealFrontName(sex: sex, phenotype: $0) }
        }
    }

    public static var allPhenotypeNudeMeshNames: [String] {
        AvatarBodySex.allCases.flatMap { sex in
            AvatarBodyPhenotype.allCases.map { nudeMeshName(sex: sex, phenotype: $0) }
        }
    }

    /// 禁止把「整套内衣/泳装/穿衣」当底座资产名；catalog 正面名 photoreal_* 本身不含这些 token。
    public static let forbiddenAssetTokens: Set<String> = [
        "bra", "panty", "panties", "lingerie", "lingerie_set", "swimsuit", "bikini",
        "underwear", "clothed", "dressed", "outfit", "ivory_mannequin", "plastic_dummy",
        "capsule_final", "abstract_croquis_final"
    ]

    public static func isForbiddenAssetName(_ name: String) -> Bool {
        let n = name.lowercased()
        return forbiddenAssetTokens.contains { n.contains($0) }
    }

    public static func isAllowedPhotorealFrontName(_ name: String) -> Bool {
        if isForbiddenAssetName(name) { return false }
        if name == BodyAvatarAsset.photorealFrontName(sex: .female)
            || name == BodyAvatarAsset.photorealFrontName(sex: .male)
        {
            return true
        }
        for sex in AvatarBodySex.allCases {
            for p in AvatarBodyPhenotype.allCases {
                if name == photorealFrontName(sex: sex, phenotype: p) { return true }
            }
            for yaw in [0, 45, 90, 135, 180, 225, 270, 315] {
                let y = String(format: "yaw%03d", yaw)
                if name == "photoreal_\(sex.rawValue)_\(y)" { return true }
                for p in AvatarBodyPhenotype.allCases {
                    if name == "photoreal_\(sex.rawValue)_\(p.rawValue)_\(y)" { return true }
                }
            }
        }
        return false
    }

    public static func isGenericPhotorealFrontName(_ name: String) -> Bool {
        name == BodyAvatarAsset.photorealFrontName(sex: .female)
            || name == BodyAvatarAsset.photorealFrontName(sex: .male)
    }
}

/// 展示用人种/表型（肤色与发型默认；非医学种族分类）。
public enum AvatarBodyPhenotype: String, CaseIterable, Sendable {
    case eastAsian
    case southeastAsian
    case southAsian
    case european
    case african
    case latinx
    case middleEastern
    case indigenous

    public var displayTitle: String {
        switch self {
        case .eastAsian: return "East Asian"
        case .southeastAsian: return "Southeast Asian"
        case .southAsian: return "South Asian"
        case .european: return "European"
        case .african: return "African"
        case .latinx: return "Latine"
        case .middleEastern: return "Middle Eastern"
        case .indigenous: return "Indigenous"
        }
    }

    public var skinRGB: (r: Double, g: Double, b: Double) {
        switch self {
        case .eastAsian: return (0.90, 0.76, 0.68)
        case .southeastAsian: return (0.78, 0.58, 0.45)
        case .southAsian: return (0.62, 0.42, 0.30)
        case .european: return (0.93, 0.80, 0.72)
        case .african: return (0.38, 0.24, 0.18)
        case .latinx: return (0.72, 0.52, 0.40)
        case .middleEastern: return (0.80, 0.62, 0.48)
        case .indigenous: return (0.68, 0.48, 0.36)
        }
    }

    public var hairRGB: (r: Double, g: Double, b: Double) {
        switch self {
        case .eastAsian, .southeastAsian, .southAsian, .african, .indigenous, .middleEastern:
            return (0.12, 0.09, 0.08)
        case .european:
            return (0.28, 0.20, 0.14)
        case .latinx:
            return (0.14, 0.10, 0.08)
        }
    }

    public func skinRGB(sex: AvatarBodySex) -> (r: Double, g: Double, b: Double) {
        let s = skinRGB
        guard sex == .male else { return s }
        return (s.r * 0.92, s.g * 0.90, s.b * 0.88)
    }

    public var skinLuminance: Double {
        let s = skinRGB
        return 0.2126 * s.r + 0.7152 * s.g + 0.0722 * s.b
    }

    public var keyLightIntensityScale: Double {
        min(1.35, max(1.0, 1.0 + (0.45 - skinLuminance) * 0.9))
    }

    public var skinRoughness: Double {
        min(0.62, max(0.36, 0.55 - skinLuminance * 0.12))
    }

    public var areolaDarken: Double {
        min(0.72, max(0.48, 0.55 + skinLuminance * 0.15))
    }

    public var segmentBias: MannequinSegmentScales {
        switch self {
        case .eastAsian:
            return MannequinSegmentScales()
        case .southeastAsian:
            return MannequinSegmentScales(height: 0.99, limbThickness: 0.98)
        case .southAsian:
            return MannequinSegmentScales(shoulderWidth: 1.02, limbThickness: 1.01)
        case .european:
            return MannequinSegmentScales(height: 1.02, shoulderWidth: 1.03, limbThickness: 1.02)
        case .african:
            return MannequinSegmentScales(
                height: 1.03, shoulderWidth: 1.04, hipWidth: 1.02, limbThickness: 1.04)
        case .latinx:
            return MannequinSegmentScales(hipWidth: 1.02, limbThickness: 1.01)
        case .middleEastern:
            return MannequinSegmentScales(shoulderWidth: 1.02, chestWidth: 1.01)
        case .indigenous:
            return MannequinSegmentScales(height: 0.99, limbThickness: 1.0)
        }
    }

    public func skinTintMultiplier(
        relativeTo base: AvatarBodyPhenotype
    ) -> (r: Double, g: Double, b: Double) {
        let t = skinRGB
        let b = base.skinRGB
        func ratio(_ a: Double, _ c: Double) -> Double {
            min(1.35, max(0.45, a / max(0.05, c)))
        }
        return (ratio(t.r, b.r), ratio(t.g, b.g), ratio(t.b, b.b))
    }

    public static func isGenericPhotorealFrontName(_ name: String) -> Bool {
        NudeBodyBaseSpec.isGenericPhotorealFrontName(name)
    }
}
