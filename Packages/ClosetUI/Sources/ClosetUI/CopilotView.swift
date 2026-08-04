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
    @State private var actions = OutfitActionsViewModel()
    @State private var didBootstrap = false
    @State private var isExportingCinematic = false
    @State private var cinematicShareURL: URL?
    @State private var showCinematicShare = false
    private var debug: DebugSettings { DebugSettings.shared }

    public init(wardrobe: Wardrobe) {
        _vm = State(initialValue: CopilotViewModel(wardrobe: wardrobe))
    }

    private let occasions = ["work", "date", "gala", "casual"]

    public var body: some View {
        NavigationStack {
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
            .background(DS.bg.ignoresSafeArea())
            .navigationTitle("Today")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.large)
            #endif
            .task {
                guard !didBootstrap else { return }
                didBootstrap = true
                await bootstrap()
            }
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
                    fitCaption: nil,
                    showsFitCaption: false,
                    enablesOrbit: true,
                    compactChrome: true,
                    backdrop: heroBackdrop,
                    depthIntensity: .cinematic)
                .padding(.top, 4)
                .padding(.horizontal, 4)
                .frame(minHeight: DS.heroMinHeight)
                .id(heroBackdrop) // 换场合强制重建合成，避免旧帧残留

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
                                Image(systemName: "film")
                                    .font(.body.weight(.semibold))
                            }
                        }
                        .foregroundStyle(DS.ink)
                        .frame(width: 36, height: 36)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .disabled(isExportingCinematic)
                    .accessibilityLabel("Export cinematic preview")
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
            .sheet(isPresented: $showCinematicShare) {
                if let url = cinematicShareURL {
                    ShareSheet(items: [url])
                }
            }

            VStack(spacing: 6) {
                Text(heroTitle)
                    .font(.headline)
                    .foregroundStyle(DS.ink)
                    .multilineTextAlignment(.center)
                if !heroSubtitle.isEmpty {
                    Text(heroSubtitle)
                        .font(.caption)
                        .foregroundStyle(DS.muted)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                }
            }
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
                    .frame(width: 28, height: 28)
                    .background(DS.bg)
                    .clipShape(Circle())
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
                    .frame(width: 28, height: 28)
                    .background(DS.bg)
                    .clipShape(Circle())
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
        if let scored = vm.selectedSuggestion {
            let names = itemNames(for: scored)
            if names.isEmpty { return "\(scored.outfit.items.count)-piece look" }
            return names.joined(separator: " · ")
        }
        if !vm.anchorIDs.isEmpty { return "Building your look" }
        if vm.isColdStart { return "Your body, ready to dress" }
        return "Your look for today"
    }

    private var heroSubtitle: String {
        if vm.selectedSuggestion != nil {
            return "Proportion guide · not a photo try-on"
        }
        if !vm.anchorIDs.isEmpty {
            return "Tap Complete to fill the rest"
        }
        if vm.isColdStart {
            return "Add pieces or load samples below"
        }
        return "Complete a look to see it here"
    }

    private var heroShape: PopularShape {
        if let pid = vm.wardrobe.owner?.id {
            let profiles = (try? context.fetch(FetchDescriptor<PersonBodyProfile>())) ?? []
            if let p = profiles.first(where: { $0.personID == pid }),
               let s = BodyProfileService.displayPopularShape(from: p) {
                return s
            }
        }
        return vm.bodyShape?.popularCategory ?? .rectangle
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
            Text("Load sample pieces, or add from Closet. Then anchor one item or use full-auto.")
                .font(.caption)
                .foregroundStyle(DS.muted)
            Button {
                let n = DemoSeedService.seedIfEmpty(vm.wardrobe, in: context)
                flash(n == 0 ? "Closet already has pieces." : "Added \(n) samples.")
                vm.fullAuto = true
                vm.refresh()
            } label: {
                Text("Load sample pieces")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(DS.accent)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: DS.radius, style: .continuous))
            }
            .buttonStyle(.plain)
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
                    depthIntensity: .off)
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
        Text(text)
            .font(.caption.weight(.medium))
            .foregroundStyle(DS.accent)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(DS.accent.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: DS.radius, style: .continuous))
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
        isExportingCinematic = true
        defer { isExportingCinematic = false }
        do {
            let url = try await AvatarCinematicExporter.exportMP4(
                .init(
                    shape: heroShape,
                    morph: bodyMorph,
                    layers: heroLayers,
                    backdrop: backdrop,
                    width: 720,
                    height: 1080,
                    duration: 2.0,
                    fps: 24))
            cinematicShareURL = url
            showCinematicShare = true
            flash("Preview ready to share")
        } catch {
            flash("Couldn’t export preview")
            AppLog.error("cinematic export: \(error)", .copilot)
        }
    }

    // MARK: - Data helpers

    private var bodyMorph: BodyMorphParams {
        if let pid = vm.wardrobe.owner?.id {
            let profiles = (try? context.fetch(FetchDescriptor<PersonBodyProfile>())) ?? []
            if let p = profiles.first(where: { $0.personID == pid }) {
                let m = BodyProfileService.measurements(from: p)
                let shape = BodyProfileService.popularShape(from: p)
                let fine = BodyMorphParams(
                    chest: p.fineChest, waist: p.fineWaist,
                    hip: p.fineHip, shoulder: 1, height: p.fineHeight)
                return BodyMorphParams.resolve(measurements: m, shape: shape, fineTune: fine)
            }
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
        let ids = Set(scored.outfit.itemIDs)
        let items = (vm.wardrobe.items ?? []).filter { ids.contains($0.id.uuidString) }
        guard !items.isEmpty else { return }
        _ = CheckInService.recordWear(items: items, on: Date(), in: vm.wardrobe, in: context)
        vm.wornWithin7DaysIDs = CheckInViewModel.recentlyWornIDs(in: context)
        flash("Checked in \(items.count) pieces · de-prioritized 7 days")
        AppLog.info("ui checkIn \(items.count)", .copilot)
    }

    private func runRefresh() {
        vm.wornWithin7DaysIDs = DebugSettings.shared.disableAntiRepeat
            ? [] : CheckInViewModel.recentlyWornIDs(in: context)
        vm.refresh()
    }

    private func flash(_ message: String) {
        checkInNote = message
        Task {
            try? await Task.sleep(nanoseconds: 3_500_000_000)
            if checkInNote == message { checkInNote = nil }
        }
    }

    private func bootstrap() async {
        vm.wornWithin7DaysIDs = CheckInViewModel.recentlyWornIDs(in: context)
        await vm.applyWeather(CityClimateWeatherProvider())
        if let pid = vm.wardrobe.owner?.id {
            let profiles = (try? context.fetch(FetchDescriptor<PersonBodyProfile>())) ?? []
            if let p = profiles.first(where: { $0.personID == pid }) {
                vm.bodyShape = BodyProfileService.bodyShape(from: p)
            }
        }
        if !vm.isColdStart {
            vm.fullAuto = true
            vm.refresh()
        }
        AppLog.debug("Copilot hero polished appear items=\(vm.availableItems.count)", .copilot)
    }
}
