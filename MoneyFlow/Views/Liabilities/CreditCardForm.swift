import SwiftUI
import SwiftData

struct CreditCardForm: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    var cardToEdit: CreditCard?

    @State private var name = ""
    @State private var limitText = ""
    @State private var balanceText = ""
    @State private var billingDay = 5
    @State private var dueDay = 25
    @State private var note = ""
    @State private var showsOptionalDetails = false
    @State private var validationMessage: String?
    @State private var saveSucceeded = false
    @FocusState private var focusedField: Field?

    private enum Field: Hashable { case name, balance, limit, note }
    private var isEditing: Bool { cardToEdit != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section("快速记录") {
                    TextField("信用卡名称", text: $name, prompt: Text("例如：日常消费卡"))
                        .submitLabel(.next)
                        .focused($focusedField, equals: .name)
                        .onSubmit { focusedField = .balance }

                    HStack {
                        Text("当前应还")
                        Spacer()
                        TextField("0.00", text: $balanceText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .focused($focusedField, equals: .balance)
                            .accessibilityLabel("当前应还金额")
                    }

                    Stepper("还款日：每月 \(dueDay) 日", value: $dueDay, in: 1...28)
                }

                Section {
                    DisclosureGroup("额度、账单日与备注", isExpanded: $showsOptionalDetails) {
                        HStack {
                            Text("信用额度")
                            Spacer()
                            TextField("可选", text: $limitText)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .focused($focusedField, equals: .limit)
                        }
                        Stepper("账单日：每月 \(billingDay) 日", value: $billingDay, in: 1...28)
                        TextField("备注（可选）", text: $note, axis: .vertical)
                            .lineLimit(2...4)
                            .focused($focusedField, equals: .note)
                    }
                }

                if let validationMessage {
                    Section {
                        Label(validationMessage, systemImage: "exclamationmark.circle.fill")
                            .foregroundStyle(.red)
                            .accessibilityLabel("无法保存：\(validationMessage)")
                    }
                }
            }
            .navigationTitle(isEditing ? "编辑信用卡" : "新增信用卡")
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

    private func populateForEditing() {
        guard let card = cardToEdit else {
            focusedField = .name
            return
        }
        name = card.name
        limitText = card.creditLimit.formatted(.number.precision(.fractionLength(0...2)))
        balanceText = card.currentBalance.formatted(.number.precision(.fractionLength(0...2)))
        billingDay = card.billingDay
        dueDay = card.dueDay
        note = card.note
        showsOptionalDetails = true
    }

    private func save() {
        if let error = EntryValidation.creditCard(name: name, balanceText: balanceText, limitText: limitText).first {
            validationMessage = error
            return
        }
        guard let balance = FinancialInputParser.number(from: balanceText) else { return }
        let limit = limitText.isEmpty ? max(balance, 0) : (FinancialInputParser.number(from: limitText) ?? 0)

        if let card = cardToEdit {
            card.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
            card.creditLimit = limit
            card.currentBalance = balance
            card.billingDay = billingDay
            card.dueDay = dueDay
            card.note = note.trimmingCharacters(in: .whitespacesAndNewlines)
            card.updatedAt = Date()
        } else {
            modelContext.insert(CreditCard(
                name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                creditLimit: limit,
                currentBalance: balance,
                billingDay: billingDay,
                dueDay: dueDay,
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
