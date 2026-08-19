import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase

    @Query private var settingsList: [UserSettings]
    @Query private var loans: [Loan]
    @Query private var creditCards: [CreditCard]
    @Query private var cashAccounts: [CashAccount]

    @State private var selectedTab = 0
    @ObservedObject private var lockService = BiometricLockService.shared

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var currentSettings: UserSettings {
        if let existing = settingsList.first {
            return existing
        }
        let initial = UserSettings()
        modelContext.insert(initial)
        return initial
    }

    private var isPrivacyShieldActive: Bool {
        lockService.isLocked || (scenePhase == .background && currentSettings.isBiometricLockEnabled)
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
            .blur(radius: isPrivacyShieldActive ? 24 : 0)
            .allowsHitTesting(!isPrivacyShieldActive)
            .animation(AppMotion.animation(for: .spatial, reduceMotion: reduceMotion), value: isPrivacyShieldActive)

            // 后台或锁定状态防窥遮罩
            if isPrivacyShieldActive {
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
                    WidgetSnapshotService.shared.syncSnapshot(
                        accounts: cashAccounts,
                        loans: loans,
                        creditCards: creditCards,
                        settings: currentSettings
                    )
                },
                onCompleteManual: {
                    currentSettings.hasCompletedOnboarding = true
                    try? modelContext.save()
                    WidgetSnapshotService.shared.syncSnapshot(
                        accounts: cashAccounts,
                        loans: loans,
                        creditCards: creditCards,
                        settings: currentSettings
                    )
                }
            )
        }
        .onAppear {
            lockService.handleColdBoot(isEnabled: currentSettings.isBiometricLockEnabled)
            WidgetSnapshotService.shared.syncSnapshot(
                accounts: cashAccounts,
                loans: loans,
                creditCards: creditCards,
                settings: currentSettings
            )
        }
        .onOpenURL { url in
            handleDeepLink(url: url)
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .background:
                lockService.handleAppDidEnterBackground(
                    isEnabled: currentSettings.isBiometricLockEnabled,
                    timeoutSeconds: currentSettings.autoLockIntervalSeconds
                )
                WidgetSnapshotService.shared.syncSnapshot(
                    accounts: cashAccounts,
                    loans: loans,
                    creditCards: creditCards,
                    settings: currentSettings
                )
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
                WidgetSnapshotService.shared.syncSnapshot(
                    accounts: cashAccounts,
                    loans: loans,
                    creditCards: creditCards,
                    settings: currentSettings
                )
            case .inactive:
                break
            @unknown default:
                break
            }
        }
    }

    private func handleDeepLink(url: URL) {
        guard let host = url.host else { return }
        switch host {
        case "overview":
            selectedTab = 0
        case "planning":
            selectedTab = 1
        case "assets":
            selectedTab = 2
        case "liabilities":
            selectedTab = 3
        default:
            break
        }
    }
}

#Preview {
    ContentView()
}

