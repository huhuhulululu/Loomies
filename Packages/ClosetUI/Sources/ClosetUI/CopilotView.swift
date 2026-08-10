import SwiftUI
import SwiftData
import ClosetModel
import ClosetCore

/// Today 首屏 = **Avatar + 今日 look**（方案 B）+ copilot。
/// 视觉：大人体 + 叠衣；机制：锚定 → 补全（D19），非 VTON。
public struct CopilotView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var vm: CopilotViewModel
    @State private var checkInNote: String?
    /// Toast 代际：同文案连发时旧计时器不得提前清掉新 toast（按值判等无法区分代）。
    @State private var flashToken = 0
    @State private var cinematicFailureToken = 0
    @State private var actions = OutfitActionsViewModel()
    @State private var didBootstrap = false
    @State private var isExportingCinematic = false
    @State private var cinematicShareURL: URL?
    @State private var showCinematicShare = false
    /// Brief failure pulse on film button (clears with flash toast).
    @State private var cinematicExportFailed = false
    /// Live body profiles so Me → Body edits re-score Today without relaunch.
    @Query private var bodyProfiles: [PersonBodyProfile]
    private var debug: DebugSettings { DebugSettings.shared }

    public init(wardrobe: Wardrobe) {
        _vm = State(initialValue: CopilotViewModel(wardrobe: wardrobe))
    }

    private let occasions = ["work", "date", "gala", "casual"]

    private var ownerProfile: PersonBodyProfile? {
        guard let pid = vm.wardrobe.owner?.id else { return nil }
        return bodyProfiles.first { $0.personID == pid }
    }

    /// Equatable snapshot so Me → Body edits re-score without bootstrap-only bodyShape.
    private var ownerBodySnapshot: OwnerBodySnapshot {
        OwnerBodySnapshot(profile: ownerProfile)
    }

    public var body: some View {
        NavigationStack {
            todayScrollContent
                .background(DS.bg.ignoresSafeArea())
                .navigationTitle("Today")
                #if os(iOS)
                .navigationBarTitleDisplayMode(.large)
                #endif
                // Favorites were only under Me — surface after Save (journey 6 discoverability).
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        NavigationLink {
                            FavoritesView(wardrobe: vm.wardrobe)
                        } label: {
                            Label("Favorites", systemImage: "heart")
                        }
                        .accessibilityLabel(Self.favoritesToolbarAccessibilityLabel)
                    }
                }
                .task { await runBootstrapOnce() }
                .onChange(of: vm.wardrobe.locationCity) { _, _ in
                    Task { await reapplyWeatherAfterCityChange() }
                }
                .onChange(of: ownerBodySnapshot) { _, _ in
                    reapplyBodyProfileIfNeeded()
                }
        }
    }

    /// Today → Favorites entry (toolbar heart). Kept public for journey tests.
    public static let favoritesToolbarAccessibilityLabel = "Favorites"

    /// A11Y: look-pager chevrons — visual stays small, hit target meets the
    /// 44pt HIG minimum. `nonisolated` so tests can pin without MainActor hops.
    nonisolated static let lookPagerChevronVisualSize: CGFloat = 28
    nonisolated static let lookPagerChevronHitArea: CGFloat = 44

    private var todayScrollContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                heroCard
                if vm.isColdStart { coldStartBanner }
                controlsCard
                if shouldShowAnchors { anchorSection }
                if !vm.suggestions.isEmpty { otherLooksSection }
                else if !vm.statusMessage.isEmpty && !vm.isColdStart && !vm.isRefreshing {
                    emptyLooksNote
                }
                if let checkInNote {
                    feedbackChip(checkInNote)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }

    private func runBootstrapOnce() async {
        guard !didBootstrap else { return }
        didBootstrap = true
        await bootstrap()
    }

    private func reapplyBodyProfileIfNeeded() {
        guard didBootstrap else { return }
        let changed = vm.applyBodyProfile(ownerProfile)
        if changed {
            runRefresh()
            AppLog.info(
                "body profile reapplied shape=\(vm.bodyShape?.rawValue ?? "nil")",
                .copilot)
        }
    }

    private var shouldShowAnchors: Bool {
        !vm.fullAuto || vm.isColdStart || !vm.anchorIDs.isEmpty
    }

    // MARK: - Hero card

    private var heroCard: some View {
        let heroBackdrop = AvatarBackdrop.resolved(from: vm.occasion)
        return VStack(spacing: 0) {
            ZStack(alignment: .topTrailing) {
                BodyAvatarView(
                    shape: heroShape,
                    morph: bodyMorph,
                    layers: heroLayers,
                    fitCaption: heroFitCaption,
                    showsFitCaption: true,
                    enablesOrbit: true,
                    compactChrome: true,
                    backdrop: heroBackdrop,
                    depthIntensity: .cinematic,
                    bodySex: heroBodySex,
                    bodyPhenotype: heroBodyPhenotype,
                    usesMannequin3D: false)
                .padding(.top, 4)
                .padding(.horizontal, 4)
                .frame(minHeight: DS.heroMinHeight)
                // 场合切换：只重建 backdrop 层（BodyAvatarView 内 .id），勿整卡 remount
                // （.id 整树会丢 yaw/orbit/@State — WWDC identity）

                // 未叠衣 / 仅 slot 占位：底座仍可见，但明确「还没穿上」——避免误以为穿衣坏了。
                // Gate on decodeable visuals, not layer count (path-only → placeholders only).
                // VoiceOver must hear this empty-look hint (do not accessibilityHidden).
                // Capsule pins to figure canvas only (not full BodyAvatarView stack) so
                // orbit chrome + fitCaption stay clear on short hero cards.
                if CopilotEmptyDressOverlay.shouldShow(layers: heroLayers) {
                    // Selected look with zero wardrobe layers shares "Look items unavailable"
                    // with title + fitCaption (not generic Undressed / Proportion guide).
                    // Path-only layers still use the generic undressed capsule.
                    let emptyHint = CopilotEmptyDressOverlay.message(
                        isColdStart: vm.isColdStart,
                        lookItemsUnavailable:
                            vm.selectedSuggestion != nil && heroLayers.isEmpty)
                    VStack(spacing: 0) {
                        Color.clear
                            .aspectRatio(
                                CopilotEmptyDressOverlay.canvasAspectRatio,
                                contentMode: .fit)
                            .overlay(alignment: .bottom) {
                                Text(emptyHint)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(DS.ink)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 10)
                                    .background(.ultraThinMaterial, in: Capsule())
                                    .padding(
                                        .bottom,
                                        CopilotEmptyDressOverlay.canvasBottomPadding)
                            }
                        Spacer(minLength: 0)
                    }
                    .padding(.top, 4)
                    .padding(.horizontal, 4)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .allowsHitTesting(false)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(emptyHint)
                }

                // 场合色微边光（细、不抢切边）
                RoundedRectangle(cornerRadius: DS.radiusLg, style: .continuous)
                    .strokeBorder(heroEdgeGlow(heroBackdrop), lineWidth: 0.8)
                    .padding(3)
                    .allowsHitTesting(false)

                HStack {
                    // 2s 电影感分享预览（yaw + 视差 MP4）
                    Button {
                        Task { await exportCinematicPreview(backdrop: heroBackdrop) }
                    } label: {
                        Group {
                            if isExportingCinematic {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Image(systemName: cinematicExportFailed
                                      ? "exclamationmark.triangle.fill" : "film")
                                    .font(.body.weight(.semibold))
                            }
                        }
                        .foregroundStyle(cinematicExportFailed ? Color.orange : DS.ink)
                        .frame(width: 36, height: 36)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .disabled(
                        isExportingCinematic
                            || !CopilotCinematicExportCopy.canExport(layers: heroLayers))
                    .accessibilityLabel(
                        cinematicExportFailed
                        ? CopilotCinematicExportCopy.failedLabel
                        : CopilotCinematicExportCopy.label)
                    .accessibilityHint(CopilotCinematicExportCopy.hint)
                    .padding(14)
                    Spacer()
                    if vm.isRefreshing {
                        ProgressView()
                            .padding(12)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                            .padding(14)
                    }
                }
            }
            .sheet(isPresented: $showCinematicShare, onDismiss: {
                // 分享面板关闭（取消或完成）即删当次 MP4：活动已在分享时拷贝数据，
                // 留盘只会在 tmp 无界积累（内容是身体形态视频，敏感度高）。
                if let url = cinematicShareURL {
                    try? FileManager.default.removeItem(at: url)
                    cinematicShareURL = nil
                }
            }) {
                if let url = cinematicShareURL {
                    ShareSheet(items: [url])
                }
            }

            // Wear/fit copy lives on BodyAvatarView.captionBlock (fitCaption);
            // keep title-only chrome here to avoid duplicating the caption.
            Text(heroTitle)
                .font(.headline)
                .foregroundStyle(DS.ink)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
                .padding(.top, 6)

            HStack(spacing: 12) {
                metaPill(
                    icon: "cloud.sun",
                    text: String(format: "%.0f°F", vm.daytimeTempF))
                metaPill(icon: "tag", text: vm.occasion.capitalized)
                if vm.lookCount > 1 {
                    lookPager
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 10)

            // W1.3 / W1.5 — source honesty + practical rain/cool cue
            VStack(spacing: 2) {
                Text(vm.weatherSourceLabel)
                    .font(.caption2)
                    .foregroundStyle(DS.muted)
                if let cue = vm.weatherDressCue {
                    Text(cue)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(DS.ink.opacity(0.75))
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 4)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(
                "Weather \(Int(vm.daytimeTempF)) degrees Fahrenheit, \(vm.weatherSourceLabel)"
                + (vm.weatherDressCue.map { ", \($0)" } ?? ""))

            if vm.selectedSuggestion != nil {
                HStack(spacing: 8) {
                    primaryAction("Save", systemImage: "heart") {
                        guard let scored = vm.selectedSuggestion else { return }
                        actions.saveFavorite(
                            scored: scored, occasion: vm.occasion,
                            in: vm.wardrobe, context: context)
                        flash(actions.message)
                    }
                    primaryAction("Plan", systemImage: "calendar") {
                        guard let scored = vm.selectedSuggestion else { return }
                        actions.planToday(
                            scored: scored, occasion: vm.occasion,
                            in: vm.wardrobe, context: context)
                        flash(actions.message)
                    }
                    primaryAction("Wore it", systemImage: "checkmark") {
                        guard let scored = vm.selectedSuggestion else { return }
                        checkIn(scored)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.top, 12)
                .padding(.bottom, 14)
            } else {
                Color.clear.frame(height: 12)
            }
        }
        .background(
            ZStack {
                DS.surface
                // 卡片底随场合极淡染色
                heroCardWash(heroBackdrop)
                    .opacity(0.14)
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: DS.radiusLg, style: .continuous))
        .shadow(color: DS.ink.opacity(0.08), radius: 20, y: 8)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.28), value: vm.occasion)
        // Look 翻页：标题/叠衣/动作条一并缓动（HIG content change）
        .animation(
            reduceMotion ? nil : .easeInOut(duration: 0.22),
            value: vm.selectedSuggestionIndex)
    }

    private func heroEdgeGlow(_ b: AvatarBackdrop) -> LinearGradient {
        let c: Color = {
            switch b {
            case .studio: return Color.white.opacity(0.35)
            case .work: return Color(red: 0.55, green: 0.72, blue: 0.95).opacity(0.55)
            case .date: return Color(red: 0.95, green: 0.45, blue: 0.5).opacity(0.55)
            case .gala: return Color(red: 0.7, green: 0.55, blue: 1).opacity(0.6)
            case .casual: return Color(red: 0.55, green: 0.8, blue: 0.65).opacity(0.5)
            }
        }()
        return LinearGradient(colors: [c, c.opacity(0.15), c], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    private func heroCardWash(_ b: AvatarBackdrop) -> Color {
        switch b {
        case .studio: return Color(white: 0.7)
        case .work: return Color(red: 0.55, green: 0.7, blue: 0.9)
        case .date: return Color(red: 0.7, green: 0.3, blue: 0.4)
        case .gala: return Color(red: 0.45, green: 0.3, blue: 0.7)
        case .casual: return Color(red: 0.5, green: 0.75, blue: 0.6)
        }
    }

    private var lookPager: some View {
        HStack(spacing: 6) {
            Button {
                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.22)) {
                    vm.selectPreviousLook()
                }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(DS.accent)
                    .frame(
                        width: Self.lookPagerChevronVisualSize,
                        height: Self.lookPagerChevronVisualSize)
                    .background(DS.bg)
                    .clipShape(Circle())
                    // A11Y: grow tap target to 44pt without changing the 28pt visual.
                    .padding((Self.lookPagerChevronHitArea - Self.lookPagerChevronVisualSize) / 2)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Previous look")
            Text("\(vm.selectedSuggestionIndex + 1)/\(vm.lookCount)")
                .font(.caption.monospacedDigit().weight(.medium))
                .foregroundStyle(DS.ink)
                .accessibilityLabel("Look \(vm.selectedSuggestionIndex + 1) of \(vm.lookCount)")
            Button {
                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.22)) {
                    vm.selectNextLook()
                }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(DS.accent)
                    .frame(
                        width: Self.lookPagerChevronVisualSize,
                        height: Self.lookPagerChevronVisualSize)
                    .background(DS.bg)
                    .clipShape(Circle())
                    // A11Y: grow tap target to 44pt without changing the 28pt visual.
                    .padding((Self.lookPagerChevronHitArea - Self.lookPagerChevronVisualSize) / 2)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Next look")
        }
    }

    private func metaPill(icon: String, text: String) -> some View {
        Label(text, systemImage: icon)
            .font(.caption2.weight(.medium))
            .foregroundStyle(DS.muted)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(DS.bg)
            .clipShape(Capsule())
    }

    private var heroTitle: String {
        CopilotHeroTitle.text(
            resolvedItemNames: vm.selectedSuggestion.map(itemNames(for:)) ?? [],
            hasSelectedSuggestion: vm.selectedSuggestion != nil,
            hasAnchors: !vm.anchorIDs.isEmpty,
            isColdStart: vm.isColdStart)
    }

    /// Wear/fit copy for hero `BodyAvatarView` caption (not external subtitle).
    private var heroFitCaption: String {
        CopilotHeroFitCaption.text(
            layers: heroLayers,
            hasSelectedSuggestion: vm.selectedSuggestion != nil,
            hasAnchors: !vm.anchorIDs.isEmpty,
            isColdStart: vm.isColdStart)
    }

    private var heroShape: PopularShape {
        if let p = ownerProfile,
           let s = BodyProfileService.displayPopularShape(from: p) {
            return s
        }
        return vm.bodyShape?.popularCategory ?? .rectangle
    }

    private var heroBodySex: AvatarBodySex {
        BodyProfileService.presentationSex(from: ownerProfile)
    }

    private var heroBodyPhenotype: AvatarBodyPhenotype {
        BodyProfileService.presentationPhenotype(from: ownerProfile)
    }

    private var heroLayers: [BodyAvatarLayer] {
        if let scored = vm.selectedSuggestion {
            return OutfitAvatarComposer.layers(
                itemIDs: scored.outfit.itemIDs, in: vm.wardrobe)
        }
        let anchored = (vm.wardrobe.items ?? []).filter { vm.anchorIDs.contains($0.id) }
        if !anchored.isEmpty {
            return OutfitAvatarComposer.layers(from: anchored)
        }
        return []
    }

    // MARK: - Cold start / controls

    private var coldStartBanner: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Get a full look in a minute")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(DS.ink)
            Text("Load samples, or add from Closet. Then anchor one item or use full-auto.")
                .font(.caption)
                .foregroundStyle(DS.muted)
            Button {
                let outcome = DemoSeedService.seedIfEmpty(vm.wardrobe, in: context)
                flash(outcome.flashMessage)
                // Only auto-refresh when pieces actually landed (save fail keeps cold-start honest).
                if case .added = outcome {
                    vm.fullAuto = true
                    vm.refresh()
                }
            } label: {
                Text("Load samples")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(DS.accent)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: DS.radius, style: .continuous))
            }
            .buttonStyle(.plain)
            // Same demo-not-photos VO as Me → Demo / Closet empty Load samples.
            .accessibilityHint(DemoSeedService.loadButtonAccessibilityHint)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DS.accent.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: DS.radiusLg, style: .continuous))
    }

    private var controlsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("Occasion", selection: $vm.occasion) {
                ForEach(occasions, id: \.self) { Text($0.capitalized).tag($0) }
            }
            .pickerStyle(.segmented)
            .onChange(of: vm.occasion) { _, _ in
                if !vm.isColdStart {
                    vm.refresh()
                }
            }

            if !vm.isColdStart {
                Toggle("Just decide for me", isOn: $vm.fullAuto)
                    .tint(DS.accent)
                    .font(.subheadline)
            }

            Button {
                runRefresh()
            } label: {
                HStack {
                    if vm.isRefreshing {
                        ProgressView().tint(.white)
                    }
                    Text(primaryCTA)
                        .font(.headline)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(DS.accent)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: DS.radius, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(vm.isRefreshing)

            if debug.showEmptyReason, !vm.statusMessage.isEmpty {
                Text(vm.statusMessage)
                    .font(.caption2)
                    .foregroundStyle(DS.muted)
            }
        }
        .padding(14)
        .background(DS.surface)
        .clipShape(RoundedRectangle(cornerRadius: DS.radiusLg, style: .continuous))
    }

    private var primaryCTA: String {
        if vm.fullAuto && !vm.isColdStart { return "Refresh look" }
        return "Complete my look"
    }

    // MARK: - Anchors（横滑，少占屏）

    private var anchorSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(vm.availableItems.isEmpty
                     ? "No pieces yet"
                     : "Anchor pieces")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(DS.ink)
                Spacer()
                if !vm.anchorIDs.isEmpty {
                    Button("Clear") { vm.clearAnchors() }
                        .font(.caption.weight(.medium))
                        .foregroundStyle(DS.accent)
                }
            }
            if vm.availableItems.isEmpty {
                Text("Add from Closet, or load samples above.")
                    .font(.caption)
                    .foregroundStyle(DS.muted)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(vm.availableItems, id: \.id) { item in
                            Button { vm.toggleAnchor(item) } label: {
                                itemChip(item)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .padding(14)
        .background(DS.surface)
        .clipShape(RoundedRectangle(cornerRadius: DS.radiusLg, style: .continuous))
    }

    private func itemChip(_ item: Item) -> some View {
        let anchored = vm.isAnchored(item)
        return VStack(spacing: 6) {
            ItemThumbnailView(item: item, height: 72)
                .frame(width: 72)
            Text(item.name)
                .font(.caption2)
                .foregroundStyle(DS.ink)
                .lineLimit(1)
                .frame(width: 76)
        }
        .padding(6)
        .background(anchored ? DS.accent.opacity(0.12) : DS.bg)
        .overlay(
            RoundedRectangle(cornerRadius: DS.radius, style: .continuous)
                .stroke(anchored ? DS.accent : DS.muted.opacity(0.15), lineWidth: anchored ? 2 : 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: DS.radius, style: .continuous))
    }

    // MARK: - Other looks

    private var otherLooksSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Other looks")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(DS.ink)
            ForEach(Array(vm.suggestions.enumerated()), id: \.offset) { idx, scored in
                suggestionRow(scored, index: idx)
            }
        }
    }

    /// Empty looks: state + learning cue + one recovery path (NN/g empty-state).
    private var emptyLooksNote: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("No looks matched", systemImage: "sparkles")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(DS.ink)
            Text(vm.statusMessage)
                .font(.caption)
                .foregroundStyle(DS.muted)
            if !vm.anchorIDs.isEmpty {
                Button {
                    vm.clearAnchors()
                    vm.fullAuto = true
                    runRefresh()
                } label: {
                    Text("Clear anchors & try full-auto")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(DS.accent)
                }
                .buttonStyle(.plain)
            } else if !vm.fullAuto {
                Button {
                    vm.fullAuto = true
                    runRefresh()
                } label: {
                    Text("Try full-auto")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(DS.accent)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DS.surface)
        .clipShape(RoundedRectangle(cornerRadius: DS.radiusLg, style: .continuous))
    }

    private func suggestionRow(_ scored: ScoredOutfit, index: Int) -> some View {
        let selected = index == vm.selectedSuggestionIndex
        // Visual thumbnails beat abstract counts for outfit pick (D40 + HIG).
        let layers = OutfitAvatarComposer.layers(
            itemIDs: scored.outfit.itemIDs, in: vm.wardrobe)
        let rowBackdrop = AvatarBackdrop.resolved(from: vm.occasion)
        return Button {
            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) {
                vm.selectSuggestion(at: index)
            }
        } label: {
            HStack(spacing: 12) {
                BodyAvatarView(
                    shape: heroShape,
                    morph: bodyMorph,
                    layers: layers,
                    showsFitCaption: false,
                    enablesOrbit: false,
                    backdrop: rowBackdrop,
                    depthIntensity: .off,
                    bodySex: heroBodySex,
                    bodyPhenotype: heroBodyPhenotype,
                    usesMannequin3D: false)
                .frame(width: 56, height: 84)
                .clipShape(RoundedRectangle(cornerRadius: DS.radius, style: .continuous))
                .allowsHitTesting(false)
                .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    Text(itemNames(for: scored).joined(separator: " · "))
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(DS.ink)
                        .lineLimit(1)
                        .multilineTextAlignment(.leading)
                    if let reason = scored.score.reasons.first {
                        Text(reason)
                            .font(.caption2)
                            .foregroundStyle(DS.muted)
                            .lineLimit(1)
                    } else {
                        Text("\(scored.outfit.items.count) pieces")
                            .font(.caption2)
                            .foregroundStyle(DS.muted)
                    }
                }
                Spacer(minLength: 0)
                if selected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(DS.accent)
                }
            }
            .padding(12)
            .background(selected ? DS.accent.opacity(0.07) : DS.surface)
            .overlay(
                RoundedRectangle(cornerRadius: DS.radius, style: .continuous)
                    .stroke(selected ? DS.accent.opacity(0.5) : Color.clear, lineWidth: 1.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: DS.radius, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(itemNames(for: scored).joined(separator: ", "))
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func feedbackChip(_ text: String) -> some View {
        // Failures orange (parity ItemDetail / Transfer); success stays accent.
        let fail = Self.feedbackChipIsFailure(text)
        let tint = fail ? Color.orange : DS.accent
        return Text(text)
            .font(.caption.weight(.medium))
            .foregroundStyle(tint)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(tint.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: DS.radius, style: .continuous))
            // Save / Plan / Wore / seed flash — VO parity with Favorites overlay.
            .accessibilityLabel(text)
    }

    /// Today flash chip: honest fail paint — not accent “success” chrome.
    static func feedbackChipIsFailure(_ text: String) -> Bool {
        CustomerFlashStyle.isFailure(text)
    }

    private func primaryAction(_ title: String, systemImage: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.caption.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .background(DS.bg)
                .foregroundStyle(DS.accent)
                .clipShape(RoundedRectangle(cornerRadius: DS.radius, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func exportCinematicPreview(backdrop: AvatarBackdrop) async {
        // Defense-in-depth (button is already disabled): no basewear-only video.
        guard CopilotCinematicExportCopy.canExport(layers: heroLayers) else {
            flash(CopilotCinematicExportCopy.nothingToPreviewToast)
            return
        }
        isExportingCinematic = true
        cinematicExportFailed = false
        defer { isExportingCinematic = false }
        do {
            let url = try await AvatarCinematicExporter.exportMP4(
                .init(
                    shape: heroShape,
                    morph: bodyMorph,
                    layers: heroLayers,
                    backdrop: backdrop,
                    bodySex: heroBodySex,
                    bodyPhenotype: heroBodyPhenotype,
                    width: 720,
                    height: 1080,
                    duration: 2.0,
                    fps: 24))
            // 换新前删旧：覆盖 URL 会让上一个文件失联（连点导出场景）
            if let old = cinematicShareURL, old != url {
                try? FileManager.default.removeItem(at: old)
            }
            cinematicShareURL = url
            showCinematicShare = true
            cinematicExportFailed = false
            flash("Preview ready to share")
        } catch {
            cinematicShareURL = nil
            showCinematicShare = false
            cinematicExportFailed = true
            let toast: String
            if let typed = error as? AvatarCinematicExporter.ExportError {
                toast = typed.toastMessage
            } else if let localized = (error as? LocalizedError)?.errorDescription, !localized.isEmpty {
                toast = localized
            } else {
                toast = "Couldn't export preview — try again"
            }
            flash(toast)
            AppLog.error("cinematic export: \(AppLog.errRef(error))", .copilot)
            // Clear failure glyph after toast window so retry looks clean.
            // 代际守卫：连续两次失败时第一个计时器不得提前清掉第二次的失败三角。
            cinematicFailureToken &+= 1
            let token = cinematicFailureToken
            Task {
                try? await Task.sleep(nanoseconds: 3_500_000_000)
                if cinematicFailureToken == token { cinematicExportFailed = false }
            }
        }
    }

    // MARK: - Data helpers

    private var bodyMorph: BodyMorphParams {
        if let p = ownerProfile {
            let m = BodyProfileService.measurements(from: p)
            let shape = BodyProfileService.popularShape(from: p)
            let fine = BodyMorphParams(
                chest: p.fineChest, waist: p.fineWaist,
                hip: p.fineHip, shoulder: 1, height: p.fineHeight)
            return BodyMorphParams.resolve(measurements: m, shape: shape, fineTune: fine)
        }
        return BodyMorphParams.preset(for: vm.bodyShape?.popularCategory ?? .rectangle)
    }

    private func itemNames(for scored: ScoredOutfit) -> [String] {
        let ids = Set(scored.outfit.itemIDs)
        return (vm.wardrobe.items ?? [])
            .filter { ids.contains($0.id.uuidString) }
            .map(\.name)
            .sorted()
    }

    private func checkIn(_ scored: ScoredOutfit) {
        let result = CopilotWoreIt.perform(
            itemIDs: scored.outfit.itemIDs,
            wardrobe: vm.wardrobe,
            context: context)
        switch result {
        case .checkedIn(let n):
            // Re-score so anti-repeat actually applies (toast must not lie).
            runRefresh()
            AppLog.info("ui checkIn \(n)", .copilot)
        case .noResolvablePieces:
            AppLog.notice("ui checkIn unresolved itemIDs", .copilot)
        case .saveFailed:
            AppLog.error("ui checkIn ModelSave failed", .copilot)
        }
        flash(CopilotWoreIt.flashMessage(
            result, antiRepeatEnabled: !DebugSettings.shared.disableAntiRepeat))
    }

    private func runRefresh() {
        vm.wornWithin7DaysIDs = DebugSettings.shared.disableAntiRepeat
            ? [] : CheckInViewModel.recentlyWornIDs(in: context)
        vm.refresh()
    }

    private func flash(_ message: String) {
        flashToken &+= 1
        let token = flashToken
        checkInNote = message
        Task {
            try? await Task.sleep(nanoseconds: 3_500_000_000)
            if flashToken == token { checkInNote = nil }
        }
    }

    private func bootstrap() async {
        // 历史导出扫尾（崩溃/未清理残留）；此刻不可能有在用的导出文件
        AvatarCinematicExporter.sweepTemporaryExports()
        vm.wornWithin7DaysIDs = CheckInViewModel.recentlyWornIDs(in: context)
        await vm.applyWeather(CompositeWeatherProvider.production)
        // Prefer live @Query profile; fall back to context fetch for first paint.
        if let p = ownerProfile {
            _ = vm.applyBodyProfile(p)
        } else {
            _ = vm.loadBodyShape(in: context)
        }
        if !vm.isColdStart {
            vm.fullAuto = true
            vm.refresh()
        }
        AppLog.debug("Copilot hero polished appear items=\(vm.availableItems.count)", .copilot)
    }

    /// After closet city changes (Me → City), refresh climate + looks so °F / outerwear track the new city.
    private func reapplyWeatherAfterCityChange() async {
        await vm.applyWeather(CompositeWeatherProvider.production)
        runRefresh()
        AppLog.info(
            "city climate reapplied hasCity=\(vm.wardrobe.locationCity != nil) temp=\(vm.daytimeTempF)",
            .weather)
    }
}

/// Lightweight Me → Body change signal for Today re-score (not a full profile copy).
struct OwnerBodySnapshot: Equatable {
    var popular: String?
    var sex: String?
    var phenotype: String?
    var bust: Double?
    var waist: Double?
    var hip: Double?
    var highHip: Double?
    var fineChest: Double
    var fineWaist: Double
    var fineHip: Double
    var fineHeight: Double

    init(profile: PersonBodyProfile?) {
        popular = profile?.popularShapeOverrideRaw
        sex = profile?.presentationSexRaw
        phenotype = profile?.presentationPhenotypeRaw
        bust = profile?.bustInches
        waist = profile?.waistInches
        hip = profile?.hipInches
        highHip = profile?.highHipInches
        fineChest = profile?.fineChest ?? 1
        fineWaist = profile?.fineWaist ?? 1
        fineHip = profile?.fineHip ?? 1
        fineHeight = profile?.fineHeight ?? 1
    }
}

/// Empty-look capsule + VoiceOver copy when the hero has nothing on-canvas.
/// Layers that exist but fail to decode still count as empty (slot placeholders only).
enum CopilotEmptyDressOverlay {
    /// Matches `BodyAvatarView.modelCanvas` (width:height = 2:3).
    static let canvasAspectRatio: CGFloat = 2.0 / 3.0
    /// Inset of capsule from the bottom edge of the figure canvas band.
    static let canvasBottomPadding: CGFloat = 28

    /// Capsule host: figure canvas band only — never full stack bottom
    /// (which would cover orbit chrome + fitCaption on short cards).
    enum Placement: Equatable {
        case canvasOnly
        case fullStackBottom
    }

    static let placement: Placement = .canvasOnly

    /// `true` when no layer decodes to an on-canvas image (empty or placeholder-only).
    static func shouldShow(layers: [BodyAvatarLayer]) -> Bool {
        !layers.contains(where: { BodyAvatarView.hasRenderableVisual($0) })
    }

    /// Capsule when hero has no on-canvas garments.
    /// - `lookItemsUnavailable`: selected look resolved to zero wardrobe layers → share
    ///   title recovery phrase (not generic "Undressed · complete a look…").
    ///   Path-only / placeholder layers keep the generic undressed line.
    static func message(isColdStart: Bool, lookItemsUnavailable: Bool = false) -> String {
        if lookItemsUnavailable {
            return "\(CopilotHeroTitle.unavailablePhrase) · undressed"
        }
        return isColdStart
            ? "Model ready · load samples to dress"
            : "Undressed · complete a look to layer clothes"
    }

    /// Height of the top canvas band for a given content width (aspect-fit by width).
    static func canvasBandHeight(forWidth width: CGFloat) -> CGFloat {
        guard width > 0, canvasAspectRatio > 0 else { return 0 }
        return width / canvasAspectRatio
    }

    /// `true` when pinning a capsule to the full stack bottom would sit over
    /// chrome below the figure canvas (orbit / fitCaption).
    static func fullStackBottomWouldCoverChrome(
        stackSize: CGSize,
        chromeMinHeight: CGFloat = 44
    ) -> Bool {
        let canvasH = canvasBandHeight(forWidth: stackSize.width)
        return stackSize.height >= canvasH + chromeMinHeight
    }
}

/// Today "Wore it": resolve wardrobe pieces, record wear, honest flash (no silent no-op).
enum CopilotWoreIt {
    enum Result: Equatable {
        case checkedIn(pieceCount: Int)
        case noResolvablePieces
        case saveFailed
    }

    @discardableResult
    static func perform(
        itemIDs: [String],
        wardrobe: Wardrobe,
        context: ModelContext,
        on date: Date = Date()
    ) -> Result {
        let ids = Set(itemIDs)
        let items = (wardrobe.items ?? []).filter { ids.contains($0.id.uuidString) }
        guard !items.isEmpty else { return .noResolvablePieces }
        guard CheckInService.recordWear(items: items, on: date, in: wardrobe, in: context) != nil
        else { return .saveFailed }
        return .checkedIn(pieceCount: items.count)
    }

    /// `antiRepeatEnabled` mirrors `runRefresh`: when DebugSettings disables anti-repeat,
    /// wornWithin7DaysIDs is empty and pieces are NOT de-prioritized — toast must not claim it.
    static func flashMessage(_ result: Result, antiRepeatEnabled: Bool = true) -> String {
        switch result {
        case .checkedIn(let n):
            return antiRepeatEnabled
                ? "Checked in \(n) pieces · de-prioritized 7 days"
                : "Checked in \(n) pieces"
        case .noResolvablePieces:
            // Shared with CheckInViewModel stale-selection toast (same condition, one copy).
            return CheckInViewModel.staleSelectionMessage
        case .saveFailed:
            return CheckInService.saveFailedMessage
        }
    }
}

/// Hero title copy: wardrobe-resolved names only (never Core outfit count when IDs miss).
/// Stale/unresolved `itemIDs` → empty `heroLayers` + undressed capsule; title must not claim N-piece.
enum CopilotHeroTitle {
    /// Shared recovery phrase for title / empty capsule / fitCaption when selected look is empty.
    static let unavailablePhrase = "Look items unavailable"

    static func text(
        resolvedItemNames: [String],
        hasSelectedSuggestion: Bool,
        hasAnchors: Bool,
        isColdStart: Bool
    ) -> String {
        if hasSelectedSuggestion {
            let names = resolvedItemNames.filter { !$0.isEmpty }
            if !names.isEmpty { return names.joined(separator: " · ") }
            // Unresolved wardrobe IDs (or empty names): do not use scored.outfit.items.count.
            return unavailablePhrase
        }
        if hasAnchors { return "Building your look" }
        if isColdStart { return "Your body, ready to dress" }
        return "Your look for today"
    }
}

/// Cinematic share export VoiceOver — layered proportion video, not try-on.
enum CopilotCinematicExportCopy {
    static let label = "Export layered look preview"
    static let failedLabel = "Export failed, double tap to retry"
    static let hint =
        "Creates a short layered proportion video to share, not photo try-on"
    /// Honest toast when export is attempted with nothing on-canvas.
    static let nothingToPreviewToast = "Nothing on the model to preview"

    /// Film export gate: with zero on-canvas garments the video is basewear-only,
    /// contradicting the "layered look preview" label — same predicate as the
    /// empty-dress capsule.
    static func canExport(layers: [BodyAvatarLayer]) -> Bool {
        !CopilotEmptyDressOverlay.shouldShow(layers: layers)
    }
}

/// Hero wear/fit caption for `BodyAvatarView` (paper-doll layering, not VTON).
enum CopilotHeroFitCaption {
    static func text(
        layers: [BodyAvatarLayer],
        hasSelectedSuggestion: Bool,
        hasAnchors: Bool,
        isColdStart: Bool
    ) -> String {
        if hasSelectedSuggestion {
            let summary = OutfitAvatarComposer.wearSummary(of: layers)
            // Path presence ≠ on-canvas image; require decode success (failed load → placeholders).
            if layers.contains(where: { BodyAvatarView.hasRenderableVisual($0) }) {
                return "\(summary) · proportion guide · not photo try-on"
            }
            if !layers.isEmpty {
                return "\(summary) · add item photos for layered preview"
            }
            // Empty layers under a selected look = unresolved IDs; align with title + capsule.
            return "\(CopilotHeroTitle.unavailablePhrase) · not a photo try-on"
        }
        if hasAnchors {
            let summary = OutfitAvatarComposer.wearSummary(of: layers)
            if summary != "undressed" {
                return "\(summary) · tap Complete to fill the rest"
            }
            return "Tap Complete to fill the rest"
        }
        if isColdStart {
            return "Add pieces or load samples below"
        }
        return "Complete a look to see it here"
    }
}
