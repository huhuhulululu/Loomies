import SwiftUI
import SwiftData
import ClosetModel
import ClosetCore

/// Today 首屏 = **Avatar + 今日 look**（方案 B）+ copilot。
/// 视觉：大人体 + 叠衣；机制：锚定 → 补全（D19），非 VTON。
public struct CopilotView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var vm: CopilotViewModel
    @State private var checkInNote: String?
    /// Toast 代际：同文案连发时旧计时器不得提前清掉新 toast（按值判等无法区分代）。
    @State private var flashToken = 0
    @State private var showCheckInSheet = false
    /// 冷启动「真实起步」路径：直接开入库面（DESIGN §475 双路径之一）
    @State private var showAddPieceSheet = false
    /// 毕业时刻只出一次——看过就记住（跨启动）。
    @AppStorage("loomies.activation.readyMomentSeen") private var hasSeenReadyMoment = false
    /// 早安提醒的邀请**只问一次**（D140）——iOS 的权限弹窗一辈子只有一次机会，
    /// 反复推销的结果是用户把整个 App 的通知永久关掉。
    @AppStorage(DailyRitual.inviteAskedDefaultsKey) private var nudgeInviteAsked = false
    @State private var nudgeInviteBusy = false
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
        // 默认场合来自 onboarding 的「场合构成」（D97）；推导收在 forToday 里，
        // View 与测试走同一条路径，回归门才真的守得住（D98）
        _vm = State(initialValue: CopilotViewModel.forToday(wardrobe: wardrobe))
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
                .sheet(isPresented: $showCheckInSheet) {
                    CheckInView(wardrobe: vm.wardrobe) { note in flash(note) }
                } // 关闭后刷新：防重复窗口立即生效
                .sheet(isPresented: $showAddPieceSheet) {
                    AddPieceSheet(wardrobe: vm.wardrobe) { note in flash(note) }
                }
                .onChange(of: showAddPieceSheet) { _, open in
                    // 关闭后立即重算：新入库的件应当马上体现在进度与里程碑上
                    if !open { runRefresh() }
                }
                .onChange(of: showCheckInSheet) { _, open in
                    if !open {
                        vm.wornWithin7DaysIDs = CheckInViewModel.recentlyWornIDs(in: context)
        vm.reloadToday(in: context)   // D116：重开 App 也记得今天定过什么
                        runRefresh()
                    }
                }
                .onChange(of: vm.wardrobe.locationCity) { _, _ in
                    Task { await reapplyWeatherAfterCityChange() }
                }
                .onChange(of: ownerBodySnapshot) { _, _ in
                    reapplyBodyProfileIfNeeded()
                }
                // D136：回到前台就重读「今天穿了什么」。
                //
                // 周二晚打了卡、周三早上被提醒叫醒打开 App——顶部却还写着
                // 「今天已定：Navy Blazer · Chinos」，那是昨天的。
                // 而早安提醒恰恰把用户导向这条路径。
                .onChange(of: scenePhase) { _, phase in
                    guard phase == .active else { return }
                    vm.reloadToday(in: context)
                    vm.wornWithin7DaysIDs = CheckInViewModel.recentlyWornIDs(in: context)
                }
        }
    }

    /// Today → Favorites entry (toolbar heart). Kept public for journey tests.
    public static let favoritesToolbarAccessibilityLabel = "Favorites"

    /// A11Y: look-pager chevrons — visual stays small, hit target meets the
    /// 44pt HIG minimum. `nonisolated` so tests can pin without MainActor hops.
    nonisolated static let lookPagerChevronVisualSize: CGFloat = 28
    nonisolated static let lookPagerChevronHitArea: CGFloat = 44

    /// D116：今天已经定了穿什么。
    ///
    /// 此前打完卡只有一条 3.5 秒的 flash chip，随后 Today 立刻摆回**一套你没穿的**衣服——
    /// 用户当天最后一个动作被当场抹掉，中午再打开完全看不出自己定过了。
    /// 数据从库里回读（`reloadToday`），所以它扛得住重启。
    private var settledBand: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.seal.fill")
                .foregroundStyle(DS.accent)
            VStack(alignment: .leading, spacing: 2) {
                Text("Today: settled")
                    .font(DS.Text.sectionTitle)
                    .foregroundStyle(DS.ink)
                Text(vm.todayWornNames.joined(separator: " · "))
                    .font(DS.Text.body)
                    .foregroundStyle(DS.muted)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(DS.surface)
        .clipShape(RoundedRectangle(cornerRadius: DS.radius))
        .overlay(
            RoundedRectangle(cornerRadius: DS.radius)
                .strokeBorder(DS.hairline, lineWidth: 1))
        .padding(.horizontal, 16)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "Today settled. Wearing \(vm.todayWornNames.joined(separator: ", "))")
    }

    private var todayScrollContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if !vm.todayWornNames.isEmpty { settledBand }
                // D140：邀请挂在**自己的**条件上。D134 的错位就发生在这个文件里——
                // 一张卡片插进 if/else 中间，`else` 改挂到了它头上。
                if showsNudgeInvite { nudgeInviteCard }
                heroCard
                // D119：阶梯此前只在 <8 件时出现，而北极星区间正好从 8 开始——
                // 用户在 8→20 这段完全没人告诉他还差什么。进度与里程碑陪到 20，
                // 双路径 CTA 仍只在冷启动出现（那两条是「怎么起步」，不是「还差多少」）。
                // D138：阶梯问的是「衣柜数字化到什么程度了」——那是**总件数**，
                // 不该随洗衣浮动：25 件的柜送洗 6 件就被推回「再加几件」，
                // 而用户什么都没少，只是在洗。
                //（`isColdStart` 问的是另一个问题——「今天拼不拼得出」——
                //  那才该看可用件。两个问题不同，判据自然不同。）
                if ActivationProgress.showsLadder(itemCount: vm.totalItemCount) {
                    coldStartBanner
                } else if !hasSeenReadyMoment, !vm.suggestions.isEmpty {
                    // 「你的衣柜可以天天给你出主意了」这句话，
                    // 不能出现在一个此刻拼不出任何一套的屏幕上（D138）
                    readyMoment
                }
                controlsCard
                if shouldShowAnchors { anchorSection }
                // D134：D117 把 `measureInviteRow` 插进了 if/else 中间，
                // `else` 于是改挂在 `showMeasureInvite` 上——**有推荐的正常屏
                // 也会在下面渲染一张「没有匹配」的卡片**。
                // 两件事本来就无关，分开写，不再靠 else 链耦合。
                if !vm.suggestions.isEmpty {
                    otherLooksSection
                } else if !vm.statusMessage.isEmpty && !vm.isColdStart && !vm.isRefreshing {
                    emptyLooksNote
                }
                if showMeasureInvite { measureInviteRow }
                if let checkInNote {
                    feedbackChip(checkInNote)
                }
            }
            // D136：提醒此前只在一次性 bootstrap 里排——加到第 8 件的当天不排，
            // 砍回 3 件仍照排。「配不配打扰用户」取决于衣柜此刻的样子。
            .onChange(of: vm.availableItems.count) { _, count in
                Task { await DailyRitualScheduler.reschedule(availableItemCount: count) }
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
                // D117：第一屏那个模特是**陌生人**，而从 Today 没有任何路径把它
                // 变成「像我」——用户得自己翻到 Me → Body 才发现能改。
                // BODY-AVATAR-USER-FLOW §5.3 本来就规定「一步到 Me → Body」。
                .overlay(alignment: .topLeading) { editBodyAffordance }
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
                    .padding(4)
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
            // D121：主视觉标题此前是 `.headline`（17pt）——和列表行一样大。
            // 用户第一眼落在这里，它得像个标题。
            Text(heroTitle)
                .font(DS.Text.display)
                .foregroundStyle(DS.ink)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
                .padding(.top, 6)

            HStack(spacing: 12) {
                metaPill(
                    icon: "cloud.sun",
                    text: CopilotViewModel.tempPillText(
                        resolved: vm.hasResolvedWeather, temp: vm.daytimeTempF))
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
                // D89：防重复硬门被降级时必须说明——否则这几件刚穿过的又出现在
                // 建议里，与「de-prioritized 7 days」的打卡回执自相矛盾
                if vm.repeatGateRelaxed {
                    Text(CandidateFilter.repeatRelaxedCaption)
                        .font(.caption2)
                        .foregroundStyle(DS.ink.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .accessibilityLabel(CandidateFilter.repeatRelaxedCaption)
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 4)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(
                // D137：与 pill 同源——不得一边显示「—°F」一边念出伪造的 70
                "Weather \(CopilotViewModel.tempAccessibilityPhrase(resolved: vm.hasResolvedWeather, temp: vm.daytimeTempF)), \(vm.weatherSourceLabel)"
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
        // D115：场合辉光进设计系统（`Palette.occasionGlow`），深色下不再是一套写死的浅色。
        let c = DS.occasionGlow(b.rawValue).opacity(0.55)
        return LinearGradient(colors: [c, c.opacity(0.15), c], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    private func heroCardWash(_ b: AvatarBackdrop) -> Color { DS.occasionGlow(b.rawValue) }

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

    /// 冷启动横幅（D91，缺口 #14）。DESIGN §475 要的三件：**双路径空状态**
    /// （真实起步 / 先看效果）、**预赋进度**（答完引导即 20%）、**场合里程碑即时兑现**。
    /// 里程碑文案是承诺——`ActivationProgress` 只让它说挣来的那部分。
    /// D119：跨过 20 件那一下的**毕业时刻**。此前横幅只是静默消失——
    /// 用户为之努力了二十件，产品一句话都没说。只出一次（看过就记住）。
    private var readyMoment: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(ActivationProgress.readyHeadline, systemImage: "checkmark.seal.fill")
                .font(DS.Text.sectionTitle)
                .foregroundStyle(DS.accent)
            Text(ActivationProgress.readyBody(itemCount: vm.availableItems.count))
                .font(DS.Text.body)
                .foregroundStyle(DS.muted)
            Button("Got it") { hasSeenReadyMoment = true }
                .font(.caption.weight(.medium))
                .foregroundStyle(DS.accent)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DS.accent.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: DS.radiusLg, style: .continuous))
        .padding(.horizontal, 16)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(ActivationProgress.readyHeadline). "
            + ActivationProgress.readyBody(itemCount: vm.availableItems.count))
    }

    /// 该不该开口问「明早叫你一次？」（D140）。判据全在 `DailyRitual` 里，
    /// 这里只负责把此刻的现状递过去——视图不自己发明规则。
    private var showsNudgeInvite: Bool {
        DailyRitual.shouldInvite(
            alreadyEnabled: DailyRitualScheduler.isEnabled,
            alreadyAsked: nudgeInviteAsked,
            availableItemCount: vm.availableItems.count,
            confirmedItemCount: vm.totalItemCount,
            settledToday: !vm.todayWornNames.isEmpty)
    }

    /// 每日回访的邀请卡。此前这个能力**只有翻进 Me → Daily 的人才知道它存在**，
    /// 而 MARKET §8.1 的 D30 证伪线整个押在它上面。
    ///
    /// 问的时机是用户**刚打完卡**那一秒：今天这一身定下来了，
    /// 「明早还要不要我叫你一次」在那时才是顺理成章的一句话。
    /// 两个按钮都记成「问过了」——包括「不用」，那扇门只敲一次。
    private var nudgeInviteCard: some View {
        VStack(alignment: .leading, spacing: DS.Space.s) {
            Label(DailyRitual.inviteHeadline, systemImage: "sun.horizon")
                .font(DS.Text.sectionTitle)
                .foregroundStyle(DS.accent)
            Text(DailyRitual.permissionRationale)
                .font(DS.Text.body)
                .foregroundStyle(DS.muted)
            HStack(spacing: DS.Space.l) {
                Button(DailyRitual.inviteAcceptLabel(hour: DailyRitualScheduler.hour)) {
                    acceptNudgeInvite()
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(DS.accent)
                .disabled(nudgeInviteBusy)
                Button(DailyRitual.inviteDeclineLabel) { nudgeInviteAsked = true }
                    .font(.caption)
                    .foregroundStyle(DS.muted)
            }
            Text(DailyRitual.inviteFootnote)
                .font(DS.Text.meta)
                .foregroundStyle(DS.muted)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DS.accent.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: DS.radiusLg, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(DailyRitual.inviteHeadline). \(DailyRitual.permissionRationale)")
    }

    /// 接受。先记「问过了」再去要权限——用户在系统弹窗上点了拒绝，
    /// 这张卡也不该在下一次打卡时卷土重来。
    private func acceptNudgeInvite() {
        nudgeInviteAsked = true
        nudgeInviteBusy = true
        let count = vm.availableItems.count
        Task {
            let granted = await DailyRitualScheduler.enable(availableItemCount: count)
            nudgeInviteBusy = false
            // 拒绝了就说清楚它没开成——静默失败会让用户以为明早会响
            flash(granted
                  ? "Morning nudge on — \(DailyRitual.hourLabel(DailyRitualScheduler.hour))."
                  : "Notifications are off for Loomies in iOS Settings.")
        }
    }

    private var coldStartBanner: some View {
        // 三处必须读**同一个集合**：进度条、里程碑、isColdStart 门。
        // 此前进度条用 wardrobe.items（含在洗/外借），门用 availableItems——
        // 同一张横幅能同时显示「100% ready」和「你还在冷启动」（D98）。
        let items = vm.availableItems
        let candidates = items.map { $0.toCandidateItem() }
        let count = items.count
        // 能走到 Today 就说明引导已完成（app-shell 无 active 衣柜时呈现 Onboarding）
        let fraction = ActivationProgress.fraction(itemCount: count)
        let milestone = ActivationProgress.headlineMilestone(
            items: candidates, statedOccasion: vm.wardrobe.owner?.primaryOccasionRaw)

        return VStack(alignment: .leading, spacing: 10) {
            Text("Get a full look in a minute")
                .font(DS.Text.sectionTitle)
                .foregroundStyle(DS.ink)

            // 预赋进度：零件也不是 0%，但文案不得暗示「完成了」
            VStack(alignment: .leading, spacing: 4) {
                ProgressView(value: fraction)
                    .tint(DS.accent)
                Text(ActivationProgress.caption(itemCount: count))
                    .font(.caption2)
                    .foregroundStyle(DS.muted)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(
                "Closet setup \(Int(fraction * 100)) percent. "
                + ActivationProgress.caption(itemCount: count))

            // 场合里程碑：兑现了就说兑现，没兑现就点名还缺什么槽位
            if let milestone {
                VStack(alignment: .leading, spacing: 2) {
                    Label(milestone.headline, systemImage: milestone.canDressOnce
                          ? "checkmark.seal.fill" : "circle.dashed")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(milestone.canDressOnce ? DS.accent : DS.muted)
                    Text(milestone.nextStep)
                        .font(.caption2)
                        .foregroundStyle(DS.muted)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(milestone.headline). \(milestone.nextStep)")
            }

            // 路径一/二只在冷启动出现：它们回答「怎么起步」，
            // 而 8→20 这段用户要的是「还差多少」。
            if vm.isColdStart {
            // 路径一：真实起步（DESIGN §475「拍下今天这身，30 秒入库 3 件」）
            Button { showAddPieceSheet = true } label: {
                Text(CopilotColdStartCopy.realStartTitle)
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(DS.accent)
                    .foregroundStyle(DS.onAccent)
                    .clipShape(RoundedRectangle(cornerRadius: DS.radius, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityHint(CopilotColdStartCopy.realStartAccessibilityHint)

            // 路径二：先看效果（示例衣橱，不是用户的照片——VO 与 Me → Demo 同口径）
            Button {
                // 横幅在 1-7 件时也显示，而 seedIfEmpty 对非空衣柜是 no-op ——
                // 那个区间里这颗按钮点了什么都不会发生（D98）。用 seed（与 Closet 空态一致）。
                let outcome = DemoSeedService.seed(vm.wardrobe, in: context)
                flash(outcome.flashMessage)
                // Only auto-refresh when pieces actually landed (save fail keeps cold-start honest).
                if case .added = outcome {
                    vm.fullAuto = true
                    vm.refresh()
                }
            } label: {
                Text("Load samples")
                    .font(.subheadline.weight(.medium))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(DS.accent.opacity(0.12))
                    .foregroundStyle(DS.accent)
                    .clipShape(RoundedRectangle(cornerRadius: DS.radius, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityHint(DemoSeedService.loadButtonAccessibilityHint)
            }   // if vm.isColdStart
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
                .foregroundStyle(DS.onAccent)
                .clipShape(RoundedRectangle(cornerRadius: DS.radius, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(vm.isRefreshing)

            // 手动打卡次级入口（D85 波 D）：copilot 建议之外，用户自己挑今天穿了什么
            Button(CheckInView.entryButtonTitle) { showCheckInSheet = true }
                .font(.caption.weight(.semibold))
                .foregroundStyle(DS.accent)
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)
                .accessibilityHint("Pick pieces you wore today")

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
                    .font(DS.Text.sectionTitle)
                    .foregroundStyle(DS.ink)
                Spacer()
                if !vm.anchorIDs.isEmpty {
                    Button("Clear") { vm.clearAnchors() }
                        .font(.caption.weight(.medium))
                        .foregroundStyle(DS.accent)
                }
            }
            // D126：互斥的两件不能同时锚定（否则永远拼不出任何一套）——
            // 后选的替换先选的同类，而**替换要说出来**，
            // 静默替换会让用户以为自己点漏了。
            if let note = vm.anchorNote {
                Label(note, systemImage: "arrow.left.arrow.right")
                    .font(DS.Text.meta)
                    .foregroundStyle(DS.muted)
                    .accessibilityLabel(note)
            }
            // D131：锚定件与今天不搭时如实说一句——**不筛掉它**。
            // 用户说「我今天就要穿这件」，产品不该反过来教育他；
            // 但一声不吭会让他以为 App 觉得这样合适，或以为过滤坏了。
            if let advisory = vm.anchorAdvisory {
                Label(advisory, systemImage: "info.circle")
                    .font(DS.Text.meta)
                    .foregroundStyle(DS.muted)
                    .accessibilityLabel(advisory)
            }
            if vm.availableItems.isEmpty {
                Text("Add from Closet, or load samples above.")
                    .font(.caption)
                    .foregroundStyle(DS.muted)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    // D125：同试衣间——铺整柜单品必须惰性，否则百件衣柜
                    // 一进 Today 就构建百个 chip（每个都要解码缩略图）。
                    LazyHStack(spacing: 10) {
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
                VStack(alignment: .leading, spacing: 4) {
                    Text(itemNames(for: scored).joined(separator: " · "))
                        .font(DS.Text.rowTitle)
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
                    // D117：合身结论进决策现场。MARKET §2 判定这是竞品都没占的
                    // 唯一纵深，而它此前只挂在网格徽章和详情页上——用户决定
                    // 「今天穿不穿这套」的那一刻，屏幕上没有这条信息。
                    if let fit = fitMark(for: scored) {
                        Label(fit.summary, systemImage: "ruler")
                            .font(.caption2)
                            .foregroundStyle(fit.verdict == .fitted ? DS.muted : .orange)
                            .lineLimit(1)
                            .accessibilityLabel("Fit: \(fit.summary)")
                    }
                    // 决定穿这套之后的下一个动作是去拿——省一次逐件跳详情（§10.3）
                    if let where_ = storageHint(for: scored) {
                        Label(where_, systemImage: "shippingbox")
                            .font(.caption2)
                            .foregroundStyle(DS.muted)
                            .lineLimit(1)
                            .accessibilityLabel("Stored: \(where_)")
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
                .padding(.vertical, 12)
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

    /// 头像上的「这不像我」入口。做成小而明确的可点区域而不是整块可点——
    /// 整块可点会跟已有的 orbit 手势打架（转身也会被当成点击）。
    @ViewBuilder
    private var editBodyAffordance: some View {
        if let person = vm.wardrobe.owner {
            NavigationLink {
                BodyProfileView(personID: person.id)
            } label: {
                Label("Make it look like me", systemImage: "person.crop.circle.badge.plus")
                    .font(.caption2.weight(.medium))
                    .labelStyle(.titleAndIcon)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.ultraThinMaterial, in: Capsule())
                    .foregroundStyle(DS.ink)
            }
            .buttonStyle(.plain)
            .padding(12)
            .accessibilityLabel("Edit your body shape and measurements")
        }
    }

    /// 有建议、有身体档案，却一条合身结论都给不出 = 全套没有实测。
    /// 此时给**入口**而不是留白：走快速添加建库的用户否则永远不知道
    /// 这条差异化能力存在（MARKET §2：合身是竞品都没占的唯一纵深）。
    private var showMeasureInvite: Bool {
        !vm.suggestions.isEmpty
            && ownerProfile != nil
            && vm.suggestions.allSatisfy { fitMark(for: $0) == nil }
    }

    private var measureInviteRow: some View {
        NavigationLink {
            // 不另建页面：现有衣柜网格点进详情就能填实测
            ClosetGridView(wardrobe: vm.wardrobe)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "ruler")
                Text(OutfitFitMark.measureInvite)
                    .font(DS.Text.body)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.caption2)
            }
            .foregroundStyle(DS.muted)
            .padding(12)
            .background(DS.surface)
            .clipShape(RoundedRectangle(cornerRadius: DS.radius))
            .overlay(
                RoundedRectangle(cornerRadius: DS.radius)
                    .strokeBorder(DS.hairline, lineWidth: 1))
            .padding(.horizontal, 16)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(OutfitFitMark.measureInvite)
    }

    /// 整套的合身结论（D117）。取最紧那件——决定穿不穿的是最勒的那一件。
    /// 无身体档案 / 全套无实测 → nil（不编）。
    private func fitMark(for scored: ScoredOutfit) -> OutfitFitMark.Mark? {
        let ids = Set(scored.outfit.itemIDs)
        let items = (vm.wardrobe.items ?? []).filter { ids.contains($0.id.uuidString) }
        return OutfitFitMark.tightest(items: items, profile: ownerProfile)
    }

    /// 「去哪拿」提示（D90）。无一件标了位置 → nil，不显示空行。
    private func storageHint(for scored: ScoredOutfit) -> String? {
        OutfitStorageHint.text(
            forItemIDs: scored.outfit.itemIDs, in: vm.wardrobe.items ?? [])
    }

    private func itemNames(for scored: ScoredOutfit) -> [String] {
        let ids = Set(scored.outfit.itemIDs)
        return (vm.wardrobe.items ?? [])
            .filter { ids.contains($0.id.uuidString) }
            .map(\.name)
            .sorted()
    }

    private func checkIn(_ scored: ScoredOutfit) {
        // D116：走 VM 的唯一路径——采纳信号（§8.1 判定协议量的那件事）
        // 与「今天穿了什么」的回读都在里面，绕过去两样都会丢。
        // wearAsIs：用户没换过任何一件时才算「原样穿」。
        let asIs = vm.anchorIDs.isEmpty
        let result = vm.recordWearDetailed(scored, in: context, wearAsIs: asIs)
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
        // D125：**先把该画的画出来**。目录对账与临时目录扫尾都要扫盘，
        // 而它们此前挡在首屏之前——用户打开 App 看到的第一件事是等待，
        // 而这两件事跟「今天穿什么」一点关系都没有。
        // 让出一次主线程即可：SwiftUI 会先完成本帧再回来。
        vm.wornWithin7DaysIDs = CheckInViewModel.recentlyWornIDs(in: context)
        vm.reloadToday(in: context)   // D116：重开 App 也记得今天定过什么
        // D118：衣柜够用时（重新）排每日回访。放在这里而不是设置页，
        // 是因为「配不配打扰用户」取决于衣柜此刻的状态，而不是用户上次开开关的状态。
        await DailyRitualScheduler.reschedule(
            availableItemCount: vm.availableItems.count)
        await vm.applyWeather(CompositeWeatherProvider.production)
        // 首屏已经画完，现在再做扫盘的家务事。
        await Task.yield()
        AvatarCinematicExporter.sweepTemporaryExports()   // 历史导出残留回收
        ImageReconcileService.reconcile(in: context)      // 图片目录 ↔ DB 对账
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
            let noun = n == 1 ? "piece" : "pieces"
            return antiRepeatEnabled
                ? "Checked in \(n) \(noun) · de-prioritized 7 days"
                : "Checked in \(n) \(noun)"
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
