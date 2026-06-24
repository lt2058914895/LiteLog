import SwiftUI
import CoreData

@main
struct LiteLogApp: App {
    @StateObject private var settingsManager = SettingsManager.shared
    
    @State private var hasPopulatedMockData = false
    
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(settingsManager)
                .environment(\.managedObjectContext, persistenceController.viewContext)
                .onAppear {
                    settingsManager.setContext(persistenceController.viewContext)
                    
                    #if DEBUG
                    if !hasPopulatedMockData {
                        MockDataManager.shared.populateMockData(context: persistenceController.viewContext)
                        hasPopulatedMockData = true
                    }
                    #endif
                    
                    Task {
                        await DataSyncManager.shared.syncLocalDataToCloud(context: persistenceController.viewContext)
                    }
                }
        }
    }
}