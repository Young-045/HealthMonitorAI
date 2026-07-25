import HealthMonitorCore
import PhotosUI
import SwiftData
import SwiftUI
import UIKit

struct NewMealView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AIProviderProfileStore.self) private var providerProfiles
    @Environment(AIHealthSummarySharingStore.self) private var healthSummarySharing
    @Environment(HealthDashboardModel.self) private var healthDashboard
    @Query(sort: \FoodCatalogItem.name) private var foodCatalog: [FoodCatalogItem]

    @State private var foodName = ""
    @State private var mealType = MealType.lunch
    @State private var eatenAt = Date()
    @State private var calories = ""
    @State private var protein = ""
    @State private var carbohydrate = ""
    @State private var fat = ""
    @State private var note = ""
    @State private var errorMessage: String?
    @State private var isSaving = false
    @State private var savedMeal: MealRecord?
    @State private var aiDescription = ""
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var processedImageData: Data?
    @State private var isPreparingImage = false
    @State private var isShowingAIPreview = false
    @State private var isAnalyzing = false
    @State private var aiResult: MealAnalysisResult?
    @State private var aiErrorMessage: String?
    @State private var previewHealthSummary: MealHealthSummary?
    @State private var matchedFoodItems: [MealFoodItem] = []
    @State private var confirmedWeightInputs: [Int: String] = [:]
    @State private var confirmedLabelAmountInput = ""
    @State private var authorityMatches: [Int: AuthorityFoodCatalogItem] = [:]
    private let healthKitWriter = HealthKitNutritionWriter()
    private let providerSecrets = AIProviderSecretCoordinator()
    private let authorityCatalog = AuthorityFoodCatalogStore.bundled

    var body: some View {
        NavigationStack {
            Form {
                aiSection

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
                    Button(savedMeal == nil ? "保存" : "重试写入") {
                        Task { await save() }
                    }
                        .fontWeight(.semibold)
                        .disabled(isSaving)
                }
            }
            .sheet(isPresented: $isShowingAIPreview) {
                if let profile = providerProfiles.activeProfile,
                   let host = profile.baseURL?.host {
                    AIRequestPreviewView(
                        providerName: profile.displayName,
                        targetDomain: host,
                        mealDescription: normalizedAIDescription,
                        image: processedImageData.flatMap(UIImage.init(data:)),
                        healthSummary: previewHealthSummary,
                        onConfirm: {
                            Task { await analyzeMeal() }
                        }
                    )
                }
            }
            .onChange(of: selectedPhotoItem) { _, _ in
                Task { await loadSelectedImage() }
            }
        }
    }

    @ViewBuilder
    private var aiSection: some View {
        let photoPickerTitle = processedImageData == nil ? "选择餐食照片" : "更换餐食照片"
        Section("Qwen 辅助识别") {
            if let profile = providerProfiles.activeProfile {
                LabeledContent("当前 Provider", value: profile.displayName)
                TextField("AI 描述（可选，留空则使用下方食物名称）", text: $aiDescription, axis: .vertical)
                    .lineLimit(2...4)

                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                    Label(photoPickerTitle, systemImage: "photo")
                }
                if isPreparingImage {
                    HStack { ProgressView(); Text("正在本机压缩并移除图片元数据…") }
                } else if let processedImageData,
                          let image = UIImage(data: processedImageData) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 180)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    Button("移除照片", role: .destructive) {
                        selectedPhotoItem = nil
                        self.processedImageData = nil
                    }
                }

                Button {
                    prepareAIPreview()
                } label: {
                    if isAnalyzing {
                        HStack { ProgressView(); Text("Qwen 正在识别…") }
                    } else {
                        Label("预览并发送", systemImage: "sparkles")
                    }
                }
                .disabled(isAnalyzing || isPreparingImage || !hasAIInput)

                if !hasAIInput {
                    Text("请填写 AI 描述或下方食物名称，也可以选择一张餐食照片。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let aiErrorMessage {
                    Text(aiErrorMessage).foregroundStyle(.red)
                }

                if let aiResult {
                    recognizedFoodsView(aiResult)
                }
            } else {
                Text("请先在“AI”页添加并选择 Qwen Provider。手动记录不受影响。")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var normalizedAIDescription: String {
        MealAIInputResolver.effectiveDescription(
            aiDescription: aiDescription,
            foodName: foodName
        )
    }

    private var hasAIInput: Bool {
        MealAIInputResolver.hasInput(
            aiDescription: aiDescription,
            foodName: foodName,
            hasImage: processedImageData != nil
        )
    }

    private func recognizedFoodsView(_ result: MealAnalysisResult) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("识别结果（尚未保存）").font(.headline)
            recognizedPackagingView(result)
            if result.foods.isEmpty,
               result.product?.name?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false {
                Text("未识别到明确食物，请修改描述或照片后重试。")
                    .foregroundStyle(.secondary)
            } else if !result.foods.isEmpty {
                if result.nutritionLabel?.present == true {
                    Text("包装外的其他餐食").font(.subheadline).fontWeight(.semibold)
                }
                ForEach(Array(result.foods.enumerated()), id: \.offset) { index, food in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(food.name).fontWeight(.semibold)
                        Text("估算范围 \(decimalText(food.weightRange.minimumGrams))–\(decimalText(food.weightRange.maximumGrams)) 克 · 置信度 \(percentText(food.confidence))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        HStack {
                            Text("确认重量")
                            Spacer()
                            TextField(
                                decimalText(food.estimatedWeightGrams),
                                text: confirmedWeightBinding(index: index, food: food)
                            )
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: 90)
                            Text("克").foregroundStyle(.secondary)
                        }
                        if !food.uncertainties.isEmpty {
                            Text("不确定：\(food.uncertainties.joined(separator: "；"))")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                        if let match = resolvedMatch(food: food, index: index) {
                            Label(match.displayText, systemImage: match.canCalculate
                                  ? "checkmark.circle.fill"
                                  : "exclamationmark.circle")
                                .font(.caption)
                                .foregroundStyle(match.canCalculate ? .green : .orange)
                        } else {
                            Label("本地目录未匹配", systemImage: "questionmark.circle")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                    }
                }
            }
            Button(confirmAIResultTitle(result)) {
                applyAIResult(result)
            }
            Text(result.nutritionLabel?.present == true
                 ? "营养表数字由 AI 转录，按确认的实际摄入重量在本机换算；保存前请核对原图。"
                 : "AI 只识别食物和重量，不直接写入数据库或 Apple 健康。")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func recognizedPackagingView(_ result: MealAnalysisResult) -> some View {
        if let product = result.product {
            VStack(alignment: .leading, spacing: 4) {
                Text(product.name ?? "未读出商品名称").fontWeight(.semibold)
                if let brand = product.brand {
                    Text("品牌：\(brand)").font(.caption).foregroundStyle(.secondary)
                }
                Text("商品信息置信度 \(percentText(product.confidence))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }

        if let package = result.package {
            VStack(alignment: .leading, spacing: 4) {
                Text("包装信息").font(.subheadline).fontWeight(.semibold)
                if let netWeight = package.netWeightGrams {
                    Text("净含量：\(decimalText(netWeight)) 克")
                }
                if let drainedWeight = package.drainedWeightGrams {
                    Text("沥干重量：\(decimalText(drainedWeight)) 克")
                }
                if let servingSize = package.servingSizeGrams {
                    Text("每份：\(decimalText(servingSize)) 克")
                }
                if let servings = package.servingsPerPackage {
                    Text("每包装：\(decimalText(servings)) 份")
                }
            }
            .font(.caption)
        }

        if let label = result.nutritionLabel, label.present {
            VStack(alignment: .leading, spacing: 6) {
                Text("检测到营养成分表 · \(nutritionBasisText(label))")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                labelValue("热量", value: label.energyKilocalories, unit: "千卡")
                labelValue("蛋白质", value: label.proteinGrams, unit: "克")
                labelValue("碳水", value: label.carbohydrateGrams, unit: "克")
                labelValue("脂肪", value: label.fatGrams, unit: "克")
                HStack {
                    Text(labelConsumptionTitle(label))
                    Spacer()
                    TextField(labelConsumptionUnit(label), text: $confirmedLabelAmountInput)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 90)
                    Text(labelConsumptionUnit(label)).foregroundStyle(.secondary)
                }
                if !label.unreadableFields.isEmpty {
                    Text("未能读清：\(label.unreadableFields.joined(separator: "、"))")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
        }

        if !result.warnings.isEmpty {
            Text("提示：\(result.warnings.joined(separator: "；"))")
                .font(.caption)
                .foregroundStyle(.orange)
        }
    }

    @ViewBuilder
    private func labelValue(_ name: String, value: Decimal?, unit: String) -> some View {
        if let value {
            Text("\(name)：\(decimalText(value)) \(unit)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func prepareAIPreview() {
        aiErrorMessage = nil
        guard let profile = providerProfiles.activeProfile,
              profile.kind == .qwen,
              profile.baseURL?.host != nil else {
            aiErrorMessage = "当前活动 Provider 不是可用的 Qwen 配置。"
            return
        }
        guard providerSecrets.hasAPIKey(profileID: profile.id) else {
            aiErrorMessage = "当前 Qwen Profile 缺少 API Key。"
            return
        }
        if processedImageData != nil,
           profile.visionModel?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false {
            aiErrorMessage = AIProviderError.imageNotSupported.localizedDescription
            return
        }
        previewHealthSummary = healthSummarySharing.isEnabled
            ? availableHealthSummary()
            : nil
        isShowingAIPreview = true
    }

    @MainActor
    private func loadSelectedImage() async {
        guard let selectedPhotoItem else {
            processedImageData = nil
            return
        }
        isPreparingImage = true
        aiErrorMessage = nil
        defer { isPreparingImage = false }
        do {
            guard let sourceData = try await selectedPhotoItem.loadTransferable(type: Data.self) else {
                throw MealImagePreprocessorError.invalidImage
            }
            processedImageData = try MealImagePreprocessor.jpegData(from: sourceData)
        } catch {
            processedImageData = nil
            aiErrorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func analyzeMeal() async {
        guard let profile = providerProfiles.activeProfile else { return }
        isAnalyzing = true
        aiResult = nil
        matchedFoodItems = []
        authorityMatches = [:]
        confirmedWeightInputs = [:]
        confirmedLabelAmountInput = ""
        aiErrorMessage = nil
        defer { isAnalyzing = false }
        do {
            guard let apiKey = try providerSecrets.loadAPIKey(profileID: profile.id) else {
                throw AIProviderError.missingAPIKey
            }
            let provider = try QwenProvider(profile: profile, apiKey: apiKey)
            let image = processedImageData.map {
                MealImage(contentType: "image/jpeg", data: $0)
            }
            let result = try await provider.analyzeMeal(MealAnalysisRequest(
                requestId: UUID().uuidString,
                locale: Locale.current.identifier,
                description: normalizedAIDescription.isEmpty ? nil : normalizedAIDescription,
                image: image,
                healthSummary: previewHealthSummary
            ))
            aiResult = result
            confirmedLabelAmountInput = defaultConsumedAmountText(for: result) ?? ""
            confirmedWeightInputs = Dictionary(uniqueKeysWithValues: result.foods.enumerated().map {
                ($0.offset, decimalText($0.element.estimatedWeightGrams))
            })
            if let authorityCatalog {
                authorityMatches = Dictionary(uniqueKeysWithValues: result.foods.enumerated().compactMap {
                    index, food in
                    guard let match = try? authorityCatalog.exactMatch(name: food.name) else {
                        return nil
                    }
                    return (index, match)
                })
            }
        } catch {
            aiErrorMessage = error.localizedDescription
        }
    }

    private func availableHealthSummary() -> MealHealthSummary? {
        let values = MealHealthSummary(
            steps: healthDashboard.summary.steps,
            activeEnergyKilocalories: healthDashboard.summary.activeEnergyKilocalories,
            exerciseMinutes: healthDashboard.summary.exerciseMinutes,
            recentSleepDayMinutes: healthDashboard.overview.sleepMinutes
        )
        guard values.steps != nil
                || values.activeEnergyKilocalories != nil
                || values.exerciseMinutes != nil
                || values.recentSleepDayMinutes != nil else {
            return nil
        }
        return values
    }

    private func applyAIResult(_ result: MealAnalysisResult) {
        let recognizedNames = ([result.product?.name] + result.foods.map { Optional($0.name) })
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        if !recognizedNames.isEmpty {
            foodName = recognizedNames.reduce(into: [String]()) { names, name in
                if !names.contains(name) { names.append(name) }
            }.joined(separator: "、")
        }
        if let label = result.nutritionLabel, label.present {
            applyNutritionLabel(label, result: result)
            return
        }
        let estimates = result.foods.enumerated().map { index, food in
            let weight = confirmedWeightInputs[index] ?? decimalText(food.estimatedWeightGrams)
            return "\(food.name)确认\(weight)克"
        }.joined(separator: "；")
        let uncertainties = result.foods.flatMap(\.uncertainties)
        let uncertaintyText = uncertainties.isEmpty
            ? ""
            : "；待确认：\(uncertainties.joined(separator: "、"))"
        note = estimates + uncertaintyText

        let matches = result.foods.enumerated().compactMap {
            index, food -> (Int, RecognizedFood, ResolvedFoodCatalogMatch)? in
            guard let match = resolvedMatch(food: food, index: index),
                  match.canCalculate else {
                return nil
            }
            return (index, food, match)
        }
        guard matches.count == result.foods.count, !matches.isEmpty else {
            matchedFoodItems = []
            aiErrorMessage = "存在未匹配的食物，已回填名称和重量备注；请手动确认营养数据。"
            return
        }

        do {
            let items = try matches.map { index, food, match in
                guard let weight = parsedConfirmedWeight(index: index), weight > 0 else {
                    throw ConfirmedFoodInputError.invalidWeight(food.name)
                }
                return try match.mealFoodItem(
                    recognizedFood: food,
                    confirmedWeightGrams: weight
                )
            }
            let nutrition = try MealNutritionCalculator.calculate(foodItems: items)
            matchedFoodItems = items
            calories = decimalText(nutrition.total.energyKilocalories)
            protein = decimalText(nutrition.total.proteinGrams)
            carbohydrate = decimalText(nutrition.total.carbohydrateGrams)
            fat = decimalText(nutrition.total.fatGrams)
            aiErrorMessage = nil
        } catch {
            matchedFoodItems = []
            aiErrorMessage = "本地营养计算失败：\(error.localizedDescription)"
        }
    }

    private func applyNutritionLabel(
        _ label: RecognizedNutritionLabel,
        result: MealAnalysisResult
    ) {
        guard let consumedAmount = parsedDecimal(confirmedLabelAmountInput) else {
            aiErrorMessage = label.basis == .per100g
                ? NutritionLabelCalculationError.invalidConsumedWeight.localizedDescription
                : NutritionLabelCalculationError.invalidConsumedBasisCount.localizedDescription
            return
        }

        do {
            var calculated: CalculatedLabelNutrition
            switch label.basis {
            case .per100g:
                calculated = try NutritionLabelCalculator.calculate(
                    label: label,
                    package: result.package,
                    consumedWeightGrams: consumedAmount
                )
            case .perServing, .perPackage:
                calculated = try NutritionLabelCalculator.calculate(
                    label: label,
                    consumedBasisCount: consumedAmount
                )
            case .unknown:
                throw NutritionLabelCalculationError.missingReferenceWeight
            }
            var additionalWarning: String?
            if !result.foods.isEmpty {
                let matches = result.foods.enumerated().compactMap {
                    index, food -> (Int, RecognizedFood, ResolvedFoodCatalogMatch)? in
                    guard let match = resolvedMatch(food: food, index: index),
                          match.canCalculate else {
                        return nil
                    }
                    return (index, food, match)
                }
                if matches.count == result.foods.count {
                    let items = try matches.map { index, food, match in
                        guard let weight = parsedConfirmedWeight(index: index), weight > 0 else {
                            throw ConfirmedFoodInputError.invalidWeight(food.name)
                        }
                        return try match.mealFoodItem(
                            recognizedFood: food,
                            confirmedWeightGrams: weight
                        )
                    }
                    let additional = try MealNutritionCalculator.calculate(foodItems: items).total
                    calculated = CalculatedLabelNutrition(
                        energyKilocalories: combined(calculated.energyKilocalories, additional.energyKilocalories),
                        proteinGrams: combined(calculated.proteinGrams, additional.proteinGrams),
                        carbohydrateGrams: combined(calculated.carbohydrateGrams, additional.carbohydrateGrams),
                        fatGrams: combined(calculated.fatGrams, additional.fatGrams),
                        fiberGrams: combined(calculated.fiberGrams, additional.fiberGrams),
                        sugarGrams: combined(calculated.sugarGrams, additional.sugarGrams),
                        sodiumMilligrams: combined(calculated.sodiumMilligrams, additional.sodiumMilligrams)
                    )
                } else {
                    additionalWarning = "包装外仍有未匹配食物，标签营养已回填，但其他食物需手动补充。"
                }
            }

            calories = calculated.energyKilocalories.map(decimalText) ?? ""
            protein = calculated.proteinGrams.map(decimalText) ?? ""
            carbohydrate = calculated.carbohydrateGrams.map(decimalText) ?? ""
            fat = calculated.fatGrams.map(decimalText) ?? ""
            matchedFoodItems = []

            var notes = [
                "营养成分表：\(nutritionBasisText(label))",
                "\(labelConsumptionTitle(label)) \(decimalText(consumedAmount)) \(labelConsumptionUnit(label))"
            ]
            if let netWeight = result.package?.netWeightGrams {
                notes.append("包装净含量 \(decimalText(netWeight)) 克")
            }
            if !label.unreadableFields.isEmpty {
                notes.append("未读清：\(label.unreadableFields.joined(separator: "、"))")
            }
            note = notes.joined(separator: "；")
            aiErrorMessage = additionalWarning
        } catch {
            matchedFoodItems = []
            aiErrorMessage = "营养成分表换算失败：\(error.localizedDescription)"
        }
    }

    private func confirmedWeightBinding(index: Int, food: RecognizedFood) -> Binding<String> {
        Binding(
            get: { confirmedWeightInputs[index] ?? decimalText(food.estimatedWeightGrams) },
            set: { confirmedWeightInputs[index] = $0 }
        )
    }

    private func parsedConfirmedWeight(index: Int) -> Double? {
        let input = confirmedWeightInputs[index]?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: ".") ?? ""
        guard let value = Double(input), value.isFinite, value <= 20_000 else { return nil }
        return value
    }

    private func allFoodsMatch(_ result: MealAnalysisResult) -> Bool {
        !result.foods.isEmpty && result.foods.enumerated().allSatisfy {
            resolvedMatch(food: $0.element, index: $0.offset)?.canCalculate == true
        }
    }

    private func resolvedMatch(
        food: RecognizedFood,
        index: Int
    ) -> ResolvedFoodCatalogMatch? {
        if let userMatch = FoodCatalogMatcher.match(
            recognizedFood: food,
            catalog: foodCatalog
        ) {
            return .user(userMatch)
        }
        if let authorityMatch = authorityMatches[index] {
            return .authority(authorityMatch)
        }
        return nil
    }

    private func decimalText(_ value: Decimal) -> String {
        NSDecimalNumber(decimal: value).stringValue
    }

    private func parsedDecimal(_ text: String) -> Decimal? {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: ".")
        guard let value = Decimal(string: normalized, locale: Locale(identifier: "en_US_POSIX")),
              value > 0, value <= 20_000 else {
            return nil
        }
        return value
    }

    private func combined(_ primary: Decimal?, _ additional: Decimal) -> Decimal? {
        primary.map { $0 + additional }
    }

    private func defaultConsumedAmountText(for result: MealAnalysisResult) -> String? {
        guard let label = result.nutritionLabel else { return nil }
        switch label.basis {
        case .per100g:
            let weight = result.package?.drainedWeightGrams
                ?? result.package?.netWeightGrams
                ?? result.package?.servingSizeGrams
            return weight.map(decimalText)
        case .perServing, .perPackage:
            return label.basisQuantity.map(decimalText) ?? "1"
        case .unknown:
            return nil
        }
    }

    private func confirmAIResultTitle(_ result: MealAnalysisResult) -> String {
        if result.nutritionLabel?.present == true {
            return "确认摄入量并采用营养成分表"
        }
        return allFoodsMatch(result) ? "确认并用本地营养计算" : "回填名称与重量备注"
    }

    private func nutritionBasisText(_ label: RecognizedNutritionLabel) -> String {
        if let description = label.basisDescription?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !description.isEmpty {
            return description
        }
        return switch label.basis {
        case .per100g: "每 100 克"
        case .perServing: "每份"
        case .perPackage: "每包装"
        case .unknown: "计量依据未读清"
        }
    }

    private func labelConsumptionTitle(_ label: RecognizedNutritionLabel) -> String {
        switch label.basis {
        case .per100g: "确认实际摄入重量"
        case .perServing: "确认实际摄入数量"
        case .perPackage: "确认实际摄入包装数"
        case .unknown: "确认实际摄入量"
        }
    }

    private func labelConsumptionUnit(_ label: RecognizedNutritionLabel) -> String {
        switch label.basis {
        case .per100g: "克"
        case .perServing: label.basisUnit ?? "份"
        case .perPackage: label.basisUnit ?? "包装"
        case .unknown: ""
        }
    }

    private func percentText(_ value: Decimal) -> String {
        let percent = NSDecimalNumber(decimal: value).doubleValue * 100
        return percent.formatted(.number.precision(.fractionLength(0))) + "%"
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

    @MainActor
    private func save() async {
        if let savedMeal {
            await syncWithHealthKit(savedMeal)
            return
        }
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
        if !matchedFoodItems.isEmpty {
            meal.foodItems = matchedFoodItems
            matchedFoodItems.forEach { $0.meal = meal }
            do {
                try MealNutritionCalculator.recalculate(meal)
            } catch {
                errorMessage = "本地营养计算失败：\(error.localizedDescription)"
                return
            }
        }
        modelContext.insert(meal)
        isSaving = true

        do {
            try modelContext.save()
            savedMeal = meal
            await syncWithHealthKit(meal)
        } catch {
            errorMessage = "保存失败：\(error.localizedDescription)"
            isSaving = false
        }
    }

    @MainActor
    private func syncWithHealthKit(_ meal: MealRecord) async {
        isSaving = true
        do {
            try await MealHealthKitSyncCoordinator.sync(meal, using: healthKitWriter)
            do {
                try modelContext.save()
                dismiss()
            } catch {
                try? await MealHealthKitSyncCoordinator.deleteHealthSamples(
                    for: meal,
                    using: healthKitWriter
                )
                meal.healthKitSyncState = .failed
                try? modelContext.save()
                errorMessage = "餐食已保存在本机，但健康样本引用保存失败：\(error.localizedDescription)"
            }
        } catch {
            meal.healthKitSyncState = .failed
            try? modelContext.save()
            errorMessage = "餐食已保存在本机，但未写入 Apple 健康：\(error.localizedDescription)"
        }
        isSaving = false
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

private enum ResolvedFoodCatalogMatch {
    case user(FoodCatalogMatch)
    case authority(AuthorityFoodCatalogItem)

    var displayText: String {
        switch self {
        case .user(let match):
            "用户目录匹配：\(match.item.name)"
        case .authority(let item) where item.nutrientsPer100Grams != nil:
            "权威目录匹配：\(item.name) · \(item.sourceDisplayName)"
        case .authority(let item):
            "权威目录匹配：\(item.name) · 营养字段不完整"
        }
    }

    var canCalculate: Bool {
        switch self {
        case .user:
            true
        case .authority(let item):
            item.nutrientsPer100Grams != nil
        }
    }

    func mealFoodItem(
        recognizedFood: RecognizedFood,
        confirmedWeightGrams: Double
    ) throws -> MealFoodItem {
        switch self {
        case .user(let match):
            return FoodCatalogMatcher.mealFoodItem(
                recognizedFood: recognizedFood,
                confirmedWeightGrams: confirmedWeightGrams,
                match: match
            )
        case .authority(let item):
            guard let nutrients = item.nutrientsPer100Grams else {
                throw ConfirmedFoodInputError.incompleteNutrition(item.name)
            }
            return MealFoodItem(
                catalogIdentifierSnapshot: item.identifier,
                foodNameSnapshot: item.name,
                weightGrams: confirmedWeightGrams,
                cookingMethod: recognizedFood.cookingMethod ?? "",
                nutrientsPer100Grams: nutrients,
                sourceDataVersion: "\(item.sourceCode):\(item.sourceRelease)"
            )
        }
    }
}

private enum ConfirmedFoodInputError: LocalizedError {
    case invalidWeight(String)
    case incompleteNutrition(String)

    var errorDescription: String? {
        switch self {
        case .invalidWeight(let foodName): "\(foodName) 的确认重量必须在 0 到 20000 克之间。"
        case .incompleteNutrition(let foodName): "\(foodName) 的权威营养字段不完整，不能自动计算。"
        }
    }
}
