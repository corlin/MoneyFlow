# MoneyFlow (CFP Dynamic Suite)

MoneyFlow 是一款使用 SwiftUI 与 SwiftData 构建的本地优先 iOS 专业财务规划工具。深度结合 **CFP（注册财务策划师）目标导向财富规划（GBWM）** 与 **CFA（特许金融分析师）资产负债压力测试** 体系，并遵循 Apple 原生设计哲学（Less, but better），帮助用户看清现金流韧性、推演还贷加速策略、实现多目标自适应储蓄与获得专业财务诊断。

应用不连接银行账户，也不上传财务数据。所有记录默认只保存在当前设备。

---

## 核心能力

- **CFP 财务韧性中枢（Financial Resilience Hub）**：
  - **三维生命线指标**：直观展示 `🛡️ 应急储备覆盖 (月数)`、`⚡ 偿债收入比 (DSR %)` 与 `💰 自由月结余`。
  - **单条黄金行动建议（Golden Insight）**：算法提炼当前最紧迫的 1 条高价值专业决策建议（如高息负债预警、雪崩省息机会），告别繁复说教。
  - **3 模块极简概览**：`财务韧性中枢` $\rightarrow$ `12个月确定性走势` $\rightarrow$ `未来30天紧迫还款`，减少 50% 滚动长度与视觉噪音。

- **动态现金流沙盘与双轨推演（Dynamic Cashflow Sandbox）**：
  - **双轨对比**：基准走势（Baseline）与情景推演（Scenario）实时联动渲染。
  - **双重视图**：支持「现金余额走势折线图」与「月度三层收支/结余瀑布堆叠图」无缝切换。
  - **原生浮动胶囊手柄（Floating Scenario Pills）**：零折叠面板，轻点图表上方的胶囊即可完成 **收入冲击压力测试 (0% / -10% / -20% / -30%)**、**突发大额开支** 与 **还贷策略仿真**，走势线与多目标卡片实时阻尼弹簧形变。

- **负债加速策略引擎（Debt Paydown Strategy）**：
  - **雪崩法 (Debt Avalanche)**：算法优先偿还利率最高的贷款，计算最大节省利息总额。
  - **滚雪球法 (Debt Snowball)**：算法优先结清本金最小的贷款，最快注销负债笔数。
  - **收益内嵌展示**：切换策略时直接高亮 `⚡ 预计省息 ¥X · 提前 N 个月`，直观呈现对无债结清日的提前效应。

- **多目标自然原型与智能推导（Multi-Goal Management）**：
  - **三大直觉原型**：
    - `🛡️ 应急防线`：系统自动锁定必需 (Tier 1)，支持一键按 3/6 个月刚性支出自动测算额度；
    - `⚡ 提前还贷`：点选已有贷款自动绑定剩余本金与利率优先级；
    - `🎯 储蓄心愿`：自由设定心愿目标（置业、购车、旅行等）。
  - **智能虚拟分账（Virtual Earmarking）**：严格区分存量已锁定金额与未锁定自由现金，防止资金重复计算（No Double-Counting）。
  - **优先级动态灌溉**：月度净自由结余资金自适应灌溉至各目标池，精确推算各目标的预计达成年月（ETA）与顺延延期风险。

- **4-Tab 专业规划工作台**：
  - **概览 (Overview)**：高层决策中枢、财务韧性体检、近期 30 天还款。
  - **规划 (Planning)**：动态现金流推演沙盘与多目标管理矩阵。
  - **资产 (Assets)**：流动性现金账户管理与已锁定/自由现金拆解。
  - **负债 (Liabilities)**：贷款与信用卡还款日程、偿债进度与还款登记。

- **双专业演示画像**：
  - **画像 1（负债突围与安全筑底）**：房贷 + 7.2% 装修贷 + 信用卡，高 DSR 承压，体验雪崩法加速脱困与建立应急储备。
  - **画像 2（多目标稳健积累）**：低息公积金贷，月结余充裕，3 大梯队目标自适应灌溉与达成期推演。

- **安全、隐私与原生体验**：
  - 100% 本地优先，无任何第三方追踪；支持 JSON 完整数据备份与导出。
  - Swift Charts 连续手势探针、物理弹簧阻尼微动画、触觉分级反馈与全面系统级无障碍支持（Dynamic Type, VoiceOver, Reduce Motion）。

---

## 专业指标口径

| 指标 | 计算口径与标准 |
| --- | --- |
| **偿债收入比 (DSR)** | $\frac{\text{每月还本付息总额}}{\text{月度预计总收入}}$；$<35\%$ 为稳健，$35\%\sim 45\%$ 为警戒，$>45\%$ 为高危。 |
| **应急储备覆盖月数** | $\frac{\text{当前流动现金}}{\text{月刚性生活支出} + \text{月固定还贷支出}}$；CFP 标准建议一般维持 3~6 个月安全水位。 |
| **自由现金流结余** | $\text{月度预计总收入} - \text{月刚性生活支出} - \text{月还本付息总额}$；用于动态灌溉多目标池或提前还贷。 |
| **加权负债成本 (WACD)** | $\frac{\sum (\text{各负债剩余本金} \times \text{年化利率})}{\text{总负债额}}$；反映整体借贷的综合利息负担。 |
| **目标达成期 (ETA)** | 基于存量分账与月度自由结余按优先级灌溉至目标金额的预测月份。 |
| **净现金头寸** | 已记录现金资产 − 已记录负债（不代表全口径固定资产净值）。 |

---

## 技术栈

- iOS 17+
- Swift 5.9
- SwiftUI
- SwiftData
- Swift Charts
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
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:MoneyFlowTests
```

测试覆盖多目标优先级动态灌溉、双轨现金流沙盘推演、雪崩法/滚雪球法省息算法、DSR 与三维健康指标诊断、双画像数据管理、还款计划表与本地化输入解析。

---

## 项目结构

```text
MoneyFlow/
├── App/          # 应用入口、4-Tab 导航与存储恢复
├── Models/       # SwiftData 模型 (FinancialGoal, UserSettings, Loan, CashAccount, CreditCard)
├── Services/     # 多目标引擎 (MultiGoalEngine)、双轨推演 (CashFlowProjector)、诊断 (RiskAnalyzer)、示例数据
├── Views/
│   ├── Overview/ # 概览中枢与 CFP 财务韧性中枢 (FinancialResilienceHubView)
│   ├── Planning/ # 规划沙盘 (DynamicCashFlowSandboxView) 与多目标矩阵 (GoalListView, GoalFormSheet)
│   ├── Assets/   # 资产与已锁定/自由现金拆解
│   ├── Liabilities/ # 负债与还款日程
│   └── Settings/ # 设置与双画像切换
├── Components/   # 通用 SwiftUI 组件与三段式资金进度条
└── Extensions/   # 日期、金额、主题与流体物理动力学扩展
```

---

## 隐私

- 财务数据默认只保存在设备本地。
- 应用不会要求银行登录信息。
- 清除全部数据需要明确确认。
- 存储恢复前会尝试创建本地备份。
