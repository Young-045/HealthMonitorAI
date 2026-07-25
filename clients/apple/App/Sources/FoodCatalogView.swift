import SwiftData
import SwiftUI

struct FoodCatalogView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \FoodCatalogItem.name) private var items: [FoodCatalogItem]
    @State private var isAdding = false
    @State private var errorMessage: String?

    var body: some View {
        List {
            if items.isEmpty {
                ContentUnavailableView(
                    "本地食物目录为空",
                    systemImage: "books.vertical",
                    description: Text("添加常用食物及每 100 克营养后，Qwen 识别结果才能在本机精确匹配和计算。")
                )
            } else {
                ForEach(items) { item in
                    VStack(alignment: .leading, spacing: 5) {
                        HStack {
                            Text(item.name).font(.headline)
                            if item.isUserCreated {
                                Text("自建").font(.caption2).foregroundStyle(.secondary)
                            }
                        }
                        if !item.aliases.isEmpty {
                            Text("别名：\(item.aliases.joined(separator: "、"))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Text("每 100 克：\(item.energyKilocaloriesPer100Grams.formatted(.number.precision(.fractionLength(1)))) 千卡 · 蛋白质 \(item.proteinGramsPer100Grams.formatted(.number.precision(.fractionLength(1)))) 克")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .swipeActions {
                        if item.isUserCreated {
                            Button("删除", role: .destructive) { delete(item) }
                        }
                    }
                }
            }
        }
        .navigationTitle("本地食物目录")
        .toolbar {
            Button {
                isAdding = true
            } label: {
                Label("添加食物", systemImage: "plus")
            }
        }
        .sheet(isPresented: $isAdding) {
            UserFoodCatalogEditorView()
        }
        .alert("目录保存失败", isPresented: errorBinding) {
            Button("确定", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "未知错误")
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )
    }

    private func delete(_ item: FoodCatalogItem) {
        modelContext.delete(item)
        do {
            try modelContext.save()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct UserFoodCatalogEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var name = ""
    @State private var aliases = ""
    @State private var category = FoodCategory.other
    @State private var defaultServing = ""
    @State private var energy = ""
    @State private var protein = ""
    @State private var carbohydrate = ""
    @State private var fat = ""
    @State private var fiber = ""
    @State private var sugar = ""
    @State private var sodium = ""
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("食物") {
                    TextField("名称，例如：熟米饭", text: $name)
                    TextField("别名，用逗号分隔，例如：米饭、白饭", text: $aliases)
                    Picker("分类", selection: $category) {
                        ForEach(FoodCategory.allCases, id: \.self) {
                            Text($0.displayName).tag($0)
                        }
                    }
                    numberField("默认份量", text: $defaultServing, unit: "克（可选）")
                }

                Section("每 100 克营养") {
                    numberField("热量", text: $energy, unit: "千卡")
                    numberField("蛋白质", text: $protein, unit: "克")
                    numberField("碳水", text: $carbohydrate, unit: "克")
                    numberField("脂肪", text: $fat, unit: "克")
                    numberField("膳食纤维", text: $fiber, unit: "克")
                    numberField("糖", text: $sugar, unit: "克")
                    numberField("钠", text: $sodium, unit: "毫克")
                }

                if let errorMessage {
                    Section { Text(errorMessage).foregroundStyle(.red) }
                }
            }
            .navigationTitle("添加本地食物")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }.fontWeight(.semibold)
                }
            }
        }
    }

    private func numberField(_ title: String, text: Binding<String>, unit: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            TextField("0", text: text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 90)
            Text(unit).font(.caption).foregroundStyle(.secondary)
        }
    }

    private func save() {
        do {
            let item = try UserFoodCatalogDraft(
                name: name,
                aliases: aliases,
                category: category,
                defaultServingGrams: defaultServing,
                energyKilocalories: energy,
                proteinGrams: protein,
                carbohydrateGrams: carbohydrate,
                fatGrams: fat,
                fiberGrams: fiber,
                sugarGrams: sugar,
                sodiumMilligrams: sodium
            ).makeCatalogItem()
            modelContext.insert(item)
            try modelContext.save()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private extension FoodCategory {
    var displayName: String {
        switch self {
        case .staple: "主食"
        case .protein: "蛋白质"
        case .vegetable: "蔬菜"
        case .fruit: "水果"
        case .dairy: "乳制品"
        case .fatAndOil: "油脂"
        case .beverage: "饮品"
        case .preparedDish: "菜肴"
        case .condiment: "调味品"
        case .other: "其他"
        }
    }
}
