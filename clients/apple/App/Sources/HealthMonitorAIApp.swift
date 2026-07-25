import SwiftUI
import SwiftData

@main
struct HealthMonitorAIApp: App {
    @State private var healthDashboard = HealthDashboardModel()
    @State private var providerProfiles = AIProviderProfileStore()
    @State private var healthSummarySharing = AIHealthSummarySharingStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(healthDashboard)
                .environment(providerProfiles)
                .environment(healthSummarySharing)
                .modelContainer(for: [
                    MealRecord.self,
                    MealFoodItem.self,
                    FoodCatalogItem.self,
                    DailyHealthSummaryRecord.self,
                    DailyScoreRecord.self
                ])
        }
    }
}
