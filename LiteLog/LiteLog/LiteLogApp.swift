import SwiftUI
import CoreData

@main
struct LiteLogApp: App {
    @StateObject private var settingsManager = SettingsManager.shared
    
    @State private var hasPopulatedMockData = false
    
    @Environment(\.scenePhase) private var scenePhase

    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(settingsManager)
                .environment(\.managedObjectContext, persistenceController.viewContext)
                .onAppear {
                    LegacyLocalDataCleanup.runIfNeeded()
                    settingsManager.setContext(persistenceController.viewContext)

                    #if DEBUG
                    if !hasPopulatedMockData {
                        MockDataManager.shared.populateMockData(context: persistenceController.viewContext)
                        hasPopulatedMockData = true
                    }
                    #endif
                }
                .onChange(of: scenePhase) { phase in
                    if phase == .background {
                        persistenceController.saveContext()
                    }
                }
        }
    }
}
