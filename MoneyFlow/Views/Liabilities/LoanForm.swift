import SwiftUI
import SwiftData

struct LoanForm: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    var loanToEdit: Loan?

    @State private var name = ""
    @State private var category: LoanCategory = .mortgage
    @State private var totalAmountText = ""
    @State private var remainingPrincipalText = ""
    @State private var monthlyPaymentText = ""
    @State private var annualRatePercentText = ""
    @State private var repaymentMethod: RepaymentMethod = .equalPayment
    @State private var totalPeriodsText = "360"
    @State private var paidPeriodsText = "0"
    @State private var paymentDayOfMonth = 10
    @State private var startDate = Date()
    @State private var note = ""
    @State private var showsPreciseDetails = false
    @State private var validationMessage: String?
    @State private var saveSucceeded = false
    @FocusState private var focusedField: Field?

    private enum Field: Hashable { case name, remaining, payment, rate, total, totalPeriods, paidPeriods, note }
    private var isEditing: Bool { loanToEdit != nil }

    private var parsedTotalPeriods: Int {
        Int(totalPeriodsText.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 360
    }

    private var parsedPaidPeriods: Int {
        Int(paidPeriodsText.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
    }

    private var estimatedMonthlyPayment: Double {
        guard let total = FinancialInputParser.number(from: totalAmountText),
              let ratePercent = FinancialInputParser.number(from: annualRatePercentText),
              total > 0, parsedTotalPeriods > 0 else { return 0 }
        return RepaymentCalculator.calculateSchedule(
            principal: total,
            annualRate: ratePercent / 100,
            totalPeriods: parsedTotalPeriods,
            method: repaymentMethod,
            startDate: startDate,
            paymentDay: paymentDayOfMonth
        ).initialMonthlyPayment
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("快速记录") {
                    TextField("贷款名称", text: $name, prompt: Text("例如：住房贷款"))
                        .submitLabel(.next)
                        .focused($focusedField, equals: .name)
                        .onSubmit { focusedField = .remaining }

                    Picker("贷款类别", selection: $category) {
                        ForEach(LoanCategory.allCases) { Text($0.rawValue).tag($0) }
                    }

                    amountField("剩余本金", text: $remainingPrincipalText, focus: .remaining)
                    amountField("当前月供", text: $monthlyPaymentText, focus: .payment)

                    HStack {
                        Text("年化利率")
                        Spacer()
                        TextField("3.5%", text: $annualRatePercentText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .focused($focusedField, equals: .rate)
                            .accessibilityLabel("年化利率百分比")
                    }
                    Stepper("还款日：每月 \(paymentDayOfMonth) 日", value: $paymentDayOfMonth, in: 1...28)
                }

                Section {
                    DisclosureGroup("精确试算设置", isExpanded: $showsPreciseDetails) {
                        amountField("原始贷款金额", text: $totalAmountText, focus: .total)

                        Picker("还款方式", selection: $repaymentMethod) {
                            ForEach(RepaymentMethod.allCases) { Text($0.rawValue).tag($0) }
                        }
                        Text(repaymentMethod.description)
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        // 手工输入总期数与 Stepper 微调联动
                        HStack {
                            Text("总期数")
                            Spacer()
                            TextField("360", text: $totalPeriodsText)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 80)
                                .focused($focusedField, equals: .totalPeriods)
                            Text("期")
                                .foregroundStyle(.secondary)

                            Stepper("", value: Binding(
                                get: { parsedTotalPeriods },
                                set: { totalPeriodsText = String(max(1, min(600, $0))) }
                            ), in: 1...600)
                            .labelsHidden()
                        }

                        // 手工输入已还期数与 Stepper 微调联动
                        HStack {
                            Text("已还期数")
                            Spacer()
                            TextField("0", text: $paidPeriodsText)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 80)
                                .focused($focusedField, equals: .paidPeriods)
                            Text("期")
                                .foregroundStyle(.secondary)

                            Stepper("", value: Binding(
                                get: { parsedPaidPeriods },
                                set: { paidPeriodsText = String(max(0, min(parsedTotalPeriods, $0))) }
                            ), in: 0...max(1, parsedTotalPeriods))
                            .labelsHidden()
                        }

                        DatePicker("起始日期", selection: $startDate, displayedComponents: .date)

                        if estimatedMonthlyPayment > 0 {
                            LabeledContent("试算首期月供") {
                                CurrencyText(amount: estimatedMonthlyPayment, weight: .semibold)
                            }
                        }

                        TextField("备注（可选）", text: $note, axis: .vertical)
                            .lineLimit(2...4)
                            .focused($focusedField, equals: .note)
                    }
                } footer: {
                    Text("快速记录用于现金压力判断；展开后可手工输入期数生成更精确的完整还款计划。")
                }

                if let validationMessage {
                    Section {
                        Label(validationMessage, systemImage: "exclamationmark.circle.fill")
                            .foregroundStyle(.red)
                            .accessibilityLabel("无法保存：\(validationMessage)")
                    }
                }
            }
            .navigationTitle(isEditing ? "编辑贷款" : "新增贷款")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("保存", action: save) }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("完成") { focusedField = nil }
                }
            }
            .onAppear(perform: populateForEditing)
            .sensoryFeedback(.success, trigger: saveSucceeded)
        }
    }

    private func amountField(_ title: String, text: Binding<String>, focus: Field) -> some View {
        HStack {
            Text(title)
            Spacer()
            TextField("0.00", text: text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .focused($focusedField, equals: focus)
                .accessibilityLabel(title)
        }
    }

    private func populateForEditing() {
        guard let loan = loanToEdit else {
            focusedField = .name
            return
        }
        name = loan.name
        category = loan.category
        totalAmountText = numberText(loan.totalAmount)
        remainingPrincipalText = numberText(loan.remainingPrincipal)
        monthlyPaymentText = numberText(loan.monthlyPayment)
        annualRatePercentText = numberText(loan.annualRate * 100, maxFractions: 4)
        repaymentMethod = loan.repaymentMethod
        totalPeriodsText = String(loan.totalPeriods)
        paidPeriodsText = String(loan.paidPeriods)
        paymentDayOfMonth = loan.paymentDayOfMonth
        startDate = loan.startDate
        note = loan.note
        showsPreciseDetails = true
    }

    private func numberText(_ value: Double, maxFractions: Int = 2) -> String {
        value.formatted(.number.precision(.fractionLength(0...maxFractions)))
    }

    private func save() {
        if let error = EntryValidation.loan(
            name: name,
            remainingPrincipalText: remainingPrincipalText,
            monthlyPaymentText: monthlyPaymentText,
            annualRateText: annualRatePercentText
        ).first {
            validationMessage = error
            return
        }

        guard let remainingPrincipal = FinancialInputParser.number(from: remainingPrincipalText),
              let monthlyPayment = FinancialInputParser.number(from: monthlyPaymentText),
              let ratePercent = FinancialInputParser.number(from: annualRatePercentText) else { return }

        let totalPeriods = max(1, parsedTotalPeriods)
        let paidPeriods = max(0, min(totalPeriods, parsedPaidPeriods))
        let totalAmount = FinancialInputParser.number(from: totalAmountText) ?? remainingPrincipal
        let annualRate = ratePercent / 100
        let endDate = Calendar.current.date(byAdding: .month, value: max(1, totalPeriods - paidPeriods), to: Date()) ?? Date()

        if let loan = loanToEdit {
            loan.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
            loan.category = category
            loan.totalAmount = totalAmount
            loan.remainingPrincipal = remainingPrincipal
            loan.annualRate = annualRate
            loan.repaymentMethod = repaymentMethod
            loan.totalPeriods = totalPeriods
            loan.paidPeriods = paidPeriods
            loan.monthlyPayment = monthlyPayment
            loan.paymentDayOfMonth = paymentDayOfMonth
            loan.startDate = startDate
            loan.endDate = endDate
            loan.icon = category.defaultIcon
            loan.note = note.trimmingCharacters(in: .whitespacesAndNewlines)
            loan.updatedAt = Date()
        } else {
            modelContext.insert(Loan(
                name: name.trimmingCharacters(in: .whitespacesAndNewlines),
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
                note: note.trimmingCharacters(in: .whitespacesAndNewlines)
            ))
        }

        do {
            try modelContext.save()
            saveSucceeded.toggle()
            dismiss()
        } catch {
            modelContext.rollback()
            validationMessage = "保存失败，请稍后重试。\(error.localizedDescription)"
        }
    }
}
