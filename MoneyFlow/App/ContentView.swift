import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase

    @Query private var settingsList: [UserSettings]
    @Query private var loans: [Loan]
    @Query private var creditCards: [CreditCard]

    @State private var selectedTab = 0
    @ObservedObject private var lockService = BiometricLockService.shared

    private var currentSettings: UserSettings {
        if let existing = settingsList.first {
            return existing
        }
        let initial = UserSettings()
        modelContext.insert(initial)
        return initial
    }

    var body: some View {
        ZStack {
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

            // 后台或锁定状态防窥遮罩
            if (lockService.isLocked || (scenePhase != .active && currentSettings.isBiometricLockEnabled)) {
                PrivacyBlurOverlayView()
                    .zIndex(100)
            }
        }
        .fullScreenCover(isPresented: Binding(
            get: { !currentSettings.hasCompletedOnboarding },
            set: { _ in }
        )) {
            OnboardingFlowView(
                onCompleteWithDemo: {
                    try? DemoDataService.load(into: modelContext, replacingExisting: true, persona: .debtRelief)
                    currentSettings.hasCompletedOnboarding = true
                    try? modelContext.save()
                    NotificationService.shared.scheduleAllReminders(
                        loans: loans,
                        creditCards: creditCards,
                        isEnabled: currentSettings.isPaymentReminderEnabled,
                        daysBefore: currentSettings.reminderDaysBefore
                    )
                },
                onCompleteManual: {
                    currentSettings.hasCompletedOnboarding = true
                    try? modelContext.save()
                }
            )
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .background:
                lockService.handleAppDidEnterBackground(isEnabled: currentSettings.isBiometricLockEnabled)
            case .active:
                lockService.handleAppWillEnterForeground(
                    isEnabled: currentSettings.isBiometricLockEnabled,
                    timeoutSeconds: currentSettings.autoLockIntervalSeconds
                )
                if currentSettings.isPaymentReminderEnabled {
                    NotificationService.shared.scheduleAllReminders(
                        loans: loans,
                        creditCards: creditCards,
                        isEnabled: true,
                        daysBefore: currentSettings.reminderDaysBefore
                    )
                }
            case .inactive:
                break
            @unknown default:
                break
            }
        }
    }
}

#Preview {
    ContentView()
}

