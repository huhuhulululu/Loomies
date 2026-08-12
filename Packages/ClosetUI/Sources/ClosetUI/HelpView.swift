import SwiftUI
import ClosetCore

/// 帮助与反馈 + FAQ（§10.6 产品外壳）。文案唯一真相在 `ClosetCore.ComplianceCopy`，
/// 出网面清单来自 `NetworkSurfaceCatalog`（有对账测试：新增出网面而未披露即红）。
public struct HelpView: View {
    public init() {}

    public var body: some View {
        List {
            Section("Questions") {
                ForEach(ComplianceCopy.faq) { entry in
                    DisclosureGroup(entry.question) {
                        Text(entry.answer)
                            .font(.callout)
                            .foregroundStyle(DS.muted)
                            .padding(.vertical, 2)
                    }
                    .accessibilityHint("Shows the answer")
                }
            }
            Section {
                ForEach(NetworkSurfaceCatalog.surfaces) { surface in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(surface.title).font(.headline)
                        Text(surface.sends).font(.caption)
                        Text(surface.trigger).font(.caption2).foregroundStyle(DS.muted)
                        Text(surface.optOut).font(.caption2).foregroundStyle(DS.muted)
                        Text(surface.hosts.joined(separator: ", "))
                            .font(.caption2).foregroundStyle(DS.muted)
                    }
                    .padding(.vertical, 2)
                    .accessibilityElement(children: .combine)
                }
            } header: {
                Text("What leaves my device")
            } footer: {
                Text("Everything else — photos, item names, looks, body measurements — stays on this device.")
            }
            Section("Policies") {
                // 应用内全文，不外链到尚不存在的域名（死链 = 不诚实）
                ForEach(ComplianceCopy.policyDocuments) { doc in
                    NavigationLink(doc.title) { PolicyDocumentView(document: doc) }
                }
            }
            Section(ComplianceCopy.feedbackTitle) {
                Text(ComplianceCopy.feedbackBody)
                    .font(.caption).foregroundStyle(DS.muted)
            }
        }
        .navigationTitle("Help & FAQ")
    }
}


/// 政策全文阅读器（应用内，无网络依赖）。
public struct PolicyDocumentView: View {
    let document: ComplianceCopy.PolicyDocument

    public init(document: ComplianceCopy.PolicyDocument) { self.document = document }

    public var body: some View {
        List {
            ForEach(document.sections, id: \.heading) { section in
                VStack(alignment: .leading, spacing: 6) {
                    Text(section.heading).font(.headline)
                    Text(section.body).font(.callout).foregroundStyle(DS.muted)
                }
                .padding(.vertical, 2)
                .accessibilityElement(children: .combine)
            }
            Section {
                Text("Last updated \(document.lastUpdated)")
                    .font(.caption2).foregroundStyle(DS.muted)
            }
        }
        .navigationTitle(document.title)
    }
}
