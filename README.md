# MoneyFlow (CFP Dynamic Suite)

MoneyFlow 是一款使用 SwiftUI 与 SwiftData 构建的本地优先 iOS 专业财务规划工具。深度结合 **CFP（注册财务策划师）目标导向财富规划（GBWM）** 与 **CFA（特许金融分析师）资产负债压力测试** 体系，并遵循 Apple 原生设计哲学（Less, but better），帮助用户看清现金流韧性、推演还贷加速策略、实现多目标自适应储蓄、精准管理房贷多次调息与提前还款、端侧 Vision OCR 批量秒级录入多笔零星消费贷款，以及通过 **「还贷 vs 理财机会成本精算」** 与 **「WidgetKit 桌面及锁屏全生态小组件」** 实现毫秒级资金全景监控与专业决策。

应用不连接银行账户，也不上传财务数据。所有记录、计算与 OCR 识别均在当前设备本地离线完成。

---

## 核心能力

### 1. 提前还贷 vs 稳健理财五维机会成本精算器（Opportunity Cost Engine）
- **五维全景精算**：
  - **贷款省息精算**：精确计算提前还本（缩短年限 / 减少月供）在剩余期限内节省的累计总利息 $\Delta I_{loan}$。
  - **理财复利回报对标**：在相同对标周期 $M$ 内，计算闲钱本金 $P$ 以预期年化收益率 $r_{inv}$ 产生的按月复利终值 $P(1 + r_{inv}/12)^M - P$。
  - **临界保本年化利率反解**：精准逆向求解理财必须达到的年化收益率 $r_{bep} = 12 \times \left[ \left(1 + \frac{\Delta I_{loan}}{P}\right)^{\frac{1}{M}} - 1 \right]$，直观判断是否能战胜房贷利率。
  - **智能流动性安全护栏**：若提前还款后剩余可用流动资金不足 3 个月必要支出，系统强制触发红黄安全预警，守护家庭应急底线。
- **双向互通架构**：
  - **规划页沙盘独立入口**：支持任意输入闲钱、自定义贷款利率、期限与理财收益率进行独立沙盘推演。
  - **负债详情页一键带入**：在已有贷款详情页直接一键带入剩余本金、当前年化利率与剩余期数，无缝对比还本与理财。

### 2. WidgetKit 桌面与锁屏全生态小组件矩阵（Desktop & Lock Screen Widgets）
- **跨进程轻量快照架构**：
  - 主 App 在前台活跃、后台挂起或数据变更时，毫秒级将脱敏财务快照写入 App Group（`group.com.moneyflow.app`）。
  - 小组件进程直接读取 JSON 快照，实现 **零数据库锁表冲突、零内存超限风险、毫秒级即时渲染**。
- **全生态形态适配**：
  - **桌面 Small**：可用资金、本月应付、风险状态徽章与快捷 Deep Link。
  - **桌面 Medium**：左右双栏布局，左侧资金全景 + DSR 压力条，右侧近期 3 笔还款倒计时列表。
  - **锁屏 AccessoryRectangular**：可用资金与最近一笔还款倒计时。
  - **锁屏 AccessoryCircular**：以环形进度条直观呈现 DSR 负债偿付压力。
- **深层路由（Deep Link）**：
  - 轻点小组件不同区域，通过 `moneyflow://overview`、`moneyflow://liabilities`、`moneyflow://planning` 直接唤醒主 App 对应 Tab。

### 3. 周期性现金流日历与账单智能对账（Cash Flow Calendar & Smart Reconciliation）
- **周/月全景折叠日历**：
  - 在规划 Tab 顶部嵌入紧凑型周视图与 7×N 全景月历网格，平滑阻尼动画折叠展开。
  - 状态指示矩阵：按日标注 🟢 发薪进账、🔴 待还出账、✅ 已对账结清与 ⚠️ 流动性预警点。
- **日级动态资金水位流转推演**：
  - 以实时可用现金为基点，结合发薪日（`paydayOfMonth`）与负债还款日，精确推演当月及未来 30 天**每一天的日终结余水位**。
  - **智能流动性缺口预警**：当某天出账后预计余额低于 1 个月刚性安全防线时触发橙色预警，发生穿底透支（$<0$）时触发红色强预警。
- **智能还款对账与账户资金联动**：
  - 独立 SwiftData 实体 [`PaymentReconciliationRecord`](file:///Users/corlin/2026/MoneyFlow/MoneyFlow/Models/PaymentReconciliationRecord.swift) 记录按月实还金额、结清状态与备注，历史账目可精确回溯。
  - 轻触一键对账结清，支持在弹窗中选择「同步扣减指定现金账户余额」，保持账本与银行卡实际资金严密一致。
- **自定义收支事件支持**：
  - 独立实体 [`CustomCashFlowEvent`](file:///Users/corlin/2026/MoneyFlow/MoneyFlow/Models/CustomCashFlowEvent.swift) 支持用户添加单次大额（如奖金、车险保费）或每月周期性收支，精准融入现金流日历。

### 4. CFP 财务韧性中枢（Financial Resilience Hub）
- **三维生命线指标**：直观展示 `🛡️ 应急储备覆盖 (月数)`、`⚡ 偿债收入比 (DSR %)` 与 `💰 自由月结余`。
- **单条黄金行动建议（Golden Insight）**：算法提炼当前最紧迫的 1 条高价值专业决策建议（如高息负债预警、雪崩省息机会），告别繁复说教。
- **3 模块极简概览**：`财务韧性中枢` $\rightarrow$ `12个月确定性走势` $\rightarrow$ `未来30天紧迫还款`，减少 50% 滚动长度与视觉噪音。

### 5. 房贷多次调息与提前还款（分段链式计划推演）
- **双轨补录哲学**：既支持“现实截面一键对账”（输入当前本金利率即刻推演未来 20 年计划），也支持“保真时间轴流水”。
- **提前还款双模式测算**：支持 **「月供降低（期限不变）」** 与 **「期限缩短（月供不变）」** 实时收益对比，智能测算累计省息金额与提前结清月数。
- **分段利率自适应重排**：支持多次 LPR 重定价与存量利率下调，按生效期数链式切分重新摊销（Amortize）。
- **成就勋章与变更时间轴**：贷款详情页展示「✨ 调息与还贷累计省息」成就徽章与垂直时间轴，分段计划表中自动标注事件微胶囊。
- **手工录入期数与 4 位小数高精度利率**：总期数与已还期数支持直接键盘数字键入与 Stepper 联动微调；年化利率精度全面提升至小数点后 4 位（如 `3.1250%`、`6.2000%`）。

### 6. 零星消费贷截图 OCR 识别与批量录入（多条独立记录）
- **Apple 原生 Vision 离线 OCR**：基于 `VNRecognizeTextRequest` 在端侧毫秒级完成文字识别，100% 离线、零流量消耗、财务账单数据绝对隐私。
- **智能金融逆向求解器**：由截图中的借款额、期数（如 `第11/12期`）、当期本金与当期利息，自动逆向求解年化利率（如精准测算出 `6.2000%`）、剩余待还本金、起贷日与每月还款日。
- **多卡片核对与批量前缀**：支持相册选图与剪贴板一键粘贴，支持快速点选平台标签（微粒贷 / 借呗 / 度小满 / 京东金条 / 分期乐）批量前缀，支持单笔卡片勾选与展开微调。
- **多条高保真独立实体持久化**：一键导入后在 SwiftData 中生成多条独立的 `Loan` 实体，精准呈现各笔贷款在不同月份结清释放现金流的真实拐点。

### 7. 动态现金流沙盘与双轨推演（Dynamic Cashflow Sandbox）
- **双轨对比**：基准走势（Baseline）与情景推演（Scenario）实时联动渲染。
- **双重视图**：支持「现金余额走势折线图」与「月度三层收支/结余瀑布堆叠图」无缝切换。
- **原生浮动胶囊手柄（Floating Scenario Pills）**：轻点图表上方的胶囊即可完成 **收入冲击压力测试 (0% / -10% / -20% / -30%)**、**突发大额开支** 与 **还贷策略仿真**，走势线与多目标卡片实时阻尼弹簧形变。

### 8. 负债加速策略引擎（Debt Paydown Strategy）
- **雪崩法 (Debt Avalanche)**：算法优先偿还利率最高的贷款，计算最大节省利息总额。
- **滚雪球法 (Debt Snowball)**：算法优先结清本金最小的贷款，最快注销负债笔数。
- **收益内嵌展示**：切换策略时直接高亮 `⚡ 预计省息 ¥X · 提前 N 个月`，直观呈现对无债结清日的提前效应。

### 9. 多目标自然原型与智能推导（Multi-Goal Management）
- **三大直觉原型**：
  - `🛡️ 应急防线`：系统自动锁定必需 (Tier 1)，支持一键按 3/6 个月刚性支出自动测算额度；
  - `⚡ 提前还贷`：点选已有贷款自动绑定剩余本金与利率优先级；
  - `🎯 储蓄心愿`：自由设定心愿目标（置业、购车、旅行等）。
- **智能虚拟分账（Virtual Earmarking）**：严格区分存量已锁定金额与未锁定自由现金，防止资金重复计算（No Double-Counting）。
- **优先级动态灌溉**：月度净自由结余资金自适应灌溉至各目标池，精确推算各目标的预计达成年月（ETA）与顺延延期风险。

---

## 专业指标口径

| 指标 | 计算口径与标准 |
| --- | --- |
| **偿债收入比 (DSR)** | $\frac{\text{每月还本付息总额}}{\text{月度预计总收入}}$；$<35\%$ 为稳健，$35\%\sim 45\%$ 为警戒，$>45\%$ 为高危。 |
| **应急储备覆盖月数** | $\frac{\text{当前流动现金}}{\text{月刚性生活支出} + \text{月固定还贷支出}}$；CFP 标准建议一般维持 3~6 个月安全水位。 |
| **自由现金流结余** | $\text{月度预计总收入} - \text{月刚性生活支出} - \text{月还本付息总额}$；用于动态灌溉多目标池或提前还贷。 |
| **加权负债成本 (WACD)** | $\frac{\sum (\text{各负债剩余本金} \times \text{最新年化利率})}{\text{总负债额}}$；反映整体借贷的综合利息负担。 |
| **临界保本理财年化率** | $12 \times \left[ \left(1 + \frac{\Delta I_{loan}}{P}\right)^{\frac{1}{M}} - 1 \right]$；持平提前还贷省息所需的最低理财年化收益率。 |
| **累计省息总额** | $\max(0, \text{基准利息} - \text{历次调息与提前还本后实际应付利息})$。 |
| **目标达成期 (ETA)** | 基于存量分账与月度自由结余按优先级灌溉至目标金额的预测月份。 |
| **净现金头寸** | 已记录现金资产 − 已记录负债（不代表全口径固定资产净值）。 |

---

## 技术栈

- iOS 17+
- Swift 5.9
- SwiftUI
- SwiftData
- Swift Charts
- WidgetKit (桌面与锁屏小组件)
- App Group 数据共享
- Vision (Apple 原生端侧离线 OCR)
- PhotosUI (原生照片选择)
- XCTest / XCUITest
- XcodeGen

项目没有第三方运行时依赖。

---

## 本地运行

1. 安装 Xcode 16 或更高版本。
2. 安装 [XcodeGen](https://github.com/yonaskolb/XcodeGen)：

   ```bash
   brew install xcodegen
   ```

3. 生成并打开工程：

   ```bash
   xcodegen generate
   open MoneyFlow.xcodeproj
   ```

4. 在 Xcode 中选择 iPhone 或 iPad 运行 `MoneyFlow` scheme（支持模拟器与物理真机）。

---

## 测试

运行完整单元测试：

```bash
xcodebuild test \
  -project MoneyFlow.xcodeproj \
  -scheme MoneyFlow \
  -destination 'id=1F0962D0-89A4-579C-9ED1-0683F0FBB269' \
  -only-testing:MoneyFlowTests
```

测试套件共 **39 项单元测试**，覆盖：
- 周期性现金流日历发薪注入、逐日水位递推与流动性缺口预警 (`CashFlowCalendarTests`)
- 贷款与信用卡还款日出账映射、对账记录状态流转与自定义收支事件
- 提前还贷 vs 稳健理财机会成本精算、保本临界利率与流动性护栏 (`OpportunityCostTests`)
- 多目标优先级动态灌溉与 ETA 预测 (`CFPPlanningEngineTests`)
- 双轨现金流沙盘推演与情景冲击
- 雪崩法/滚雪球法省息与提前结清期数
- DSR 与三维健康指标诊断
- 房贷多次 LPR 调息分段重排与省息测算 (`LoanAdjustmentEngineTests`)
- 提前还贷双模式（月供降低 vs 期限缩短）链式推演
- 4 位小数高精度年化利率解算
- 真实账单截图 OCR 解析与多条独立负债持久化验证 (`LoanOCRParserTests`)
- SwiftData 级联删除与存储备份恢复

---

## 项目结构

```text
MoneyFlow/
├── App/                  # 应用入口、4-Tab 导航、Deep Link 路由与存储恢复
├── Models/               # SwiftData 模型 (FinancialGoal, UserSettings, Loan, LoanAdjustmentEvent, CashAccount, CreditCard, PaymentReconciliationRecord, CustomCashFlowEvent) 与小组件快照 (WidgetSnapshotData)
├── Services/             # 现金流日历引擎 (CashFlowCalendarEngine)、机会成本引擎 (OpportunityCostEngine)、小组件快照服务 (WidgetSnapshotService)、多目标引擎 (MultiGoalEngine)、双轨推演 (CashFlowProjector)、诊断 (RiskAnalyzer)、OCR解析器 (LoanOCRScannerService)、分段重算引擎 (RepaymentCalculator)、示例数据
├── Views/
│   ├── Overview/         # 概览中枢与 CFP 财务韧性中枢 (FinancialResilienceHubView)
│   ├── Planning/         # 规划沙盘 (DynamicCashFlowSandboxView)、现金流全景日历卡片 (CashFlowCalendarCardView)、单日流水抽屉 (DailyCashFlowDetailSheet)、智能对账确认 (ReconciliationConfirmSheet)、自定义收支表单 (CustomCashFlowEventFormSheet)、机会成本精算器 (OpportunityCostCalculatorView) 与多目标矩阵
│   ├── Assets/           # 资产与已锁定/自由现金拆解
│   ├── Liabilities/      # 负债与还款日程、贷款详情 (LoanDetailView)、调息还贷向导 (LoanAdjustmentEventSheet)、截图批量录入 (BatchLoanOCRImportSheet)
│   └── Settings/         # 设置与双画像切换
├── Components/           # 通用 SwiftUI 组件与三段式资金进度条
├── Extensions/           # 日期、金额、高精度利率格式化、主题与流体物理动力学扩展
├── MoneyFlowWidgets/     # WidgetKit 扩展 Target (Small/Medium/AccessoryRectangular/AccessoryCircular)
└── MoneyFlowTests/       # 39 项单元测试矩阵
```

---

## 隐私

- 财务数据与截图文字识别 100% 仅在设备本地离线执行，无任何网络上传。
- 应用不会要求银行登录信息。
- 清除全部数据需要明确确认。
- 存储恢复前会尝试创建本地备份。
