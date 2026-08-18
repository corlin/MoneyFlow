import SwiftUI
import SwiftData
import PhotosUI

struct BatchLoanOCRImportSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var isProcessingOCR = false
    @State private var parsedDrafts: [ParsedLoanDraft] = []
    @State private var platformPrefix = "微粒贷"
    @State private var errorMessage: String?
    @State private var saveSucceeded = false
    @State private var customPrefixText = ""

    private let presetPrefixes = ["微粒贷", "借呗", "度小满", "京东金条", "分期乐", "其他"]

    private var selectedDraftsCount: Int {
        parsedDrafts.filter { $0.isSelected }.count
    }

    private var totalRemainingPrincipalSelected: Double {
        parsedDrafts.filter { $0.isSelected }.reduce(0.0) { $0 + $1.remainingPrincipal }
    }

    private var totalMonthlyPaymentSelected: Double {
        parsedDrafts.filter { $0.isSelected }.reduce(0.0) { $0 + $1.monthlyPayment }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 16) {
                    // 1. 选图与识别控制台
                    imagePickerControlCard

                    // 2. 批量前缀设置栏
                    if !parsedDrafts.isEmpty {
                        platformPrefixSection
                    }

                    // 3. 识别状态与统计摘要
                    if isProcessingOCR {
                        processingIndicatorCard
                    } else if !parsedDrafts.isEmpty {
                        summaryStatsBanner
                    }

                    // 4. 解析出的单笔借款卡片列表
                    if !parsedDrafts.isEmpty {
                        draftsListView
                    } else if selectedImage == nil && !isProcessingOCR {
                        emptyStateGuideCard
                    }

                    if let errorMessage {
                        errorBanner(errorMessage)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 100) // 留出吸底按钮空间
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("📸 截图批量录入")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom) {
                if selectedDraftsCount > 0 {
                    bottomImportBar
                }
            }
            .onChange(of: selectedPhotoItem) { _, newItem in
                Task {
                    guard let newItem else { return }
                    if let data = try? await newItem.loadTransferable(type: Data.self),
                       let uiImage = UIImage(data: data) {
                        await processImage(uiImage)
                    }
                }
            }
            .sensoryFeedback(.success, trigger: saveSucceeded)
        }
    }

    // MARK: - 选图控制台
    private var imagePickerControlCard: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                    HStack(spacing: 6) {
                        Image(systemName: "photo.on.rectangle.angled")
                        Text("相册选择截图")
                    }
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 12))
                    .foregroundStyle(.white)
                }

                Button(action: pasteFromClipboard) {
                    HStack(spacing: 6) {
                        Image(systemName: "doc.on.clipboard")
                        Text("粘贴截图")
                    }
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
                    .foregroundStyle(.primary)
                }
            }

            if selectedImage == nil && parsedDrafts.isEmpty {
                Button(action: loadSampleData) {
                    HStack(spacing: 4) {
                        Image(systemName: "sparkles")
                        Text("载入「本期应还借款4笔」示例数据一键体验")
                    }
                    .font(.caption)
                    .foregroundStyle(Color.accentColor)
                }
                .padding(.top, 4)
            }
        }
        .padding(14)
        .background(Color.appCardBackground, in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - 平台前缀批量设置
    private var platformPrefixSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("统一平台前缀 (将自动加在每笔借款名称前)")
                .font(.caption)
                .foregroundStyle(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(presetPrefixes, id: \.self) { prefix in
                        let isSelected = platformPrefix == prefix
                        Button {
                            platformPrefix = prefix
                        } label: {
                            Text(prefix)
                                .font(.caption.weight(.medium))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(isSelected ? Color.accentColor : Color(.secondarySystemGroupedBackground), in: Capsule())
                                .foregroundStyle(isSelected ? .white : .primary)
                        }
                        .buttonStyle(.borderless)
                    }
                }
            }
        }
        .padding(14)
        .background(Color.appCardBackground, in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - 识别状态与统计摘要
    private var processingIndicatorCard: some View {
        HStack(spacing: 12) {
            ProgressView()
            Text("Apple Vision 端侧引擎正在高速离线解析...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(Color.appCardBackground, in: RoundedRectangle(cornerRadius: 16))
    }

    private var summaryStatsBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.seal.fill")
                .font(.title2)
                .foregroundStyle(.green)

            VStack(alignment: .leading, spacing: 2) {
                Text("已识别 \(parsedDrafts.count) 笔独立贷款，已选 \(selectedDraftsCount) 笔")
                    .font(.subheadline.bold())
                    .foregroundStyle(.primary)

                Text("待还本金合计 \(totalRemainingPrincipalSelected.formattedCurrencyCompact) · 月供合计 \(totalMonthlyPaymentSelected.formattedCurrencyCompact)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button(selectedDraftsCount == parsedDrafts.count ? "取消全选" : "全选") {
                let willSelectAll = selectedDraftsCount != parsedDrafts.count
                for idx in parsedDrafts.indices {
                    parsedDrafts[idx].isSelected = willSelectAll
                }
            }
            .font(.caption.weight(.semibold))
        }
        .padding(14)
        .background(Color.appCardBackground, in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - 单笔借款核对卡片列表
    private var draftsListView: some View {
        VStack(spacing: 12) {
            ForEach($parsedDrafts) { $draft in
                DraftLoanCard(draft: $draft, platformPrefix: platformPrefix)
            }
        }
    }

    // MARK: - 空状态引导
    private var emptyStateGuideCard: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.viewfinder")
                .font(.system(size: 44))
                .foregroundStyle(.secondary)
                .padding(.top, 16)

            Text("支持各种消费贷还款账单截图")
                .font(.headline)

            Text("系统将自动逆推年化利率（如 6.20%）、剩余本金、还款期数与还款日，并以独立记录批量存入您的负债资产池。")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
        }
        .frame(maxWidth: .infinity)
        .background(Color.appCardBackground, in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - 错误提示
    private func errorBanner(_ msg: String) -> some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
            Text(msg)
                .font(.caption)
                .foregroundStyle(.red)
            Spacer()
        }
        .padding(12)
        .background(Color.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - 吸底批量导入条
    private var bottomImportBar: some View {
        VStack(spacing: 0) {
            Divider()
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("共 \(selectedDraftsCount) 笔独立负债")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    CurrencyText(amount: totalRemainingPrincipalSelected, font: .system(.title3, design: .rounded), weight: .bold)
                }

                Spacer()

                Button(action: batchImport) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.down.doc.fill")
                        Text("一键批量导入 (\(selectedDraftsCount)笔)")
                    }
                    .font(.subheadline.bold())
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Color.accentColor, in: Capsule())
                    .foregroundStyle(.white)
                }
                .buttonStyle(AppSpringButtonStyle(scaleAmount: 0.96, pressedOpacity: 0.85))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial)
        }
    }

    // MARK: - 业务逻辑
    private func processImage(_ image: UIImage) async {
        selectedImage = image
        isProcessingOCR = true
        errorMessage = nil

        do {
            let lines = try await LoanOCRScannerService.recognizeText(from: image)
            let drafts = LoanOCRScannerService.parseLoanDrafts(from: lines)

            await MainActor.run {
                self.isProcessingOCR = false
                if drafts.isEmpty {
                    self.errorMessage = "未在图片中识别到清晰的借款还款信息，请确保截图包含借款金额与期数。"
                } else {
                    self.parsedDrafts = drafts
                }
            }
        } catch {
            await MainActor.run {
                self.isProcessingOCR = false
                self.errorMessage = "图片识别失败：\(error.localizedDescription)"
            }
        }
    }

    private func pasteFromClipboard() {
        if let image = UIPasteboard.general.image {
            Task {
                await processImage(image)
            }
        } else {
            errorMessage = "剪贴板中未找到图片，请先在相册中复制截图。"
        }
    }

    private func loadSampleData() {
        isProcessingOCR = true
        errorMessage = nil
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            let drafts = LoanOCRScannerService.parseLoanDrafts(fromTextLines: LoanOCRScannerService.sampleScreenshotTextLines)
            self.parsedDrafts = drafts
            self.isProcessingOCR = false
        }
    }

    private func batchImport() {
        let toImport = parsedDrafts.filter { $0.isSelected }
        guard !toImport.isEmpty else { return }

        for draft in toImport {
            let loan = draft.createLoanEntity(platformPrefix: platformPrefix)
            modelContext.insert(loan)
        }

        do {
            try modelContext.save()
            saveSucceeded.toggle()
            dismiss()
        } catch {
            modelContext.rollback()
            errorMessage = "批量保存失败：\(error.localizedDescription)"
        }
    }
}

// MARK: - 单笔借款草稿编辑卡片
private struct DraftLoanCard: View {
    @Binding var draft: ParsedLoanDraft
    let platformPrefix: String
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // 头部：勾选框 + 名称 + 类别徽章
            HStack(alignment: .top, spacing: 10) {
                Button {
                    draft.isSelected.toggle()
                } label: {
                    Image(systemName: draft.isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(draft.isSelected ? Color.accentColor : Color.secondary)
                }
                .buttonStyle(.borderless)

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        let displayName = platformPrefix.isEmpty ? draft.name : "\(platformPrefix)-\(draft.name)"
                        Text(displayName)
                            .font(.subheadline.bold())
                            .foregroundStyle(.primary)

                        Spacer()

                        Text("第 \(draft.paidPeriods + 1)/\(draft.totalPeriods) 期")
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.blue.opacity(0.12), in: Capsule())
                            .foregroundStyle(.blue)
                    }

                    Text("起贷日：\(draft.startDate.formatted(date: .numeric, time: .omitted)) · 每月 \(draft.paymentDayOfMonth) 日还款")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            // 核心数值指标栏
            HStack(spacing: 16) {
                metricItem("剩余本金", draft.remainingPrincipal.formattedCurrencyCompact, .primary)
                metricItem("当期月供", draft.monthlyPayment.formattedCurrencyCompact, .appLiability)
                metricItem("年化利率", draft.annualRate.formattedRatePercentage, .primary)
                metricItem("还款方式", draft.repaymentMethod.rawValue, .secondary)
            }

            // 展开高级微调
            if isExpanded {
                Divider()
                VStack(spacing: 8) {
                    HStack {
                        Text("名称微调")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        TextField("名称", text: $draft.name)
                            .textFieldStyle(.roundedBorder)
                            .font(.caption)
                    }

                    HStack {
                        Text("年化利率 (%)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        TextField("利率", value: Binding(
                            get: { draft.annualRate * 100.0 },
                            set: { draft.annualRate = $0 / 100.0 }
                        ), format: .number.precision(.fractionLength(0...4)))
                        .textFieldStyle(.roundedBorder)
                        .font(.caption)
                        .keyboardType(.decimalPad)
                    }
                }
            }

            HStack {
                Spacer()
                Button(isExpanded ? "收起" : "微调明细") {
                    withAnimation(.spring(response: 0.3)) {
                        isExpanded.toggle()
                    }
                }
                .font(.caption2)
                .foregroundStyle(Color.accentColor)
            }
        }
        .padding(12)
        .background(Color.appCardBackground, in: RoundedRectangle(cornerRadius: 14))
        .opacity(draft.isSelected ? 1.0 : 0.6)
    }

    private func metricItem(_ label: String, _ value: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
