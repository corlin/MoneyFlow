import Foundation

struct WishlistTemplate: Identifiable, Equatable {
    let id: String
    let name: String
    let icon: String
    let defaultTargetAmount: Double
    let category: GoalCategory
    let badgeText: String
    let tagColorHex: String
    let promptDescription: String

    static let presets: [WishlistTemplate] = [
        WishlistTemplate(
            id: "phone",
            name: "换新手机 / 电脑",
            icon: "iphone.gen3",
            defaultTargetAmount: 8000,
            category: .capitalMilestone,
            badgeText: "数码好物 📱",
            tagColorHex: "#007AFF",
            promptDescription: "犒劳自己一台旗舰手机或生产力电脑"
        ),
        WishlistTemplate(
            id: "travel",
            name: "年假旅行 / 看演唱会",
            icon: "airplane.departure",
            defaultTargetAmount: 6000,
            category: .capitalMilestone,
            badgeText: "休假看世界 ✈️",
            tagColorHex: "#FF9500",
            promptDescription: "去海边度假、自驾游或见喜欢的歌手"
        ),
        WishlistTemplate(
            id: "parents_health",
            name: "父母体检 / 家人健康",
            icon: "cross.case.fill",
            defaultTargetAmount: 3000,
            category: .emergencyBuffer,
            badgeText: "孝敬关爱 🩺",
            tagColorHex: "#34C759",
            promptDescription: "为父母预约一次全面的年度深度体检"
        ),
        WishlistTemplate(
            id: "new_year",
            name: "过年红包 / 年终大件",
            icon: "gift.fill",
            defaultTargetAmount: 5000,
            category: .capitalMilestone,
            badgeText: "春节心愿 🧧",
            tagColorHex: "#FF3B30",
            promptDescription: "年底回家过年给长辈晚辈包红包与置办年货"
        ),
        WishlistTemplate(
            id: "car",
            name: "买车首付 / 换车基金",
            icon: "car.fill",
            defaultTargetAmount: 30000,
            category: .capitalMilestone,
            badgeText: "出行自由 🚗",
            tagColorHex: "#5856D6",
            promptDescription: "为人生第一台车或新能源车备足首付"
        ),
        WishlistTemplate(
            id: "emergency_buffer",
            name: "3个月应急底气金",
            icon: "shield.checkered",
            defaultTargetAmount: 15000,
            category: .emergencyBuffer,
            badgeText: "家庭防线 🛡️",
            tagColorHex: "#30B0C7",
            promptDescription: "无论发生什么，都有足够的生活缓冲底气"
        )
    ]
}
