import HealthMonitorCore
import SwiftUI
import UIKit

struct AIRequestPreviewView: View {
    @Environment(\.dismiss) private var dismiss

    let providerName: String
    let targetDomain: String
    let mealDescription: String
    let image: UIImage?
    let healthSummary: MealHealthSummary?
    let onConfirm: () -> Void

    var body: some View {
        NavigationStack {
            List {
                Section("请求目标") {
                    LabeledContent("Provider", value: providerName)
                    LabeledContent("域名", value: targetDomain)
                }

                Section("即将发送") {
                    if !mealDescription.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Label("文字描述", systemImage: "text.alignleft")
                            Text(mealDescription)
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        }
                    }
                    if let image {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("压缩后的餐食图片", systemImage: "photo")
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .frame(maxHeight: 220)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                    if let healthSummary {
                        VStack(alignment: .leading, spacing: 6) {
                            Label("已授权的聚合健康摘要", systemImage: "heart.text.square")
                            healthSummaryRows(healthSummary)
                        }
                    }
                }

                Section("不会发送") {
                    if healthSummary == nil {
                        Label("Apple 健康与 HealthKit 摘要", systemImage: "heart.slash")
                    }
                    Label("API Key 正文", systemImage: "key.slash")
                    Text("API Key 仅作为 HTTPS Authorization 请求头发送给上方域名。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("确认发送给 AI")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("确认发送") {
                        dismiss()
                        onConfirm()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }

    private func healthSummaryRows(_ summary: MealHealthSummary) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            previewValue("今日步数", summary.steps, unit: "步")
            previewValue("活动能量", summary.activeEnergyKilocalories, unit: "千卡")
            previewValue("锻炼时间", summary.exerciseMinutes, unit: "分钟")
            previewValue("最近睡眠日", summary.recentSleepDayMinutes, unit: "分钟")
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    private func previewValue(_ title: String, _ value: Int?, unit: String) -> Text {
        Text("\(title)：\(value?.formatted() ?? "无可用值")\(value == nil ? "" : " \(unit)")")
    }
}
