import Foundation

struct GoalProjectionItem: Identifiable, Equatable {
    var id: UUID { goal.id }
    let goal: FinancialGoal
    let initialEarmarked: Double
    let projectedIrrigation: Double
    let projectedTotal: Double
    let targetAmount: Double
    let remainingGap: Double
    let completionDate: Date?
    let completionMonthIndex: Int?
    let isOnTrack: Bool
    let delayedMonths: Int

    var progressRatio: Double {
        guard targetAmount > 0 else { return 1.0 }
        return min(1.0, max(0.0, projectedTotal / targetAmount))
    }

    var earmarkedProgressRatio: Double {
        guard targetAmount > 0 else { return 1.0 }
        return min(1.0, max(0.0, initialEarmarked / targetAmount))
    }

    var irrigationProgressRatio: Double {
        guard targetAmount > 0 else { return 0.0 }
        return min(1.0 - earmarkedProgressRatio, max(0.0, projectedIrrigation / targetAmount))
    }
}

struct MultiGoalSummary: Equatable {
    let totalTargetAmount: Double
    let totalEarmarkedAmount: Double
    let totalRemainingGap: Double
    let availableFreeCash: Double
    let isOverAllocated: Bool
    let goalProjections: [GoalProjectionItem]
    let onTimeGoalCount: Int
    let delayedGoalCount: Int

    var overallCompletionRatio: Double {
        guard totalTargetAmount > 0 else { return 1.0 }
        return min(1.0, max(0.0, (totalEarmarkedAmount + goalProjections.reduce(0) { $0 + $1.projectedIrrigation }) / totalTargetAmount))
    }
}

enum MultiGoalEngine {

    /// 计算可用自由现金与多目标的虚拟分账情况
    static func calculateFreeCash(
        totalCash: Double,
        goals: [FinancialGoal]
    ) -> (freeCash: Double, totalEarmarked: Double, isOverAllocated: Bool) {
        let totalEarmarked = goals.reduce(0.0) { $0 + $1.currentEarmarkedAmount }
        let freeCash = max(0.0, totalCash - totalEarmarked)
        let isOverAllocated = totalEarmarked > totalCash
        return (freeCash, totalEarmarked, isOverAllocated)
    }

    /// 核心算法：将未来各月的自由结余现金流按优先级自适应灌溉至各目标池
    static func projectGoals(
        totalCash: Double,
        monthlySurpluses: [Double],
        monthDates: [Date],
        goals: [FinancialGoal]
    ) -> MultiGoalSummary {
        guard !goals.isEmpty else {
            let freeCash = totalCash
            return MultiGoalSummary(
                totalTargetAmount: 0,
                totalEarmarkedAmount: 0,
                totalRemainingGap: 0,
                availableFreeCash: freeCash,
                isOverAllocated: false,
                goalProjections: [],
                onTimeGoalCount: 0,
                delayedGoalCount: 0
            )
        }

        let (_, totalEarmarked, isOverAllocated) = calculateFreeCash(totalCash: totalCash, goals: goals)
        let freeCash = max(0.0, totalCash - totalEarmarked)

        // 排序规则：优先级排名 (essential -> important -> aspirational)，其次创建时间
        let sortedGoals = goals.sorted { g1, g2 in
            if g1.priority != g2.priority {
                return g1.priority < g2.priority
            }
            if let d1 = g1.targetDate, let d2 = g2.targetDate {
                return d1 < d2
            }
            return g1.createdAt < g2.createdAt
        }

        var accumulatedIrrigation: [UUID: Double] = [:]
        var completionDates: [UUID: (date: Date, monthIndex: Int)] = [:]

        // 初始化累计灌溉进度
        for goal in sortedGoals {
            accumulatedIrrigation[goal.id] = 0.0
            if goal.currentEarmarkedAmount >= goal.targetAmount && goal.targetAmount > 0 {
                completionDates[goal.id] = (monthDates.first ?? Date(), 0)
            }
        }

        // 逐月进行资金瀑布灌溉
        let horizonCount = min(monthlySurpluses.count, monthDates.count)
        for monthIdx in 0..<horizonCount {
            var surplusThisMonth = max(0.0, monthlySurpluses[monthIdx])
            let monthDate = monthDates[monthIdx]

            for goal in sortedGoals {
                if surplusThisMonth <= 0.001 { break }

                let currentTotal = goal.currentEarmarkedAmount + (accumulatedIrrigation[goal.id] ?? 0.0)
                let needed = max(0.0, goal.targetAmount - currentTotal)

                if needed > 0 {
                    let grant = min(surplusThisMonth, needed)
                    accumulatedIrrigation[goal.id] = (accumulatedIrrigation[goal.id] ?? 0.0) + grant
                    surplusThisMonth -= grant

                    // 检查是否在当月达成
                    if (accumulatedIrrigation[goal.id] ?? 0.0) + goal.currentEarmarkedAmount >= goal.targetAmount {
                        if completionDates[goal.id] == nil {
                            completionDates[goal.id] = (monthDate, monthIdx + 1)
                        }
                    }
                }
            }
        }

        var projectionItems: [GoalProjectionItem] = []
        var onTimeCount = 0
        var delayedCount = 0
        let calendar = Calendar.current

        for goal in sortedGoals {
            let earmarked = goal.currentEarmarkedAmount
            let irrigation = accumulatedIrrigation[goal.id] ?? 0.0
            let projectedTotal = earmarked + irrigation
            let gap = max(0.0, goal.targetAmount - projectedTotal)
            let completion = completionDates[goal.id]

            var isOnTrack = true
            var delayedMonths = 0

            if let targetDate = goal.targetDate {
                if let actualCompletion = completion?.date {
                    if actualCompletion > targetDate {
                        isOnTrack = false
                        let diff = calendar.dateComponents([.month], from: targetDate, to: actualCompletion).month ?? 0
                        delayedMonths = max(0, diff)
                    }
                } else {
                    // 在预测期内未能完成
                    isOnTrack = false
                    let endOfForecast = monthDates.last ?? Date()
                    let diff = calendar.dateComponents([.month], from: targetDate, to: endOfForecast).month ?? 0
                    delayedMonths = max(1, diff)
                }
            }

            if isOnTrack {
                onTimeCount += 1
            } else {
                delayedCount += 1
            }

            projectionItems.append(GoalProjectionItem(
                goal: goal,
                initialEarmarked: earmarked,
                projectedIrrigation: irrigation,
                projectedTotal: projectedTotal,
                targetAmount: goal.targetAmount,
                remainingGap: gap,
                completionDate: completion?.date,
                completionMonthIndex: completion?.monthIndex,
                isOnTrack: isOnTrack,
                delayedMonths: delayedMonths
            ))
        }

        let totalTarget = sortedGoals.reduce(0.0) { $0 + $1.targetAmount }
        let totalGap = projectionItems.reduce(0.0) { $0 + $1.remainingGap }

        return MultiGoalSummary(
            totalTargetAmount: totalTarget,
            totalEarmarkedAmount: totalEarmarked,
            totalRemainingGap: totalGap,
            availableFreeCash: freeCash,
            isOverAllocated: isOverAllocated,
            goalProjections: projectionItems,
            onTimeGoalCount: onTimeCount,
            delayedGoalCount: delayedCount
        )
    }
}
