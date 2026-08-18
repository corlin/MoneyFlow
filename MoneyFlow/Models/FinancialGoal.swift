import Foundation
import SwiftUI
import SwiftData

enum GoalCategory: String, CaseIterable, Codable, Identifiable {
    case emergencyBuffer = "emergencyBuffer"
    case acceleratedDebtPaydown = "acceleratedDebtPaydown"
    case capitalMilestone = "capitalMilestone"
    case wealthAccumulation = "wealthAccumulation"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .emergencyBuffer: return "应急保障"
        case .acceleratedDebtPaydown: return "提前还贷"
        case .capitalMilestone: return "阶段心愿"
        case .wealthAccumulation: return "资产积累"
        }
    }

    var systemImage: String {
        switch self {
        case .emergencyBuffer: return "shield.fill"
        case .acceleratedDebtPaydown: return "bolt.fill"
        case .capitalMilestone: return "target"
        case .wealthAccumulation: return "chart.line.uptrend.xyaxis"
        }
    }

    var themeColor: Color {
        switch self {
        case .emergencyBuffer: return .blue
        case .acceleratedDebtPaydown: return .orange
        case .capitalMilestone: return .purple
        case .wealthAccumulation: return .green
        }
    }
}

enum GoalPriority: String, CaseIterable, Codable, Identifiable, Comparable {
    case essential = "essential"       // Tier 1: 刚性保障
    case important = "important"       // Tier 2: 关键进阶
    case aspirational = "aspirational" // Tier 3: 弹性心愿

    var id: String { rawValue }

    var title: String {
        switch self {
        case .essential: return "必需 (Tier 1)"
        case .important: return "重要 (Tier 2)"
        case .aspirational: return "心愿 (Tier 3)"
        }
    }

    var shortTitle: String {
        switch self {
        case .essential: return "必需"
        case .important: return "重要"
        case .aspirational: return "心愿"
        }
    }

    var rank: Int {
        switch self {
        case .essential: return 1
        case .important: return 2
        case .aspirational: return 3
        }
    }

    static func < (lhs: GoalPriority, rhs: GoalPriority) -> Bool {
        lhs.rank < rhs.rank
    }
}

@Model
final class FinancialGoal {
    var id: UUID = UUID()
    var name: String = ""
    var categoryRaw: String = GoalCategory.capitalMilestone.rawValue
    var targetAmount: Double = 0.0
    var currentEarmarkedAmount: Double = 0.0 // 已锁定的存量现金
    var priorityRaw: String = GoalPriority.important.rawValue
    var targetDate: Date?
    var targetLoanId: UUID?
    var note: String = ""
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    var category: GoalCategory {
        get { GoalCategory(rawValue: categoryRaw) ?? .capitalMilestone }
        set { categoryRaw = newValue.rawValue }
    }

    var priority: GoalPriority {
        get { GoalPriority(rawValue: priorityRaw) ?? .important }
        set { priorityRaw = newValue.rawValue }
    }

    var remainingGap: Double {
        max(0, targetAmount - currentEarmarkedAmount)
    }

    var earmarkedRatio: Double {
        guard targetAmount > 0 else { return 1.0 }
        return min(1.0, max(0.0, currentEarmarkedAmount / targetAmount))
    }

    var isCompleted: Bool {
        currentEarmarkedAmount >= targetAmount && targetAmount > 0
    }

    init(
        id: UUID = UUID(),
        name: String,
        category: GoalCategory = .capitalMilestone,
        targetAmount: Double,
        currentEarmarkedAmount: Double = 0,
        priority: GoalPriority = .important,
        targetDate: Date? = nil,
        targetLoanId: UUID? = nil,
        note: String = "",
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.categoryRaw = category.rawValue
        self.targetAmount = targetAmount
        self.currentEarmarkedAmount = currentEarmarkedAmount
        self.priorityRaw = priority.rawValue
        self.targetDate = targetDate
        self.targetLoanId = targetLoanId
        self.note = note
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
