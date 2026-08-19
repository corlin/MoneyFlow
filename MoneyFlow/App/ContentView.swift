import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            OverviewTab(selectedTab: $selectedTab)
                .tabItem {
                    Label("概览", systemImage: "square.grid.2x2.fill")
                }
                .tag(0)

            PlanningTab()
                .tabItem {
                    Label("规划", systemImage: "chart.xyaxis.line")
                }
                .tag(1)

            AssetsTab()
                .tabItem {
                    Label("资产", systemImage: "banknote.fill")
                }
                .tag(2)

            LiabilitiesTab()
                .tabItem {
                    Label("负债", systemImage: "creditcard.fill")
                }
                .tag(3)
        }
        .tint(Color.appPrimary)
    }
}

#Preview {
    ContentView()
}
