//
//  ContentView.swift
//  LiteLog
//
//  Created by lt on 2026/5/11.
//


import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0
    @State private var selectedSidebarItem: TabItem = .home

    enum TabItem: Int, CaseIterable, Identifiable {
        case home = 0
        case statistics = 1
        case record = 2
        case settings = 3

        var id: Int { rawValue }

        var title: String {
            switch self {
            case .home: return NSLocalizedString("tab.home", comment: "")
            case .statistics: return NSLocalizedString("tab.statistics", comment: "")
            case .record: return NSLocalizedString("tab.record", comment: "")
            case .settings: return NSLocalizedString("tab.settings", comment: "")
            }
        }

        var icon: String {
            switch self {
            case .home: return "house.fill"
            case .statistics: return "chart.bar.fill"
            case .record: return "plus.circle.fill"
            case .settings: return "gearshape.fill"
            }
        }
    }

    var body: some View {
        if UIDevice.isPad {
            iPadLayout
        } else {
            iPhoneLayout
        }
    }

    private var iPhoneLayout: some View {
        TabView(selection: $selectedTab) {
            NavigationView {
                HomeView()
            }
            .tabItem {
                Label(NSLocalizedString("tab.home", comment: ""), systemImage: "house.fill")
            }
            .tag(0)

            NavigationView {
                StatisticsView()
            }
            .tabItem {
                Label(NSLocalizedString("tab.statistics", comment: ""), systemImage: "chart.bar.fill")
            }
            .tag(1)

            NavigationView {
                RecordView()
            }
            .tabItem {
                Label(NSLocalizedString("tab.record", comment: ""), systemImage: "plus.circle.fill")
            }
            .tag(2)

            NavigationView {
                SettingsView()
            }
            .tabItem {
                Label(NSLocalizedString("tab.settings", comment: ""), systemImage: "gearshape.fill")
            }
            .tag(3)
        }
        .tint(.primaryBlue)
    }

    private var iPadLayout: some View {
        NavigationView {
            VStack(spacing: 0) {
                Text(NSLocalizedString("app.name", comment: ""))
                    .font(.title)
                    .fontWeight(.bold)
                    .padding()

                List {
                    ForEach(TabItem.allCases) { item in
                        Button(action: {
                            selectedSidebarItem = item
                        }) {
                            HStack(spacing: 12) {
                                Image(systemName: item.icon)
                                    .foregroundColor(selectedSidebarItem == item ? .primaryBlue : .secondaryText)
                                Text(item.title)
                                    .foregroundColor(selectedSidebarItem == item ? .primaryText : .secondaryText)
                            }
                            .padding(.vertical, 8)
                        }
                        .listRowBackground(selectedSidebarItem == item ? Color.primaryBlue.opacity(0.1) : Color.clear)
                    }
                }
                .listStyle(.sidebar)
            }
            .navigationTitle("LiteLog")
        }
    }
}

#Preview {
    ContentView()
}
