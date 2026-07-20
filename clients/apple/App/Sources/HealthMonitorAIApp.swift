import SwiftUI
import SwiftData

@main
struct HealthMonitorAIApp: App {
    @State private var healthDashboard = HealthDashboardModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(healthDashboard)
                .modelContainer(for: MealRecord.self)
        }
    }
}
