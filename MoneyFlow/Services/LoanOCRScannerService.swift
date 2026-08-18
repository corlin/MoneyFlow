import Foundation
import UIKit
import Vision

/// OCR 解析出的单笔借款草稿对象（供用户核对、编辑及勾选）
struct ParsedLoanDraft: Identifiable, Hashable {
    let id: UUID
    var isSelected: Bool
    var name: String
    var category: LoanCategory
    var totalAmount: Double
    var remainingPrincipal: Double
    var annualRate: Double
    var repaymentMethod: RepaymentMethod
    var totalPeriods: Int
    var paidPeriods: Int
    var monthlyPayment: Double
    var paymentDayOfMonth: Int
    var startDate: Date
    var note: String

    init(
        id: UUID = UUID(),
        isSelected: Bool = true,
        name: String,
        category: LoanCategory = .consumerLoan,
        totalAmount: Double,
        remainingPrincipal: Double,
        annualRate: Double,
        repaymentMethod: RepaymentMethod = .equalPrincipal,
        totalPeriods: Int,
        paidPeriods: Int,
        monthlyPayment: Double,
        paymentDayOfMonth: Int,
        startDate: Date,
        note: String = ""
    ) {
        self.id = id
        self.isSelected = isSelected
        self.name = name
        self.category = category
        self.totalAmount = totalAmount
        self.remainingPrincipal = remainingPrincipal
        self.annualRate = annualRate
        self.repaymentMethod = repaymentMethod
        self.totalPeriods = totalPeriods
        self.paidPeriods = paidPeriods
        self.monthlyPayment = monthlyPayment
        self.paymentDayOfMonth = paymentDayOfMonth
        self.startDate = startDate
        self.note = note
    }

    /// 转换为独立的 SwiftData 实体
    func createLoanEntity(platformPrefix: String = "") -> Loan {
        let trimmedPrefix = platformPrefix.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalName: String
        if !trimmedPrefix.isEmpty {
            finalName = "\(trimmedPrefix)-\(name)"
        } else {
            finalName = name
        }

        let endDate = Calendar.current.date(byAdding: .month, value: max(1, totalPeriods - paidPeriods), to: Date()) ?? Date()

        return Loan(
            name: finalName,
            category: category,
            totalAmount: totalAmount,
            remainingPrincipal: remainingPrincipal,
            annualRate: annualRate,
            repaymentMethod: repaymentMethod,
            totalPeriods: totalPeriods,
            paidPeriods: paidPeriods,
            monthlyPayment: monthlyPayment,
            paymentDayOfMonth: paymentDayOfMonth,
            startDate: startDate,
            endDate: endDate,
            icon: category.defaultIcon,
            note: note.isEmpty ? "通过截图智能批量识别录入" : note
        )
    }
}

/// 识别原始文本行数据单元
struct RawOCRTextLine {
    let text: String
    let boundingBox: CGRect
}

enum LoanOCRScannerService {

    /// 使用 Apple 原生 Vision 离线识别图片中的所有文本
    static func recognizeText(from image: UIImage) async throws -> [RawOCRTextLine] {
        guard let cgImage = image.cgImage else {
            throw NSError(domain: "LoanOCRScannerService", code: -1, userInfo: [NSLocalizedDescriptionKey: "无法解析图片内容"])
        }

        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: [])
                    return
                }

                let lines: [RawOCRTextLine] = observations.compactMap { observation in
                    guard let candidate = observation.topCandidates(1).first else { return nil }
                    return RawOCRTextLine(text: candidate.string, boundingBox: observation.boundingBox)
                }

                // 按自上而下、从左到右排序 (Vision 坐标系原点在左下角，因此 Y 越大约在上方)
                let sortedLines = lines.sorted { line1, line2 in
                    if abs(line1.boundingBox.origin.y - line2.boundingBox.origin.y) > 0.015 {
                        return line1.boundingBox.origin.y > line2.boundingBox.origin.y
                    }
                    return line1.boundingBox.origin.x < line2.boundingBox.origin.x
                }

                continuation.resume(returning: sortedLines)
            }

            request.recognitionLevel = .accurate
            request.recognitionLanguages = ["zh-Hans", "zh-Hant", "en-US"]
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    /// 从识别到的文本行列表提取并反推所有的独立借款草稿
    static func parseLoanDrafts(from rawLines: [RawOCRTextLine]) -> [ParsedLoanDraft] {
        let fullTextLines = rawLines.map { $0.text.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        return parseLoanDrafts(fromTextLines: fullTextLines)
    }

    /// 核心金融解析算法：从多行文本中切分每笔借款块并逆向解算
    static func parseLoanDrafts(fromTextLines lines: [String]) -> [ParsedLoanDraft] {
        var drafts: [ParsedLoanDraft] = []

        // 寻找每个借款块的起始行索引
        // 典型标题行模式：`2025.09.02借款20,000.00元 | 信用贷款` 或 `2025.09.08借款10,000.00元`
        var blockStartIndices: [Int] = []

        for (index, line) in lines.enumerated() {
            if isLoanHeaderLine(line) {
                blockStartIndices.append(index)
            }
        }

        // 如果没有找到明确的 `xxxx.xx.xx借款...` 标题，尝试按包含 `本期应还` 或 `第x/x期` 切分
        if blockStartIndices.isEmpty {
            for (index, line) in lines.enumerated() {
                if line.contains("本期应还") || line.contains("应还") {
                    let start = max(0, index - 1)
                    if !blockStartIndices.contains(start) {
                        blockStartIndices.append(start)
                    }
                }
            }
        }

        guard !blockStartIndices.isEmpty else {
            return []
        }

        for (i, startIndex) in blockStartIndices.enumerated() {
            let endIndex = (i + 1 < blockStartIndices.count) ? blockStartIndices[i + 1] : lines.count
            let blockLines = Array(lines[startIndex..<endIndex])
            if let draft = parseSingleLoanBlock(blockLines) {
                drafts.append(draft)
            }
        }

        return drafts
    }

    /// 判定是否是单笔借款的头部行
    private static func isLoanHeaderLine(_ line: String) -> Bool {
        let clean = line.replacingOccurrences(of: " ", with: "")
        // 匹配包含借款日期与金额，例如：2025.09.02借款 或 借款20000 或 信用贷款
        if clean.contains("借款") && (clean.contains("元") || clean.range(of: #"\d{4}[.\-/]\d{2}"#, options: .regularExpression) != nil) {
            return true
        }
        if clean.range(of: #"\d{4}[.\-/]\d{2}[.\-/]\d{2}"#, options: .regularExpression) != nil && clean.contains("第") && clean.contains("期") {
            return true
        }
        return false
    }

    /// 解析单个借款文本块并逆向推导其金融参数
    private static func parseSingleLoanBlock(_ lines: [String]) -> ParsedLoanDraft? {
        let blockText = lines.joined(separator: "\n")

        // 1. 提取借款日期 (如 2025.09.02)
        var startDate = Date()
        var dateString = ""
        var paymentDay = 10
        if let dateRange = blockText.range(of: #"\d{4}[.\-/]\d{1,2}[.\-/]\d{1,2}"#, options: .regularExpression) {
            dateString = String(blockText[dateRange])
            let cleanDateStr = dateString.replacingOccurrences(of: "/", with: ".").replacingOccurrences(of: "-", with: ".")
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy.MM.dd"
            if let parsed = formatter.date(from: cleanDateStr) {
                startDate = parsed
                paymentDay = Calendar.current.component(.day, from: parsed)
            }
        }

        // 2. 提取原始借款金额 (如 20,000.00元)
        var totalAmount: Double = 0
        if let match = blockText.range(of: #"(?:借款)?\s*([0-9,]+\.?\d*)\s*元"#, options: .regularExpression) {
            let matchedStr = String(blockText[match])
            totalAmount = extractAmount(from: matchedStr)
        }

        // 3. 提取期数 (如 第12/12期 或 12/12期 或 第11/12期)
        var currentPeriod = 12
        var totalPeriods = 12
        if let periodRange = blockText.range(of: #"第?\s*(\d{1,3})\s*/\s*(\d{1,3})\s*期"#, options: .regularExpression) {
            let periodText = String(blockText[periodRange])
            let digits = periodText.components(separatedBy: CharacterSet.decimalDigits.inverted).filter { !$0.isEmpty }.compactMap { Int($0) }
            if digits.count >= 2 {
                currentPeriod = digits[0]
                totalPeriods = digits[1]
            } else if digits.count == 1 {
                totalPeriods = digits[0]
            }
        }

        // 4. 提取当期应还金额、本金、利息
        var monthlyPayment: Double = 0
        var currentPrincipal: Double = 0
        var currentInterest: Double = 0

        for line in lines {
            let clean = line.replacingOccurrences(of: " ", with: "")
            if clean.contains("本期应还") || clean.hasPrefix("应还") {
                monthlyPayment = extractAmount(from: line)
            } else if clean.contains("本金") && !clean.contains("借款") && !clean.contains("剩余") {
                currentPrincipal = extractAmount(from: line)
            } else if clean.contains("利息") {
                currentInterest = extractAmount(from: line)
            }
        }

        // 兜底补全金额
        if monthlyPayment == 0 && (currentPrincipal > 0 || currentInterest > 0) {
            monthlyPayment = currentPrincipal + currentInterest
        }
        if currentPrincipal == 0 && monthlyPayment > 0 && currentInterest > 0 {
            currentPrincipal = max(0, monthlyPayment - currentInterest)
        }

        // 5. 逆向推算还款方式与剩余本金
        // 等额本金特征：每期本金 = totalAmount / totalPeriods
        let paidPeriods = max(0, currentPeriod - 1)
        let remainingPeriods = max(1, totalPeriods - paidPeriods)

        var remainingPrincipal: Double = 0
        var repaymentMethod: RepaymentMethod = .equalPrincipal

        if totalAmount > 0 {
            let avgPrincipalPerPeriod = totalAmount / Double(totalPeriods)
            if currentPrincipal > 0 && abs(currentPrincipal - avgPrincipalPerPeriod) < 2.0 {
                // 等额本金
                repaymentMethod = .equalPrincipal
                remainingPrincipal = avgPrincipalPerPeriod * Double(remainingPeriods)
            } else {
                // 等额本息
                repaymentMethod = .equalPayment
                if currentPrincipal > 0 {
                    remainingPrincipal = currentPrincipal * Double(remainingPeriods)
                } else {
                    remainingPrincipal = totalAmount * (Double(remainingPeriods) / Double(totalPeriods))
                }
            }
        } else if currentPrincipal > 0 {
            // 没有总额时，由当期本金和总期数反推
            totalAmount = currentPrincipal * Double(totalPeriods)
            remainingPrincipal = currentPrincipal * Double(remainingPeriods)
        }

        // 如果已经到了最后一期 (如 12/12期)，剩余本金即等于本期本金
        if currentPeriod >= totalPeriods && currentPrincipal > 0 {
            remainingPrincipal = currentPrincipal
        }

        // 6. 逆向精确求解年化利率 (精准至小数点后 4 位)
        // 核心公式：当期计息本金 P_current_start = remainingPrincipal
        // r_annual = (currentInterest / P_current_start) * 12
        var annualRate: Double = 0.0620 // 默认兜底 6.20%
        let basePrincipalForInterest = remainingPrincipal > 0 ? remainingPrincipal : (currentPrincipal > 0 ? currentPrincipal : totalAmount)

        if currentInterest > 0 && basePrincipalForInterest > 0 {
            let solvedRate = (currentInterest / basePrincipalForInterest) * 12.0
            if solvedRate > 0.005 && solvedRate < 0.36 {
                // 四舍五入到万分之零点一 (小数点后 4 位精度)
                annualRate = (solvedRate * 10000.0).rounded() / 10000.0
            }
        }

        // 7. 生成借款名称
        let nameDateStr = dateString.isEmpty ? "消费贷" : dateString
        let wanAmountStr = totalAmount >= 10000 ? String(format: "¥%.1f万", totalAmount / 10000.0) : String(format: "¥%.0f", totalAmount)
        let name = "\(nameDateStr)(\(wanAmountStr))"

        guard totalAmount > 0 || remainingPrincipal > 0 || monthlyPayment > 0 else {
            return nil
        }

        return ParsedLoanDraft(
            isSelected: true,
            name: name,
            category: .consumerLoan,
            totalAmount: totalAmount > 0 ? totalAmount : remainingPrincipal,
            remainingPrincipal: remainingPrincipal > 0 ? remainingPrincipal : monthlyPayment,
            annualRate: annualRate,
            repaymentMethod: repaymentMethod,
            totalPeriods: totalPeriods,
            paidPeriods: paidPeriods,
            monthlyPayment: monthlyPayment,
            paymentDayOfMonth: paymentDay,
            startDate: startDate,
            note: "OCR提取 · 第\(currentPeriod)/\(totalPeriods)期 · 当期利息¥\(String(format: "%.2f", currentInterest))"
        )
    }

    /// 从带千分位和货币符号的字符串中提取数值
    private static func extractAmount(from text: String) -> Double {
        let pattern = #"([0-9,]+\.?\d*)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return 0 }
        let nsString = text as NSString
        let results = regex.matches(in: text, range: NSRange(location: 0, length: nsString.length))

        for match in results {
            let matchedString = nsString.substring(with: match.range).replacingOccurrences(of: ",", with: "")
            if let number = Double(matchedString), number > 0 {
                return number
            }
        }
        return 0
    }

    /// 内置示例截图文本数据（供在模拟器或无图时即刻体验）
    static var sampleScreenshotTextLines: [String] {
        [
            "本期应还借款 共4笔",
            "2025.09.02借款20,000.00元 | 信用贷款 第12/12期 >",
            "本期应还 1,675.35",
            "本金 1,666.74",
            "利息 8.61",
            "2025.09.08借款10,000.00元 | 信用贷款 第12/12期 >",
            "本期应还 837.68",
            "本金 833.37",
            "利息 4.31",
            "2025.09.22借款12,000.00元 | 信用贷款 第11/12期 >",
            "本期应还 1,010.33",
            "本金 1,000.00",
            "利息 10.33",
            "2025.09.26借款95,000.00元 | 信用贷款 第11/12期 >",
            "本期应还 7,998.47",
            "本金 7,916.66",
            "利息 81.81"
        ]
    }
}
