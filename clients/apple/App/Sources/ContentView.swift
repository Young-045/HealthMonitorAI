import SwiftUI
import UIKit

struct ContentView: View {
    @Environment(HealthDashboardModel.self) private var healthDashboard

    var body: some View {
        TabView {
            healthView
                .tabItem {
                    Label("健康", systemImage: "heart.fill")
                }
            MealsView()
                .tabItem {
                    Label("饮食", systemImage: "fork.knife")
                }
            SigningDiagnosticsView()
                .tabItem {
                    Label("诊断", systemImage: "stethoscope")
                }
            AIProviderSettingsView()
                .tabItem {
                    Label("AI", systemImage: "sparkles")
                }
        }
        .tint(.green)
    }

    private var healthView: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    header
                    authorizationCard
                    sectionTitle("活动")
                    activityGrid
                    sectionTitle("身体")
                    bodyGrid
                    sectionTitle("训练与恢复")
                    recoveryGrid
                    privacyCard
                }
                .padding(20)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("今日健康")
            .toolbar {
                if healthDashboard.state == .ready {
                    Button {
                        Task { await healthDashboard.refresh() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .accessibilityLabel("刷新健康数据")
                }
            }
            .task {
                if healthDashboard.state == .checkingAuthorization {
                    await healthDashboard.prepare()
                }
            }
        }
    }

    @ViewBuilder
    private var authorizationCard: some View {
        switch healthDashboard.state {
        case .needsAuthorization:
            statusCard(
                icon: "heart.text.square.fill",
                title: "连接 Apple 健康",
                message: "授权读取身体、活动、训练、睡眠与恢复数据。原始数据只在本机处理。"
            ) {
                Task { await healthDashboard.requestAuthorization() }
            }
        case .checkingAuthorization, .requesting, .loading:
            HStack(spacing: 12) {
                ProgressView()
                Text(progressMessage)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .cardStyle()
        case .unavailable:
            statusCard(
                icon: "exclamationmark.triangle.fill",
                title: "健康数据不可用",
                message: "请在支持 HealthKit 的 iPhone 上运行并验证。",
                actionTitle: nil,
                action: nil
            )
        case .failed(let message):
            statusCard(
                icon: "exclamationmark.circle.fill",
                title: "暂时无法读取",
                message: message,
                actionTitle: "重试"
            ) {
                Task { await healthDashboard.prepare() }
            }
        case .ready:
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label("已请求 Apple 健康访问", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Spacer()
                    if let lastUpdated = healthDashboard.lastUpdated {
                        Text(lastUpdated, style: .time)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Text(accessExplanation)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button("前往设置") {
                    openSettings()
                }
                .buttonStyle(.bordered)
            }
            .cardStyle()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("你的数据，由你掌控")
                .font(.title2.bold())
            Text("活动数据来自 Apple 健康；饮食记录保存在本机 SwiftData 数据库。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var activityGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
            MetricCard(
                title: "步数",
                value: formatted(healthDashboard.summary.steps),
                unit: "步",
                icon: "figure.walk",
                tint: .blue
            )
            MetricCard(
                title: "活动能量",
                value: formatted(healthDashboard.summary.activeEnergyKilocalories),
                unit: "千卡",
                icon: "flame.fill",
                tint: .orange
            )
            MetricCard(
                title: "锻炼时间",
                value: formatted(healthDashboard.summary.exerciseMinutes),
                unit: "分钟",
                icon: "timer",
                tint: .green
            )
            MetricCard(
                title: "静息能量",
                value: formatted(healthDashboard.summary.restingEnergyKilocalories),
                unit: "千卡",
                icon: "bed.double.fill",
                tint: .purple
            )
        }
        .redacted(reason: healthDashboard.state == .loading ? .placeholder : [])
    }

    private var bodyGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
            MetricCard(
                title: "身高",
                value: formatted(healthDashboard.overview.heightCentimeters, decimals: 1),
                unit: "厘米",
                icon: "ruler.fill",
                tint: .indigo
            )
            MetricCard(
                title: "体重",
                value: formatted(healthDashboard.overview.weightKilograms, decimals: 1),
                unit: "千克",
                icon: "scalemass.fill",
                tint: .cyan
            )
            MetricCard(
                title: "体脂率",
                value: formatted(healthDashboard.overview.bodyFatPercentage, decimals: 1),
                unit: "%",
                icon: "percent",
                tint: .orange
            )
        }
    }

    private var recoveryGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
            MetricCard(
                title: "今日训练",
                value: formatted(healthDashboard.overview.workoutCount),
                unit: "次",
                icon: "figure.run",
                tint: .green
            )
            MetricCard(
                title: "训练时长",
                value: formatted(healthDashboard.overview.workoutMinutes),
                unit: "分钟",
                icon: "stopwatch.fill",
                tint: .blue
            )
            MetricCard(
                title: "最近睡眠日",
                value: formatted(healthDashboard.overview.sleepMinutes),
                unit: "分钟",
                icon: "moon.zzz.fill",
                tint: .indigo
            )
            MetricCard(
                title: "静息心率",
                value: formatted(healthDashboard.overview.restingHeartRate),
                unit: "次/分",
                icon: "heart.fill",
                tint: .red
            )
            MetricCard(
                title: "HRV",
                value: formatted(healthDashboard.overview.heartRateVariabilityMilliseconds),
                unit: "毫秒",
                icon: "waveform.path.ecg",
                tint: .pink
            )
        }
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.headline)
    }

    private var progressMessage: String {
        switch healthDashboard.state {
        case .checkingAuthorization:
            "正在检查健康访问状态…"
        case .requesting:
            "等待健康授权…"
        default:
            "正在读取今日数据…"
        }
    }

    private var accessExplanation: String {
        let syncFailures = healthDashboard.lastSyncResult.failedMetrics
            .map(\.displayName)
            .sorted()
            .joined(separator: "、")
        let unavailable = healthDashboard.summary.unavailableMetrics
            .map(\.displayName)
            .sorted()
            .joined(separator: "、")

        if !syncFailures.isEmpty {
            return "部分数据（\(syncFailures)）增量同步失败，已保留上次同步位置；刷新后会安全重试。"
        }
        if healthDashboard.summary.isUnavailable {
            return "当前无法读取活动数据。Apple 不向 App 披露单项读取权限；请在设置中检查健康权限后重试。"
        }
        if healthDashboard.summary.isPartiallyAvailable {
            return "部分数据（\(unavailable)）暂时无法读取。请检查健康权限，其他可用数据仍会正常显示。"
        }
        return "Apple 不向 App 披露每一项读取权限是否被拒绝；数值为 0 也可能表示今天暂无数据。"
    }

    private func formatted(_ value: Int?) -> String {
        value?.formatted() ?? "—"
    }

    private func formatted(_ value: Double?, decimals: Int) -> String {
        value?.formatted(.number.precision(.fractionLength(decimals))) ?? "—"
    }

    private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    private var privacyCard: some View {
        Label {
            VStack(alignment: .leading, spacing: 4) {
                Text("隐私优先").font(.headline)
                Text("当前页面不会把 HealthKit 数据上传到服务端或发送给 AI。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } icon: {
            Image(systemName: "lock.shield.fill")
                .font(.title2)
                .foregroundStyle(.indigo)
        }
        .cardStyle()
    }

    private func statusCard(
        icon: String,
        title: String,
        message: String,
        actionTitle: String? = "授权读取",
        action: (() -> Void)?
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: icon)
                .font(.headline)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.borderedProminent)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }
}

private struct MetricCard: View {
    let title: String
    let value: String
    let unit: String
    let icon: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(tint)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value).font(.title2.bold())
                Text(unit).font(.caption).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }
}

private extension View {
    func cardStyle() -> some View {
        padding(16)
            .background(.background, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}
