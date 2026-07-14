import SwiftUI

struct ContentView: View {
    @Environment(HealthDashboardModel.self) private var healthDashboard

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    header
                    authorizationCard
                    activityGrid
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
        }
    }

    @ViewBuilder
    private var authorizationCard: some View {
        switch healthDashboard.state {
        case .needsAuthorization:
            statusCard(
                icon: "heart.text.square.fill",
                title: "连接 Apple 健康",
                message: "授权读取步数、活动能量和锻炼时间。原始数据只在本机处理。"
            ) {
                Task { await healthDashboard.requestAuthorization() }
            }
        case .requesting, .loading:
            HStack(spacing: 12) {
                ProgressView()
                Text(healthDashboard.state == .requesting ? "等待健康授权…" : "正在读取今日数据…")
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
                Task { await healthDashboard.requestAuthorization() }
            }
        case .ready:
            HStack {
                Label("已连接 Apple 健康", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Spacer()
                if let lastUpdated = healthDashboard.lastUpdated {
                    Text(lastUpdated, style: .time)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .cardStyle()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("你的数据，由你掌控")
                .font(.title2.bold())
            Text("第一阶段先建立可靠的 HealthKit 本地读取通道，之后再叠加饮食和 AI 分析。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var activityGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
            MetricCard(
                title: "步数",
                value: healthDashboard.summary.steps.formatted(),
                unit: "步",
                icon: "figure.walk",
                tint: .blue
            )
            MetricCard(
                title: "活动能量",
                value: healthDashboard.summary.activeEnergyKilocalories.formatted(),
                unit: "千卡",
                icon: "flame.fill",
                tint: .orange
            )
            MetricCard(
                title: "锻炼时间",
                value: healthDashboard.summary.exerciseMinutes.formatted(),
                unit: "分钟",
                icon: "timer",
                tint: .green
            )
        }
        .redacted(reason: healthDashboard.state == .loading ? .placeholder : [])
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
