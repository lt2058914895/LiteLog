//
//  ContentView.swift
//  LiteLog
//
//  Created by lt on 2026/5/11.
//

import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem {
                    Label(NSLocalizedString("tab.home", comment: ""), systemImage: "house.fill")
                }
                .tag(0)

            StatisticsView()
                .tabItem {
                    Label(NSLocalizedString("tab.statistics", comment: ""), systemImage: "chart.bar.fill")
                }
                .tag(1)

            RecordView()
                .tabItem {
                    Label(NSLocalizedString("tab.record", comment: ""), systemImage: "plus.circle.fill")
                }
                .tag(2)

            SettingsView()
                .tabItem {
                    Label(NSLocalizedString("tab.settings", comment: ""), systemImage: "gearshape.fill")
                }
                .tag(3)
        }
        .tint(.primaryBlue)
    }
}

#Preview {
    ContentView()
}
