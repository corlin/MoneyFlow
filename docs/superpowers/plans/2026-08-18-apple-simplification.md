# MoneyFlow Apple Simplification Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn MoneyFlow into a calm, truthful, reversible financial-safety experience while preserving its native three-tab structure.

**Architecture:** Pure calculation, input parsing, and recovery decisions live outside SwiftUI and are unit-tested. SwiftUI views consume those units, use progressive disclosure, and expose native undo, feedback, accessibility, and reduced-motion behavior.

**Tech Stack:** Swift 5.9, SwiftUI, SwiftData, Charts, XCTest, iOS 17+

**Spec:** `docs/superpowers/specs/2026-08-18-apple-simplification-design.md`

## Global Constraints

- Preserve iOS 17.0 as the deployment floor and use no third-party dependencies.
- Use only native SwiftUI interaction patterns and SF Symbols.
- Do not automatically destroy persisted financial data.
- Use neutral Chinese risk language and state projection assumptions explicitly.
- Every behavioral change follows a failing-test then passing-test cycle.

---

### Task 1: Trustworthy projection and localized input

**Files:**
- Create: `MoneyFlow/Services/FinancialInputParser.swift`
- Modify: `MoneyFlow/Services/CashFlowProjector.swift`
- Modify: `MoneyFlowTests/RepaymentCalculatorTests.swift`

**Interfaces:**
- Produces: `FinancialInputParser.number(from:) -> Double?`
- Produces: `ProjectionAssumptions`, and `projectCashFlow(... monthlyIncome:assumptions:)`

- [ ] Add tests proving currency symbols/group separators parse, malformed input fails, monthly income is applied, and first-month card assumptions remain explicit.
- [ ] Run the focused test suite and confirm the new tests fail for missing APIs.
- [ ] Implement the parser and projection inputs with no UI dependency.
- [ ] Re-run focused tests and retain green output.

### Task 2: Non-destructive startup recovery

**Files:**
- Create: `MoneyFlow/App/PersistenceRecoveryView.swift`
- Modify: `MoneyFlow/App/MoneyFlowApp.swift`
- Test: `MoneyFlowTests/PersistenceRecoveryTests.swift`

**Interfaces:**
- Produces: `PersistenceStoreFactory.open()` and explicit `resetAndOpen()`.
- Consumes: recovery view retry/reset actions.

- [ ] Add tests proving ordinary open failure does not remove store files and reset is explicit.
- [ ] Run the focused test and confirm failure against the old eager-delete behavior.
- [ ] Implement recoverable app startup state and a reset confirmation surface.
- [ ] Re-run focused tests and the app build.

### Task 3: Single demo-data source and reversible mutations

**Files:**
- Modify: `MoneyFlow/Services/DemoDataService.swift`
- Modify: `MoneyFlow/Services/RiskAnalyzer.swift`
- Modify: `MoneyFlow/Views/Settings/SettingsView.swift`
- Modify: asset, liability, and loan detail views.

**Interfaces:**
- Produces: `DemoDataService.load(into:replacingExisting:) throws`
- Produces: local undo closures for delete/payment mutations.

- [ ] Add model-context tests for replacement and non-duplication behavior.
- [ ] Verify the focused tests fail against the three existing implementations.
- [ ] Consolidate demo generation and surface save errors.
- [ ] Add native swipe delete, payment feedback, and Undo overlays.
- [ ] Re-run focused tests.

### Task 4: Simplified Overview and navigation

**Files:**
- Modify: `MoneyFlow/App/ContentView.swift`
- Modify: `MoneyFlow/Views/Overview/OverviewTab.swift`
- Create: `MoneyFlow/Views/Overview/FinancialStatusCard.swift`
- Modify: existing overview cards and copy.

**Interfaces:**
- Produces: empty onboarding and populated decision-first overview states.

- [ ] Add pure status-summary tests for no-data, safe, attention, and shortfall states.
- [ ] Confirm failures before adding the status-summary API.
- [ ] Implement consistent tab/title copy and progressive overview content.
- [ ] Build and inspect both empty and populated states.

### Task 5: Progressive forms and validation

**Files:**
- Modify: `MoneyFlow/Views/Assets/CashAccountForm.swift`
- Modify: `MoneyFlow/Views/Liabilities/CreditCardForm.swift`
- Modify: `MoneyFlow/Views/Liabilities/LoanForm.swift`

**Interfaces:**
- Consumes: `FinancialInputParser`.
- Produces: quick fields, expandable advanced sections, inline validation, and explicit save failure state.

- [ ] Add tests for form validation policies and localized numeric input.
- [ ] Confirm failures for malformed required fields.
- [ ] Implement progressive disclosure, focus order, and save-state handling.
- [ ] Re-run focused tests and build.

### Task 6: Motion, chart feedback, and accessibility

**Files:**
- Modify: `MoneyFlow/Views/Overview/CashFlowChart.swift`
- Modify: `MoneyFlow/Views/Liabilities/LoanDetailView.swift`
- Modify: shared amount/badge/empty-state components.

**Interfaces:**
- Consumes: system accessibility settings and selected chart month.

- [ ] Add accessibility identifiers and a chart summary API covered by tests.
- [ ] Confirm the summary test fails before implementation.
- [ ] Add visible chart selection, semantic accessibility output, monospaced digits, adaptive layouts, explicit springs, haptics, and Reduce Motion alternatives.
- [ ] Build at iPhone and iPad destinations.

### Task 7: Cleanup, review, and acceptance

**Files:**
- Modify: affected source and tests only.

- [ ] Remove unused state, duplicate demo code, fixed-width phone tables, and obsolete copy.
- [ ] Run focused and full tests.
- [ ] Run independent code review and address all high-confidence findings.
- [ ] Build and launch on a simulator; inspect empty and populated UI.
- [ ] Build, install, launch, capture logs, and screenshot `corlin17mx`.
- [ ] Audit every design acceptance criterion against current source and runtime evidence.
