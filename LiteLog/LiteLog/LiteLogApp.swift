import SwiftUI
import CoreData

@main
struct LiteLogApp: App {
    @StateObject private var settingsManager = SettingsManager.shared
    @StateObject private var proStore = ProEntitlementStore.shared

    @Environment(\.scenePhase) private var scenePhase

    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(settingsManager)
                .environmentObject(proStore)
                .environment(\.managedObjectContext, persistenceController.viewContext)
                .onAppear {
                    LegacyLocalDataCleanup.runIfNeeded()
                    settingsManager.performStartupMaintenance()
                    settingsManager.setContext(persistenceController.viewContext)
                    ICloudBackupManager.shared.refreshAvailability()
                }
                .onChange(of: scenePhase) { phase in
                    if phase == .background {
                        persistenceController.saveContext()
                        try? ICloudBackupManager.shared.backup(
                            context: persistenceController.viewContext,
                            settings: settingsManager
                        )
                    } else if phase == .active {
                        Task {
                            await proStore.refreshEntitlements()
                            ICloudBackupManager.shared.refreshAvailability()
                        }
                    }
                }
        }
    }
}
