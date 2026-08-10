import Foundation

/// Photoreal F/M body-base mesh lock-in (USDZ), per `NudeBodyBaseSpec` (D59/D63/D64).
/// Product bar = real photoreal human + **minimal catalog basewear**
/// (♀ pasties+thong / ♂ thong); full-nude zero covering is aspirational, not the bar.
/// Bundle names stable (`nude_body_*` stems kept for compatibility); until certified
/// assets ship, UI falls back to a procedural SceneKit approximation — an interim
/// stand-in only, never a final visual (`NudeBodyBaseSpec.allowsMeshOrSimulationAsFinalVisual == false`).
///
/// **License gate (D51):** no SMPL without commercial Meshcapade license.
/// Prefer CC0 / purchased photoreal body USDZ, or in-house scans — not dressed fashion dummies.
public enum MannequinMeshCatalog: Sendable {
    /// Expected bundle resource (no extension) for a sex-specific **nude** photoreal base.
    /// Canonical names; legacy `mannequin_body_*` still accepted as aliases.
    public static func usdzResourceName(for sex: AvatarBodySex) -> String {
        switch sex {
        case .female: return "nude_body_female"
        case .male: return "nude_body_male"
        }
    }

    /// 优选：按表型的 nude mesh 名（`nude_body_{sex}_{phenotype}`）；缺省回退 sex-only。
    public static func usdzResourceName(
        for sex: AvatarBodySex,
        phenotype: AvatarBodyPhenotype
    ) -> String {
        NudeBodyBaseSpec.nudeMeshName(sex: sex, phenotype: phenotype)
    }

    /// Older resource stem (pre-D54 rename); still loads if present.
    public static func legacyUsdzResourceName(for sex: AvatarBodySex) -> String {
        switch sex {
        case .female: return "mannequin_body_female"
        case .male: return "mannequin_body_male"
        }
    }

    public static func usdzFileName(for sex: AvatarBodySex) -> String {
        usdzResourceName(for: sex) + ".usdz"
    }

    /// 加载顺序 stems：phenotype 专用 → sex 通用 → legacy。
    public static func usdzCandidateStems(
        sex: AvatarBodySex,
        phenotype: AvatarBodyPhenotype = .eastAsian
    ) -> [String] {
        [
            usdzResourceName(for: sex, phenotype: phenotype),
            usdzResourceName(for: sex),
            legacyUsdzResourceName(for: sex)
        ]
    }

    /// Scene graph root name inside a locked USDZ (authors should match this).
    public static let bodyRootNodeName = "BodyRoot"

    /// Optional named child nodes the loader will re-scale with `MannequinSegmentScales`.
    /// Missing nodes are skipped (whole-body scale still applies via height).
    public static let segmentNodeNames: Set<String> = [
        "shoulderBar", "chest", "breastL", "breastR", "pecL", "pecR",
        "waist", "hip", "glute",
        "lThigh", "rThigh", "lShin", "rShin",
        "lUpperArm", "rUpperArm", "lForeArm", "rForeArm",
        "lHand", "rHand", "lFoot", "rFoot",
        // D63/D64: base mesh carries only the minimal catalog basewear (`NudeBodyBaseSpec`);
        // no additional garment/covering nodes beyond that.
        "hair", "head", "neck", "pelvis"
    ]

    /// How the runtime should pick geometry.
    public enum MeshSource: String, Equatable, Sendable {
        /// Locked photoreal mesh from bundle USDZ.
        case usdz
        /// Capsule/sphere anatomical approximation (current default until USDZ lands).
        case procedural
    }

    /// Resolve source: prefer nude USDZ when present (phenotype → sex → legacy).
    public static func resolveSource(
        sex: AvatarBodySex,
        phenotype: AvatarBodyPhenotype = .eastAsian,
        availableResourceNames: Set<String>
    ) -> MeshSource {
        resolveUsdzStem(
            sex: sex,
            phenotype: phenotype,
            availableResourceNames: availableResourceNames) != nil
            ? .usdz
            : .procedural
    }

    /// Pick first matching resource stem for loader (phenotype preferred).
    public static func resolveUsdzStem(
        sex: AvatarBodySex,
        phenotype: AvatarBodyPhenotype = .eastAsian,
        availableResourceNames: Set<String>
    ) -> String? {
        for stem in usdzCandidateStems(sex: sex, phenotype: phenotype) {
            if availableResourceNames.contains(stem)
                || availableResourceNames.contains(stem + ".usdz")
            {
                return stem
            }
        }
        return nil
    }
}
