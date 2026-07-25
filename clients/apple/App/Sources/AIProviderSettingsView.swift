import HealthMonitorCore
import SwiftUI

struct AIProviderSettingsView: View {
    @Environment(AIProviderProfileStore.self) private var profileStore
    @Environment(AIHealthSummarySharingStore.self) private var healthSummarySharing
    @State private var presentedProfile: AIProviderProfile?
    @State private var isAddingQwen = false
    @State private var errorMessage: String?
    @State private var isConfirmingHealthSharing = false
    private let secrets = AIProviderSecretCoordinator()

    var body: some View {
        NavigationStack {
            List {
                Section("活动 Provider") {
                    Button {
                        select(nil)
                    } label: {
                        selectionRow(title: "不使用 AI", isSelected: profileStore.activeProfileID == nil)
                    }

                    if profileStore.profiles.isEmpty {
                        ContentUnavailableView(
                            "尚未配置 AI Provider",
                            systemImage: "key.horizontal",
                            description: Text("添加 Qwen API Key 后可进行文字餐食识别；手动记录始终可用。")
                        )
                    } else {
                        ForEach(profileStore.profiles) { profile in
                            Button {
                                select(profile.id)
                            } label: {
                                selectionRow(
                                    title: profile.displayName,
                                    subtitle: profileSubtitle(profile),
                                    isSelected: profileStore.activeProfileID == profile.id
                                )
                            }
                            .swipeActions {
                                Button("删除", role: .destructive) {
                                    delete(profile)
                                }
                                Button("编辑") {
                                    presentedProfile = profile
                                }
                                .tint(.blue)
                            }
                        }
                    }
                }

                Section("隐私") {
                    Text("Profile 只保存名称、HTTPS 地址、模型和超时。API Key 单独保存在本机 ThisDeviceOnly Keychain，不进入数据库、日志或导出。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("健康摘要共享") {
                    Toggle("允许发送聚合健康摘要", isOn: healthSummarySharingBinding)
                    Text("默认关闭。开启后，每次请求仍会先预览，只包含今日步数、活动能量、锻炼分钟和最近睡眠日分钟；不包含原始 HealthKit 样本。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("AI 设置")
            .toolbar {
                Button {
                    isAddingQwen = true
                } label: {
                    Label("添加 Qwen", systemImage: "plus")
                }
            }
            .sheet(isPresented: $isAddingQwen) {
                QwenProfileEditorView(profile: nil)
            }
            .sheet(item: $presentedProfile) { profile in
                QwenProfileEditorView(profile: profile)
            }
            .alert("AI 设置错误", isPresented: errorBinding) {
                Button("确定", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "未知错误")
            }
            .alert("允许向第三方 AI 发送健康摘要？", isPresented: $isConfirmingHealthSharing) {
                Button("取消", role: .cancel) {}
                Button("允许发送") {
                    healthSummarySharing.setEnabled(true)
                }
            } message: {
                Text("开启后，步数、活动能量、锻炼分钟和最近睡眠日分钟可能发送到你选择的 Provider。每次发送前仍需确认。")
            }
        }
    }

    private var healthSummarySharingBinding: Binding<Bool> {
        Binding(
            get: { healthSummarySharing.isEnabled },
            set: { enabled in
                if enabled {
                    isConfirmingHealthSharing = true
                } else {
                    healthSummarySharing.setEnabled(false)
                }
            }
        )
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )
    }

    private func selectionRow(title: String, subtitle: String? = nil, isSelected: Bool) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(title).foregroundStyle(.primary)
                if let subtitle {
                    Text(subtitle).font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
            if isSelected {
                Image(systemName: "checkmark").foregroundStyle(.green)
            }
        }
    }

    private func profileSubtitle(_ profile: AIProviderProfile) -> String {
        let keyStatus = secrets.hasAPIKey(profileID: profile.id) ? "密钥已保存" : "缺少密钥"
        return "\(profile.textModel ?? profile.kind.displayName) · \(keyStatus)"
    }

    private func select(_ profileID: UUID?) {
        do {
            if let profileID, !secrets.hasAPIKey(profileID: profileID) {
                throw AIProviderError.missingAPIKey
            }
            try profileStore.select(profileID: profileID)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func delete(_ profile: AIProviderProfile) {
        do {
            try secrets.deleteAPIKey(profileID: profile.id)
            try profileStore.remove(profileID: profile.id)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

extension AIProviderKind {
    var displayName: String {
        switch self {
        case .officialGateway: "官方服务"
        case .openAICompatible: "OpenAI Compatible"
        case .qwen: "Qwen"
        case .localRules: "本地规则"
        }
    }
}

extension QwenRegion {
    var displayName: String {
        switch self {
        case .chinaBeijing: "中国内地（北京）"
        case .singapore: "新加坡"
        case .unitedStates: "美国"
        }
    }
}
