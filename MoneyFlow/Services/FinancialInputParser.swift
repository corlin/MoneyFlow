import Foundation

enum FinancialInputParser {
    static func number(from source: String) -> Double? {
        let trimmed = source.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let halfWidth = trimmed.applyingTransform(.fullwidthToHalfwidth, reverse: false) ?? trimmed
        let ignoredCurrencyCharacters = "¥￥$€£元"
        var filtered = ""
        for character in halfWidth {
            if character.isWhitespace || ignoredCurrencyCharacters.contains(character) { continue }
            guard character.isNumber || character == "." || character == "," || character == "-" else {
                return nil
            }
            filtered.append(character)
        }
        guard !filtered.isEmpty else { return nil }
        guard filtered.filter({ $0 == "-" }).count <= 1,
              !filtered.dropFirst().contains("-") else { return nil }

        let dotCount = filtered.filter { $0 == "." }.count
        let commaCount = filtered.filter { $0 == "," }.count

        if dotCount > 0 && commaCount > 0 {
            let lastDot = filtered.lastIndex(of: ".")!
            let lastComma = filtered.lastIndex(of: ",")!
            let decimalSeparator: Character = lastDot > lastComma ? "." : ","
            filtered = normalized(filtered, decimalSeparator: decimalSeparator)
        } else if commaCount > 0 {
            let groups = filtered.split(separator: ",", omittingEmptySubsequences: false)
            let isGrouping = groups.count > 1 && groups.dropFirst().allSatisfy { $0.count == 3 }
            filtered = isGrouping
                ? filtered.replacingOccurrences(of: ",", with: "")
                : normalized(filtered, decimalSeparator: ",")
        } else if dotCount > 1 {
            let groups = filtered.split(separator: ".", omittingEmptySubsequences: false)
            guard groups.dropFirst().allSatisfy({ $0.count == 3 }) else { return nil }
            filtered = filtered.replacingOccurrences(of: ".", with: "")
        }

        guard filtered.filter({ $0 == "." }).count <= 1 else { return nil }
        return Double(filtered)
    }

    private static func normalized(_ value: String, decimalSeparator: Character) -> String {
        var result = ""
        for character in value {
            if character == decimalSeparator {
                result.append(".")
            } else if character != "." && character != "," {
                result.append(character)
            }
        }
        return result
    }
}

enum EntryValidation {
    static func asset(name: String, balanceText: String) -> [String] {
        var errors: [String] = []
        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append("请输入账户名称")
        }
        if balanceText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append("请输入当前余额")
        } else if let balance = FinancialInputParser.number(from: balanceText), balance < 0 {
            errors.append("余额不能为负数")
        } else if FinancialInputParser.number(from: balanceText) == nil {
            errors.append("请输入有效余额")
        }
        return errors
    }

    static func creditCard(name: String, balanceText: String, limitText: String) -> [String] {
        var errors: [String] = []
        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append("请输入卡片名称")
        }
        if balanceText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append("请输入当前欠款")
        } else if let balance = FinancialInputParser.number(from: balanceText), balance < 0 {
            errors.append("欠款金额不能为负数")
        } else if FinancialInputParser.number(from: balanceText) == nil {
            errors.append("请输入有效欠款金额")
        }
        if !limitText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            if let limit = FinancialInputParser.number(from: limitText), limit < 0 {
                errors.append("信用额度不能为负数")
            } else if FinancialInputParser.number(from: limitText) == nil {
                errors.append("请输入有效信用额度")
            }
        }
        return errors
    }

    static func loan(
        name: String,
        remainingPrincipalText: String,
        monthlyPaymentText: String,
        annualRateText: String
    ) -> [String] {
        var errors: [String] = []
        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append("请输入贷款名称")
        }
        appendRequiredNumberError(remainingPrincipalText, empty: "请输入剩余本金", invalid: "请输入有效剩余本金", to: &errors)
        appendRequiredNumberError(monthlyPaymentText, empty: "请输入当前月供", invalid: "请输入有效月供", to: &errors)
        appendRequiredNumberError(annualRateText, empty: "请输入年化利率", invalid: "请输入有效年化利率", to: &errors)
        if let principal = FinancialInputParser.number(from: remainingPrincipalText), principal <= 0 {
            errors.removeAll { $0 == "请输入有效剩余本金" }
            errors.append("剩余本金必须大于 0")
        }
        if let payment = FinancialInputParser.number(from: monthlyPaymentText), payment <= 0 {
            errors.removeAll { $0 == "请输入有效月供" }
            errors.append("月供必须大于 0")
        }
        if let rate = FinancialInputParser.number(from: annualRateText), rate < 0 {
            errors.removeAll { $0 == "请输入有效年化利率" }
            errors.append("年化利率不能为负数")
        }
        return errors
    }

    private static func appendRequiredNumberError(_ text: String, empty: String, invalid: String, to errors: inout [String]) {
        if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append(empty)
        } else if FinancialInputParser.number(from: text) == nil {
            errors.append(invalid)
        }
    }
}
