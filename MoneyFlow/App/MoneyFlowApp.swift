import SwiftUI
import SwiftData

@main
struct MoneyFlowApp: App {
    @State private var storeState: StoreState

    init() {
        _storeState = State(initialValue: Self.openStore())
    }

    var body: some Scene {
        WindowGroup {
            switch storeState {
            case .ready(let container):
                ContentView()
                    .modelContainer(container)
            case .failed(let message):
                PersistenceRecoveryView(
                    errorMessage: message,
                    onRetry: { storeState = Self.openStore() },
                    onReset: { storeState = Self.backupResetAndOpen() }
                )
            }
        }
    }

    private enum StoreState {
        case ready(ModelContainer)
        case failed(String)
    }

    private static var schema: Schema {
        Schema([
            CashAccount.self,
            Loan.self,
            CreditCard.self,
            UserSettings.self,
            FinancialGoal.self,
            LoanAdjustmentEvent.self,
            PaymentReconciliationRecord.self,
            CustomCashFlowEvent.self
        ])
    }

    private static var storeURL: URL {
        URL.applicationSupportDirectory.appending(path: "MoneyFlow_v2.sqlite")
    }

    private static func openStore() -> StoreState {
        do {
            let configuration = ModelConfiguration(url: storeURL)
            return .ready(try ModelContainer(for: schema, configurations: [configuration]))
        } catch {
            return .failed("无法打开本地财务数据。原始数据仍保留在设备上。\n\n\(error.localizedDescription)")
        }
    }

    private static func backupResetAndOpen() -> StoreState {
        do {
            try backupAndRemoveStore()
            return openStore()
        } catch {
            return .failed("无法创建恢复备份，因此没有删除任何数据。\n\n\(error.localizedDescription)")
        }
    }

    private static func backupAndRemoveStore() throws {
        _ = try StoreFileRecovery.backupAndRemoveStore(
            storeURL: storeURL,
            backupRoot: URL.applicationSupportDirectory.appending(path: "RecoveryBackups", directoryHint: .isDirectory)
        )
    }
}
