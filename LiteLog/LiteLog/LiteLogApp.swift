import SwiftUI
import CoreData

@main
struct LiteLogApp: App {
    @StateObject private var settingsManager = SettingsManager.shared
    
    @State private var hasPopulatedMockData = false
    @State private var hasHandledCloudSync = false
    
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
                        if !hasHandledCloudSync {
                            hasHandledCloudSync = true
                            await handleCloudSyncOnStartup()
                        }
                        await DataSyncManager.shared.syncLocalDataToCloud(context: persistenceController.viewContext)
                    }
                }
        }
    }
    
    private func handleCloudSyncOnStartup() async {
        guard settingsManager.iCloudSyncEnabled else {
            await DataSyncManager.shared.syncFromCloud(context: persistenceController.viewContext)
            return
        }
        
        for _ in 0..<5 {
            if let syncedId = UserIdentifierManager.shared.checkForSyncedDeviceId() {
                UserIdentifierManager.shared.switchToDeviceId(syncedId)
                
                do {
                    let response = try await APIService.shared.fetchAllData()
                    
                    if let profile = response.profile {
                        try await DataSyncManager.shared.mergeProfileFromCloud(profile, context: persistenceController.viewContext)
                    }
                    if let records = response.records {
                        try await DataSyncManager.shared.mergeRecordsFromCloud(records, context: persistenceController.viewContext)
                    }
                    
                    return
                } catch {
                    print("Failed to merge synced data: \(error)")
                }
            }
            try? await Task.sleep(nanoseconds: 500_000_000)
        }
        
        await DataSyncManager.shared.syncFromCloud(context: persistenceController.viewContext)
    }
}