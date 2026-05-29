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
        let modelConfiguration = ModelConfiguration(
            "LiteLog_v3",
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .automatic
        )

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
        }
        .modelContainer(LiteLogApp.sharedModelContainer)
    }
}
