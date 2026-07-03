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
        if UIDevice.current.userInterfaceIdiom == .pad {
            iPadLayout(selectedTab: $selectedTab)
        } else {
            iPhoneLayout(selectedTab: $selectedTab)
        }
    }
}

struct iPadLayout: View {
    @Binding var selectedTab: Int

    var body: some View {
        NavigationSplitView {
            List {
                SidebarButton(
                    title: NSLocalizedString("tab.home", comment: ""),
                    systemImage: "house.fill",
                    isSelected: selectedTab == 0,
                    action: { selectedTab = 0 }
                )
                SidebarButton(
                    title: NSLocalizedString("tab.statistics", comment: ""),
                    systemImage: "chart.bar.fill",
                    isSelected: selectedTab == 1,
                    action: { selectedTab = 1 }
                )
                SidebarButton(
                    title: NSLocalizedString("tab.record", comment: ""),
                    systemImage: "plus.circle.fill",
                    isSelected: selectedTab == 2,
                    action: { selectedTab = 2 }
                )
                SidebarButton(
                    title: NSLocalizedString("tab.settings", comment: ""),
                    systemImage: "gearshape.fill",
                    isSelected: selectedTab == 3,
                    action: { selectedTab = 3 }
                )
            }
            .navigationTitle(NSLocalizedString("app.name", comment: ""))
            .tint(.primaryBlue)
        } detail: {
            switch selectedTab {
            case 0:
                HomeView()
            case 1:
                StatisticsView()
            case 2:
                RecordView()
            case 3:
                SettingsView()
            default:
                HomeView()
            }
        }
    }
}

struct SidebarButton: View {
    let title: String
    let systemImage: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .foregroundColor(isSelected ? .primaryBlue : .secondary)
                Text(title)
                    .foregroundColor(isSelected ? .primaryBlue : .primary)
                Spacer()
            }
        }
        .listRowBackground(isSelected ? Color.primaryBlue.opacity(0.1) : Color.clear)
    }
}

struct iPhoneLayout: View {
    @Binding var selectedTab: Int

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
