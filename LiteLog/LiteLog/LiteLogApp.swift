//
//  LiteLogApp.swift
//  LiteLog
//
//  Created by lt on 2026/5/11.
//


import SwiftUI
import SwiftData

@main
struct LiteLogApp: App {
    @StateObject private var settingsManager = SettingsManager.shared
    
    @State private var hasPopulatedMockData = false

    static var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            WeightRecord.self,
            UserProfile.self,
        ])
        
        // DEBUG 模式下使用内存数据库，避免 schema 不兼容问题
        #if DEBUG
        let modelConfiguration = ModelConfiguration(
            isStoredInMemoryOnly: true,
            allowsSave: true,
            cloudKitDatabase: .none
        )
        #else
        let modelConfiguration = ModelConfiguration(
            "LiteLog_v4",
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .automatic
        )
        #endif

        do {
            let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
            
            // 在调试模式下自动填充Mock数据
            #if DEBUG
            MockDataManager.shared.populateMockData(modelContext: container.mainContext)
            #endif
            
            return container
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(settingsManager)
                .onAppear {
                    let modelContext = LiteLogApp.sharedModelContainer.mainContext
                    settingsManager.setModelContext(modelContext)
                    
                    // 冷启动时检查并同步未上传的数据到云数据库
                    Task {
                        await DataSyncManager.shared.syncLocalDataToCloud(modelContext: modelContext)
                    }
                }
        }
        .modelContainer(LiteLogApp.sharedModelContainer)
    }
}
