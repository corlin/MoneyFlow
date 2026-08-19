import SwiftUI
import SwiftData

struct CustomCashFlowEventFormSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    var initialDate: Date = Date()
    var eventToEdit: CustomCashFlowEvent? = nil

    @State private var title: String = ""
    @State private var amountString: String = ""
    @State private var isIncome: Bool = true
    @State private var date: Date = Date()
    @State private var isRecurringMonthly: Bool = false
    @State private var selectedIcon: String = "banknote.fill"
    @State private var notes: String = ""

    private let availableIcons = [
        "banknote.fill", "gift.fill", "arrow.down.circle.fill", "briefcase.fill",
        "cart.fill", "car.fill", "house.fill", "cross.case.fill", "arrow.up.circle.fill"
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("收支类型", selection: $isIncome) {
                        Text("🟢 收入 / 进账").tag(true)
                        Text("🔴 支出 / 出账").tag(false)
                    }
                    .pickerStyle(.segmented)

                    TextField("事件标题 (如：季度奖金、车险保费)", text: $title)

                    HStack {
                        Text("金额")
                            .foregroundStyle(.secondary)
                        Spacer()
                        TextField("0.00", text: $amountString)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .font(.system(.body, design: .rounded, weight: .bold))
                            .foregroundStyle(isIncome ? .green : .red)
                    }
                } header: {
                    Text("基本信息")
                }

                Section {
                    DatePicker("发生日期", selection: $date, displayedComponents: [.date])
                    Toggle("每月固定循环", isOn: $isRecurringMonthly)
                        .tint(Color.appPrimary)
                } header: {
                    Text("时间与周期")
                }

                Section {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(availableIcons, id: \.self) { icon in
                                Button {
                                    selectedIcon = icon
                                } label: {
                                    Image(systemName: icon)
                                        .font(.title3)
                                        .frame(width: 44, height: 44)
                                        .background(selectedIcon == icon ? Color.appPrimary.opacity(0.2) : Color(.secondarySystemBackground))
                                        .foregroundColor(selectedIcon == icon ? Color.appPrimary : .primary)
                                        .clipShape(Circle())
                                        .overlay(
                                            Circle()
                                                .stroke(selectedIcon == icon ? Color.appPrimary : Color.clear, lineWidth: 2)
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                } header: {
                    Text("图标")
                }

                Section {
                    TextField("添加事件备注（可选）", text: $notes)
                } header: {
                    Text("备注")
                }

                if eventToEdit != nil {
                    Section {
                        Button(role: .destructive) {
                            if let event = eventToEdit {
                                modelContext.delete(event)
                                try? modelContext.save()
                                dismiss()
                            }
                        } label: {
                            HStack {
                                Spacer()
                                Text("删除此事件")
                                Spacer()
                            }
                        }
                    }
                }
            }
            .navigationTitle(eventToEdit == nil ? "添加日历收支" : "编辑日历收支")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        saveEvent()
                    }
                    .fontWeight(.semibold)
                    .tint(Color.appPrimary)
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty || (Double(amountString) ?? 0) <= 0)
                }
            }
            .onAppear {
                if let event = eventToEdit {
                    title = event.title
                    amountString = String(format: "%.2f", event.amount)
                    isIncome = event.isIncome
                    date = event.date
                    isRecurringMonthly = event.isRecurringMonthly
                    selectedIcon = event.icon
                    notes = event.notes
                } else {
                    date = initialDate
                }
            }
        }
    }

    private func saveEvent() {
        guard let amount = Double(amountString), amount > 0 else { return }

        if let event = eventToEdit {
            event.title = title.trimmingCharacters(in: .whitespaces)
            event.amount = amount
            event.isIncome = isIncome
            event.date = date
            event.isRecurringMonthly = isRecurringMonthly
            event.icon = selectedIcon
            event.notes = notes
            event.updatedAt = Date()
        } else {
            let newEvent = CustomCashFlowEvent(
                title: title.trimmingCharacters(in: .whitespaces),
                amount: amount,
                isIncome: isIncome,
                date: date,
                isRecurringMonthly: isRecurringMonthly,
                icon: selectedIcon,
                notes: notes
            )
            modelContext.insert(newEvent)
        }

        try? modelContext.save()
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        dismiss()
    }
}
