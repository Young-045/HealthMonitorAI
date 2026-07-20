import SwiftData
import SwiftUI

struct NewMealView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var foodName = ""
    @State private var mealType = MealType.lunch
    @State private var eatenAt = Date()
    @State private var calories = ""
    @State private var protein = ""
    @State private var carbohydrate = ""
    @State private var fat = ""
    @State private var note = ""
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("食物") {
                    TextField("例如：番茄炒蛋", text: $foodName)
                    Picker("餐次", selection: $mealType) {
                        ForEach(MealType.allCases) { type in
                            Text(type.title).tag(type)
                        }
                    }
                    DatePicker("用餐时间", selection: $eatenAt)
                }

                Section("营养估算") {
                    nutritionField("热量", text: $calories, unit: "千卡")
                    nutritionField("蛋白质", text: $protein, unit: "克")
                    nutritionField("碳水", text: $carbohydrate, unit: "克")
                    nutritionField("脂肪", text: $fat, unit: "克")
                }

                Section("备注") {
                    TextField("份量、烹饪方式等（可选）", text: $note, axis: .vertical)
                        .lineLimit(2...4)
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("记录饮食")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存", action: save)
                        .fontWeight(.semibold)
                }
            }
        }
    }

    private func nutritionField(_ title: String, text: Binding<String>, unit: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            TextField("0", text: text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 100)
            Text(unit)
                .foregroundStyle(.secondary)
        }
    }

    private func save() {
        let normalizedName = foodName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedName.isEmpty else {
            errorMessage = "请输入食物名称。"
            return
        }

        guard let caloriesValue = parseNonnegative(calories),
              let proteinValue = parseNonnegative(protein),
              let carbohydrateValue = parseNonnegative(carbohydrate),
              let fatValue = parseNonnegative(fat) else {
            errorMessage = "营养数据必须是大于或等于 0 的数字；不确定时可以留空。"
            return
        }

        let meal = MealRecord(
            eatenAt: eatenAt,
            mealType: mealType,
            foodName: normalizedName,
            note: note.trimmingCharacters(in: .whitespacesAndNewlines),
            calories: caloriesValue,
            proteinGrams: proteinValue,
            carbohydrateGrams: carbohydrateValue,
            fatGrams: fatValue
        )
        modelContext.insert(meal)

        do {
            try modelContext.save()
            dismiss()
        } catch {
            errorMessage = "保存失败：\(error.localizedDescription)"
        }
    }

    private func parseNonnegative(_ text: String) -> Double? {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.isEmpty { return 0 }

        let normalized = value.replacingOccurrences(of: ",", with: ".")
        guard let number = Double(normalized), number.isFinite, number >= 0 else {
            return nil
        }
        return number
    }
}
