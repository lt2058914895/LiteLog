import SwiftUI
import CoreData
import os

@main
struct LiteLogApp: App {
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.litelog.app", category: "LiteLogApp")
    
    @StateObject private var settingsManager = SettingsManager.shared
    
    @State private var hasPopulatedMockData = false
    @State private var hasHandledCloudSync = false
    
    @Environment(\.scenePhase) private var scenePhase

    let persistenceController = PersistenceController.shared

    init() {
        BackgroundTaskManager.shared.registerBackgroundTasks()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(settingsManager)
                .environment(\.managedObjectContext, persistenceController.viewContext)
                .onAppear {
                    settingsManager.setContext(persistenceController.viewContext)

                    BackgroundTaskManager.shared.scheduleAppRefresh()
                    DataSyncManager.shared.startAutoSyncTimer()

                    // 仅在非正式环境下填充假数据（正式环境使用真实数据，无需假数据）
                    if settingsManager.appEnvironment != .production && !hasPopulatedMockData {
                        MockDataManager.shared.populateMockData(context: persistenceController.viewContext)
                        hasPopulatedMockData = true
                    }
                    
                    Task {
                        if !hasHandledCloudSync {
                            hasHandledCloudSync = true
                            await handleCloudSyncOnStartup()
                        }
                        await DataSyncManager.shared.syncLocalDataToCloud(context: persistenceController.viewContext)
                    }
                }
                .onChange(of: scenePhase) { phase in
                    switch phase {
                    case .active:
                        DataSyncManager.shared.startAutoSyncTimer()
                        Task {
                            await DataSyncManager.shared.syncLocalDataToCloud(context: persistenceController.viewContext)
                        }
                    case .background:
                        DataSyncManager.shared.stopAutoSyncTimer()
                        BackgroundTaskManager.shared.scheduleAppRefresh()
                    default:
                        break
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
                await DataSyncManager.shared.syncFromCloud(context: persistenceController.viewContext)
                return
            }
            try? await Task.sleep(nanoseconds: 500_000_000)
        }
        
        await DataSyncManager.shared.syncFromCloud(context: persistenceController.viewContext)
    }
}
