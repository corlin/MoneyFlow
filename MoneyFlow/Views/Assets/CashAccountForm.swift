import SwiftUI
import SwiftData

struct CashAccountForm: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    var accountToEdit: CashAccount?

    @State private var name = ""
    @State private var balanceText = ""
    @State private var icon = "banknote"
    @State private var note = ""
    @State private var showsOptionalDetails = false
    @State private var validationMessage: String?
    @State private var saveSucceeded = false
    @FocusState private var focusedField: Field?

    private let availableIcons = [
        "banknote", "creditcard", "building.columns", "dollarsign.circle",
        "bag", "wallet.pass", "safe", "chart.line.uptrend.xyaxis"
    ]

    private enum Field: Hashable { case name, balance, note }
    private var isEditing: Bool { accountToEdit != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section("快速记录") {
                    TextField("账户名称", text: $name, prompt: Text("例如：工资卡"))
                        .textContentType(.name)
                        .submitLabel(.next)
                        .focused($focusedField, equals: .name)
                        .onSubmit { focusedField = .balance }

                    HStack {
                        Text("当前余额")
                        Spacer()
                        TextField("0.00", text: $balanceText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .focused($focusedField, equals: .balance)
                            .accessibilityLabel("当前余额")
                    }
                }

                Section {
                    DisclosureGroup("图标与备注", isExpanded: $showsOptionalDetails) {
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 12) {
                            ForEach(availableIcons, id: \.self) { iconName in
                                Button {
                                    icon = iconName
                                } label: {
                                    Image(systemName: iconName)
                                        .font(.title2)
                                        .frame(minWidth: 44, minHeight: 44)
                                        .foregroundStyle(icon == iconName ? .white : .primary)
                                        .background(icon == iconName ? Color.appPrimary : Color(uiColor: .tertiarySystemFill))
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("账户图标 \(iconName)")
                                .accessibilityAddTraits(icon == iconName ? .isSelected : [])
                            }
                        }
                        .padding(.vertical, 8)

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
            .navigationTitle(isEditing ? "编辑资产" : "新增资产")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存", action: save)
                }
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
        guard let account = accountToEdit else {
            focusedField = .name
            return
        }
        name = account.name
        balanceText = account.balance.formatted(.number.precision(.fractionLength(0...2)))
        icon = account.icon
        note = account.note
        showsOptionalDetails = !note.isEmpty || icon != "banknote"
    }

    private func save() {
        if let error = EntryValidation.asset(name: name, balanceText: balanceText).first {
            validationMessage = error
            return
        }
        guard let balance = FinancialInputParser.number(from: balanceText) else { return }

        if let account = accountToEdit {
            account.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
            account.balance = balance
            account.icon = icon
            account.note = note.trimmingCharacters(in: .whitespacesAndNewlines)
            account.updatedAt = Date()
        } else {
            modelContext.insert(CashAccount(
                name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                balance: balance,
                icon: icon,
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
