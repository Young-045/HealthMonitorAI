import SwiftUI
import UIKit

struct SigningDiagnosticsView: View {
    @State private var diagnostics = SigningDiagnostics.capture()
    @State private var copied = false

    var body: some View {
        NavigationStack {
            List {
                Section("结论") {
                    Label(
                        diagnostics.conclusion,
                        systemImage: diagnostics.runtimeHealthKitEntitlement
                            ? "checkmark.shield.fill"
                            : "exclamationmark.shield.fill"
                    )
                    .foregroundStyle(
                        diagnostics.runtimeHealthKitEntitlement ? .green : .orange
                    )
                }

                Section("安装后的实际签名") {
                    statusRow(
                        "进程 HealthKit entitlement",
                        value: diagnostics.runtimeHealthKitEntitlement
                    )
                    valueRow("Bundle ID", diagnostics.bundleIdentifier)
                    valueRow("Signing ID", diagnostics.signingIdentifier ?? "未读取到")
                    valueRow("Team ID", diagnostics.runtimeTeamIdentifier ?? "未读取到")
                }

                Section("embedded.mobileprovision") {
                    statusRow("Profile 存在", value: diagnostics.embeddedProfilePresent)
                    statusRow(
                        "Profile 允许 HealthKit",
                        value: diagnostics.profileHealthKitEntitlement
                    )
                    valueRow("Profile 名称", diagnostics.profileName ?? "未读取到")
                    valueRow(
                        "Application ID",
                        diagnostics.profileApplicationIdentifier ?? "未读取到"
                    )
                    valueRow("Profile Team ID", diagnostics.profileTeamIdentifier ?? "未读取到")
                    if let date = diagnostics.profileExpirationDate {
                        valueRow("失效时间", date.formatted(date: .abbreviated, time: .shortened))
                    }
                    if let error = diagnostics.profileReadError {
                        valueRow("读取错误", error)
                    }
                }

                Section {
                    Button {
                        UIPasteboard.general.string = diagnostics.report
                        copied = true
                    } label: {
                        Label(copied ? "已复制" : "复制诊断报告", systemImage: "doc.on.doc")
                    }

                    Button {
                        diagnostics = SigningDiagnostics.capture()
                        copied = false
                    } label: {
                        Label("重新检测", systemImage: "arrow.clockwise")
                    }
                } footer: {
                    Text("报告不包含 Apple ID、密码、设备健康数据或 API Key。")
                }
            }
            .navigationTitle("签名诊断")
        }
    }

    private func statusRow(_ title: String, value: Bool?) -> some View {
        HStack {
            Text(title)
            Spacer()
            if let value {
                Label(value ? "是" : "否", systemImage: value ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundStyle(value ? .green : .red)
            } else {
                Label("未知", systemImage: "questionmark.circle")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func valueRow(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.footnote.monospaced())
                .textSelection(.enabled)
        }
    }
}
