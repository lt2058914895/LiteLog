import SwiftUI
import CoreData

@main
struct LiteLogApp: App {
    @StateObject private var settingsManager = SettingsManager.shared

    @Environment(\.scenePhase) private var scenePhase

    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(settingsManager)
                .environment(\.managedObjectContext, persistenceController.viewContext)
                .onAppear {
                    LegacyLocalDataCleanup.runIfNeeded()
                    settingsManager.performStartupMaintenance()
                    settingsManager.setContext(persistenceController.viewContext)
                }
                .onChange(of: scenePhase) { phase in
                    if phase == .background {
                        persistenceController.saveContext()
                    }
                }
        }
    }
}
