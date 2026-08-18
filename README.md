# MoneyFlow

MoneyFlow 是一款使用 SwiftUI 与 SwiftData 构建的本地优先 iOS 财务工具，帮助用户快速判断现金能否覆盖未来还款、负债是否正在改善，以及近期有哪些还款需要处理。

应用不连接银行账户，也不上传财务数据。所有记录默认只保存在当前设备。

## 核心能力

- **偿债缓冲**：计算现金连续可覆盖的预测月份，并指出首次缺口与最低预计余额。
- **12 个月现金余量**：用单一余额折线呈现每月完成已记录还款后的预计现金。
- **负债改善**：展示未来 12 个月预计减少的本金、剩余负债和当前净现金头寸。
- **未来 30 天还款**：汇总近期应还金额，并可直接进入对应贷款或信用卡记录。
- **资产与负债管理**：记录现金账户、贷款和信用卡，查看贷款计划并登记还款。
- **安全与可恢复性**：删除和还款支持撤销；存储异常不会自动删除原始数据。
- **无障碍支持**：支持动态字体、VoiceOver、Reduce Motion、语义化颜色与触觉反馈。

## 指标口径

| 指标 | 计算口径 |
| --- | --- |
| 可支撑月数 | 从当前月开始，期末预计现金连续不低于 0 的月份数，预测上限为 12 个月。 |
| 期末预计现金 | 期初现金 + 设置中的每月预计收入 − 贷款计划还款 − 信用卡应还。 |
| 预计本金减少 | 未来 12 个月贷款计划中的本金部分，加上假设首月还清的当前信用卡欠款。 |
| 净现金头寸 | 已记录现金资产 − 已记录负债；不代表完整净资产。 |

默认预测假设当前信用卡欠款在首月偿还，并计入设置中的每月预计收入。预测不包含未记录的生活支出、新增借款、投资波动或收入变化，因此仅用于个人规划参考，不构成财务建议。

## 技术栈

- iOS 17+
- Swift 5.9
- SwiftUI
- SwiftData
- Swift Charts
- XCTest / XCUITest
- XcodeGen

项目没有第三方运行时依赖。

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

4. 在 Xcode 中选择 iPhone 或 iPad 模拟器运行 `MoneyFlow` scheme。

仓库同时提交了生成后的 `MoneyFlow.xcodeproj`，因此也可以直接打开工程。

## 测试

运行完整单元测试与 UI 测试：

```bash
xcodebuild test \
  -project MoneyFlow.xcodeproj \
  -scheme MoneyFlow \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

测试覆盖还款计划、现金流预测、偿债缓冲、负债改善、30 天还款汇总、本地化金额输入、数据恢复、示例数据与主要 UI 流程。

## 项目结构

```text
MoneyFlow/
├── App/          # 应用入口、导航与存储恢复
├── Models/       # SwiftData 数据模型
├── Services/     # 还款、预测、风险和展示指标
├── Views/        # 概览、资产、负债与设置界面
├── Components/   # 通用 SwiftUI 组件
└── Extensions/   # 日期、金额与主题扩展
```

产品设计与实现记录位于 [`docs/superpowers`](docs/superpowers)。

## 隐私

- 财务数据默认只保存在设备本地。
- 应用不会要求银行登录信息。
- 清除全部数据需要明确确认。
- 存储恢复前会尝试创建本地备份。
