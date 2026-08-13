import Testing
import Foundation
@testable import ClosetCore

/// D201：**判定协议冻结了，没人检查它算不算得出来。**
///
/// `MARKET.md` §8 把上线判定现在就固定死（「只能按 §8.5 规则修改」），
/// 理由写得很清楚：没有预注册就等于确认偏误许可证，kill/pivot 永远不触发。
///
/// 但协议是文档，事件是代码，**两者之间没有任何对账**。
/// 删一个事件、从白名单里去掉一个字段，都不会有人红——
/// 而这件事的代价要到**上线第 6 周首判那天**才显形，那时数据已经没了。
///
/// 这是本 session 反复撞见的同一族：**一条被冻结的承诺，没有数据通路的验证。**
struct TelemetryVerdictContractTests {

    /// 五条门槛一条不少（§8.1 那张表加一行，这里必须跟着加）。
    @Test func everyPreRegisteredMetricIsListed() {
        #expect(TelemetryVerdictContract.metrics.count == 5, Comment(rawValue:
            "§8.1 有五条门槛，契约里只有 \(TelemetryVerdictContract.metrics.count) 条"))
        let names = TelemetryVerdictContract.metrics.map(\.name)
        #expect(names.contains { $0.contains("D30 留存") })
        #expect(names.contains { $0.contains("激活率") })
        #expect(names.contains { $0.contains("激活层") })
        #expect(names.contains { $0.contains("wear-as-is") })
        #expect(names.contains { $0.contains("CVR") })
    }

    /// **本波的核心**：每条能算的门槛，它依赖的事件都真的存在。
    @Test func everyRequiredEventExists() {
        let known = Set(TelemetryEvent.allCases.map(\.rawValue))
        for metric in TelemetryVerdictContract.metrics where metric.blockedBy == nil {
            #expect(!metric.events.isEmpty, Comment(rawValue:
                "「\(metric.name)」没被标成 blocked，却一个依赖事件都没写 —— "
                + "那它是靠什么算出来的？"))
            for event in metric.events {
                #expect(known.contains(event.rawValue), Comment(rawValue:
                    "「\(metric.name)」依赖 \(event.rawValue)，而它已经不在事件表里了"))
            }
        }
    }

    /// 依赖的**字段**必须在那个事件的白名单里——白名单会把不在册的键**丢掉**，
    /// 于是字段还在代码里发、数据里却没有。
    @Test func everyRequiredFieldSurvivesTheAllowlist() {
        for metric in TelemetryVerdictContract.metrics where metric.blockedBy == nil {
            for (event, keys) in metric.fields {
                for key in keys {
                    #expect(event.allowedKeys.contains(key), Comment(rawValue:
                        "「\(metric.name)」要 \(event.rawValue).\(key)，"
                        + "而白名单会把它丢掉 —— 发得出去，落不下来"))
                }
            }
        }
    }

    /// 自测：把一个不存在的字段喂进白名单判定，应当抓得到
    ///（防过滤逻辑写坏之后整条空转）。
    @Test func theAllowlistCheckWouldCatchAMissingField() {
        #expect(!TelemetryEvent.copilotAccepted.allowedKeys.contains("ghost_field"))
    }

    /// 真裁决器那条要**逐字**钉住：红队把它定为 copilot 机制成立与否的判据，
    /// 两个字段缺一不可。
    @Test func theMechanismVerdictKeepsBothFields() {
        let metric = TelemetryVerdictContract.metrics
            .first { $0.name.contains("wear-as-is") }
        let fields = metric?.fields[.copilotAccepted] ?? []
        #expect(fields.contains("wear_as_is"), "分不出「原样穿」与「改过再穿」")
        #expect(fields.contains("source"), "分不出「从推送进来」与「自己打开」")
        #expect(TelemetryEvent.copilotAccepted.allowedKeys.isSuperset(of: fields))
    }

    /// 算不出来的那条要**明说原因**，不许留空白冒充没问题。
    @Test func anythingWithoutADataPathSaysWhy() {
        for metric in TelemetryVerdictContract.metrics where metric.events.isEmpty {
            #expect(metric.blockedBy != nil, Comment(rawValue:
                "「\(metric.name)」没有任何事件，也没说为什么 —— 那就是悄悄算不出来"))
        }
    }

    /// sink 必须自己补的那两样要写下来。
    ///
    /// App 这层**刻意不发**装机标识（准 PII，白名单挡在外面，
    /// 而「不运营账号、没有你的副本」是对外承诺过的）。
    /// 代价是留存类指标全靠 sink——接 sink 的人不知道这条，
    /// §8 五条里有三条会在第 6 周悄悄变成算不出来。
    @Test func theSinkSideRequirementsAreWrittenDown() {
        let reqs = TelemetryVerdictContract.sinkRequirements.joined()
        #expect(reqs.contains("装机"), Comment(rawValue: "没写「按装机的标识」这条依赖"))
        #expect(reqs.contains("时间戳"), Comment(rawValue: "没写「事件时间戳」这条依赖"))
    }

    /// **App 这层不许自己发装机标识**——那是隐私姿态的一部分，不是疏忽。
    @Test func noEventCarriesAnInstallIdentifier() {
        let banned = ["install", "device", "user_id", "uid", "distinct", "advertis", "idfa"]
        for event in TelemetryEvent.allCases {
            for key in event.allowedKeys {
                for token in banned {
                    #expect(!key.localizedCaseInsensitiveContains(token), Comment(rawValue:
                        "\(event.rawValue) 的白名单里有 `\(key)` —— "
                        + "装机标识由 sink 生成，App 不传（隐私承诺）"))
                }
            }
        }
    }
}
