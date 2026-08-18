import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            OverviewTab()
                .tabItem {
                    Label("概览", systemImage: "chart.pie.fill")
                }
                .tag(0)

            AssetsTab()
                .tabItem {
                    Label("资产", systemImage: "banknote.fill")
                }
                .tag(1)

            LiabilitiesTab()
                .tabItem {
                    Label("负债", systemImage: "doc.plaintext.fill")
                }
                .tag(2)
        }
        .tint(Color.appPrimary)
    }
}

#Preview {
    ContentView()
}
