import Foundation

extension Date {
    var yearMonthString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年M月"
        return formatter.string(from: self)
    }

    var monthShortString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M月"
        return formatter.string(from: self)
    }

    var yearMonthDayString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: self)
    }

    func addingMonths(_ months: Int) -> Date {
        Calendar.current.date(byAdding: .month, value: months, to: self) ?? self
    }

    var startOfMonth: Date {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: self)
        return calendar.date(from: components) ?? self
    }

    var dayOfMonth: Int {
        Calendar.current.component(.day, from: self)
    }

    func nextOccurrenceOf(day: Int) -> Date {
        let calendar = Calendar.current
        let currentDay = self.dayOfMonth
        let targetDay = max(1, min(day, 28)) // 保证日期有效

        var comp = calendar.dateComponents([.year, .month], from: self)
        comp.day = targetDay

        if currentDay > targetDay {
            // 下个月
            if let nextMonthDate = calendar.date(byAdding: .month, value: 1, to: self) {
                var nextComp = calendar.dateComponents([.year, .month], from: nextMonthDate)
                nextComp.day = targetDay
                return calendar.date(from: nextComp) ?? self
            }
        }
        return calendar.date(from: comp) ?? self
    }
}
