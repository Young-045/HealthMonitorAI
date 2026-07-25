import HealthMonitorCore
import SwiftUI
import UIKit

struct QwenProfileEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AIProviderProfileStore.self) private var profileStore

    private let profileID: UUID
    private let secrets = AIProviderSecretCoordinator()
    @State private var displayName: String
    @State private var region: QwenRegion
    @State private var baseURL: String
    @State private var textModel: String
    @State private var visionModel: String
    @State private var timeoutSeconds: Int
    @State private var apiKey = ""
    @State private var hasSavedAPIKey: Bool
    @State private var isTesting = false
    @State private var connectionResult: ConnectionTestResult?
    @State private var visionConnectionResult: ConnectionTestResult?
    @State private var errorMessage: String?

    init(profile: AIProviderProfile?) {
        let selectedRegion = Self.region(for: profile?.baseURL) ?? .chinaBeijing
        let id = profile?.id ?? UUID()
        profileID = id
        _displayName = State(initialValue: profile?.displayName ?? "阿里云百炼 Qwen")
        _region = State(initialValue: selectedRegion)
        _baseURL = State(initialValue: profile?.baseURL?.absoluteString ?? selectedRegion.baseURL.absoluteString)
        _textModel = State(initialValue: profile?.textModel ?? "qwen3.7-plus")
        _visionModel = State(initialValue: profile?.visionModel ?? "qwen3.7-plus")
        _timeoutSeconds = State(initialValue: profile?.timeoutSeconds ?? 60)
        _hasSavedAPIKey = State(initialValue: AIProviderSecretCoordinator().hasAPIKey(profileID: id))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Qwen 配置") {
                    TextField("名称", text: $displayName)
                    Picker("区域", selection: $region) {
                        ForEach(QwenRegion.allCases, id: \.self) { region in
                            Text(region.displayName).tag(region)
                        }
                    }
                    .onChange(of: region) { _, newRegion in
                        baseURL = newRegion.baseURL.absoluteString
                    }
                    TextField("Base URL", text: $baseURL)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                        .autocorrectionDisabled()
                    TextField("文字模型", text: $textModel)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    TextField("视觉模型", text: $visionModel)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Stepper("超时：\(timeoutSeconds) 秒", value: $timeoutSeconds, in: 5...300, step: 5)
                }

                Section("API Key") {
                    SecureField(hasSavedAPIKey ? "留空则保留现有密钥" : "输入 Qwen API Key", text: $apiKey)
                        .textContentType(.password)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .privacySensitive()
                    Text(hasSavedAPIKey ? "密钥已保存在本机 Keychain。" : "尚未保存密钥。")
                        .font(.caption)
                        .foregroundStyle(hasSavedAPIKey ? .green : .secondary)
                }

                Section("连接测试") {
                    Button {
                        Task { await testConnection() }
                    } label: {
                        if isTesting {
                            HStack { ProgressView(); Text("正在测试…") }
                        } else {
                            Text("测试文字连接")
                        }
                    }
                    .disabled(isTesting)

                    Button {
                        Task { await testVisionConnection() }
                    } label: {
                        if isTesting {
                            Text("请等待当前测试完成…")
                        } else {
                            Text("测试视觉能力")
                        }
                    }
                    .disabled(isTesting || visionModel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                    if let connectionResult {
                        LabeledContent("文字状态", value: "连接成功")
                        LabeledContent("文字模型", value: connectionResult.model)
                        LabeledContent("文字延迟", value: "\(connectionResult.latencyMilliseconds) ms")
                    }
                    if let visionConnectionResult {
                        LabeledContent("视觉状态", value: "连接成功")
                        LabeledContent("视觉模型", value: visionConnectionResult.model)
                        LabeledContent("视觉延迟", value: "\(visionConnectionResult.latencyMilliseconds) ms")
                    }
                    if connectionResult != nil || visionConnectionResult != nil {
                        LabeledContent("目标域名", value: URL(string: baseURL)?.host ?? "—")
                    }
                    Text("连接测试会向配置的域名发起真实请求。视觉测试会发送 App 在内存中生成的测试图案，可能产生少量费用。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage).foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Qwen Provider")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                        .fontWeight(.semibold)
                }
            }
        }
    }

    private func draftProfile() throws -> AIProviderProfile {
        let name = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            throw AIProviderError.invalidConfiguration("请填写 Provider 名称。")
        }
        guard let url = URL(string: baseURL.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            throw AIProviderError.invalidConfiguration("Base URL 格式无效。")
        }
        try AIRequestSecurity.validateQwenBaseURL(url)
        return AIProviderProfile(
            id: profileID,
            displayName: name,
            kind: .qwen,
            baseURL: url,
            visionModel: normalizedVisionModel,
            textModel: textModel.trimmingCharacters(in: .whitespacesAndNewlines),
            timeoutSeconds: timeoutSeconds
        )
    }

    private var normalizedVisionModel: String? {
        let value = visionModel.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    private func resolvedAPIKey() throws -> String {
        let entered = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if !entered.isEmpty { return entered }
        guard let saved = try secrets.loadAPIKey(profileID: profileID) else {
            throw AIProviderError.missingAPIKey
        }
        return saved
    }

    private func save() {
        do {
            let profile = try draftProfile()
            let entered = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
            if !entered.isEmpty {
                try secrets.saveAPIKey(entered, profileID: profileID)
                hasSavedAPIKey = true
            } else if !hasSavedAPIKey {
                throw AIProviderError.missingAPIKey
            }
            try profileStore.upsert(profile)
            try profileStore.select(profileID: profile.id)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func testConnection() async {
        isTesting = true
        connectionResult = nil
        errorMessage = nil
        defer { isTesting = false }
        do {
            let provider = try QwenProvider(
                profile: draftProfile(),
                apiKey: resolvedAPIKey()
            )
            connectionResult = try await provider.testConnection()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func testVisionConnection() async {
        isTesting = true
        visionConnectionResult = nil
        errorMessage = nil
        defer { isTesting = false }
        do {
            let provider = try QwenProvider(
                profile: draftProfile(),
                apiKey: resolvedAPIKey()
            )
            let renderer = UIGraphicsImageRenderer(size: CGSize(width: 128, height: 128))
            let imageData = renderer.jpegData(withCompressionQuality: 0.8) { context in
                context.cgContext.setFillColor(UIColor.systemBackground.cgColor)
                context.cgContext.fill(CGRect(x: 0, y: 0, width: 128, height: 128))
                context.cgContext.setFillColor(UIColor.systemOrange.cgColor)
                context.cgContext.fillEllipse(in: CGRect(x: 32, y: 32, width: 64, height: 64))
            }
            visionConnectionResult = try await provider.testVisionConnection(image: MealImage(
                contentType: "image/jpeg",
                data: imageData
            ))
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private static func region(for url: URL?) -> QwenRegion? {
        guard let host = url?.host?.lowercased() else { return nil }
        if host.contains("dashscope-intl") || host.contains("ap-southeast-1") { return .singapore }
        if host.contains("dashscope-us") || host.contains("us-east-1") { return .unitedStates }
        if host.contains("dashscope") || host.contains("cn-beijing") { return .chinaBeijing }
        return nil
    }
}
