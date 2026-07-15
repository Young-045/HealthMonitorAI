import SwiftData
import SwiftUI

struct MealsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \MealRecord.eatenAt, order: .reverse) private var meals: [MealRecord]

    @State private var isPresentingNewMeal = false
    @State private var storageError: String?

    private var todayMeals: [MealRecord] {
        meals.filter { Calendar.autoupdatingCurrent.isDateInToday($0.eatenAt) }
    }

    private var earlierMeals: [MealRecord] {
        meals.filter { !Calendar.autoupdatingCurrent.isDateInToday($0.eatenAt) }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    NutritionSummaryView(totals: NutritionTotals(meals: todayMeals))
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                } header: {
                    Text("今日摄入")
                }

                Section("今日记录") {
                    if todayMeals.isEmpty {
                        ContentUnavailableView(
                            "还没有饮食记录",
                            systemImage: "fork.knife",
                            description: Text("点击右上角加号，记录今天吃过的食物。")
                        )
                    } else {
                        ForEach(todayMeals) { meal in
                            MealRow(meal: meal)
                                .swipeActions {
                                    deleteButton(for: meal)
                                }
                        }
                    }
                }

                if !earlierMeals.isEmpty {
                    Section("历史记录") {
                        ForEach(earlierMeals) { meal in
                            MealRow(meal: meal)
                                .swipeActions {
                                    deleteButton(for: meal)
                                }
                        }
                    }
                }
            }
            .navigationTitle("饮食记录")
            .toolbar {
                Button {
                    isPresentingNewMeal = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("添加饮食记录")
            }
            .sheet(isPresented: $isPresentingNewMeal) {
                NewMealView()
            }
            .alert("本地保存失败", isPresented: storageErrorBinding) {
                Button("确定", role: .cancel) {}
            } message: {
                Text(storageError ?? "未知错误")
            }
        }
    }

    private var storageErrorBinding: Binding<Bool> {
        Binding(
            get: { storageError != nil },
            set: { if !$0 { storageError = nil } }
        )
    }

    private func deleteButton(for meal: MealRecord) -> some View {
        Button("删除", role: .destructive) {
            modelContext.delete(meal)
            do {
                try modelContext.save()
            } catch {
                storageError = error.localizedDescription
            }
        }
    }
}

private struct NutritionSummaryView: View {
    let totals: NutritionTotals

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text(totals.calories, format: .number.precision(.fractionLength(0)))
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                Text("千卡")
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 0) {
                nutrient("蛋白质", totals.proteinGrams, .blue)
                nutrient("碳水", totals.carbohydrateGrams, .orange)
                nutrient("脂肪", totals.fatGrams, .purple)
            }
        }
        .padding(18)
        .background(
            LinearGradient(
                colors: [Color.green.opacity(0.18), Color.blue.opacity(0.10)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 20, style: .continuous)
        )
    }

    private func nutrient(_ title: String, _ value: Double, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("\(value.formatted(.number.precision(.fractionLength(1)))) g")
                .font(.subheadline.bold())
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct MealRow: View {
    let meal: MealRecord

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: meal.mealType.symbol)
                .frame(width: 38, height: 38)
                .background(Color.green.opacity(0.13), in: Circle())
                .foregroundStyle(.green)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(meal.foodName).font(.headline)
                    Spacer()
                    Text(meal.calories, format: .number.precision(.fractionLength(0)))
                        .font(.subheadline.bold())
                    Text("千卡")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                HStack(spacing: 8) {
                    Text(meal.mealType.title)
                    Text(meal.eatenAt, style: .time)
                    Text("蛋白质 \(meal.proteinGrams.formatted(.number.precision(.fractionLength(1))))g")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                if !meal.note.isEmpty {
                    Text(meal.note)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(.vertical, 4)
    }
}
