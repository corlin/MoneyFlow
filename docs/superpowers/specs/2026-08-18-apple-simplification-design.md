# MoneyFlow Apple Simplification Design

## Purpose

MoneyFlow should answer three questions within seconds: what is due next, whether available cash can cover upcoming debt, and what action deserves attention. The experience should feel calm, native, predictable, and reversible.

## Product language and trust

- Never delete the persistent store automatically after an initialization error. Present recovery choices and require explicit confirmation before resetting local data.
- Describe projections according to their actual inputs. The default projection is "偿债后现金余额" and explicitly states that future income is excluded and current credit-card balances are paid in the first month.
- Replace moral or medical debt labels such as "良性" and "高危" with neutral, user-configurable threshold language: "低于基准" and "需关注".
- A save may only dismiss after validation and persistence succeed. Errors remain visible beside the affected field or at the form level.
- One-step destructive actions must be reversible. Payments and list deletions expose Undo; clearing all data remains explicitly confirmed.

## Information architecture

- Retain the familiar three-tab structure and use consistent titles: 概览, 资产, 负债.
- Empty overview: one value statement, one primary manual-entry action, one secondary demo action, and a local-privacy note. Do not display meaningless zero metrics.
- Populated overview order: actionable status, next payment, minimum projected balance/coverage, projection chart, then secondary net-worth and debt-composition details.
- Settings remain available from Overview and contain projection assumptions, alert preferences, demo/reset controls, and app metadata.

## Progressive entry

- Asset quick fields: name and balance. Icon and note move under optional details.
- Credit-card quick fields: name, current balance, due day. Credit limit, billing day, and note move under optional details.
- Loan quick fields: name, remaining principal, monthly payment, annual rate, and payment day. Original amount, repayment method, terms, paid periods, start date, and note move under precise-calculation details.
- Numeric input accepts localized grouping separators and currency/percent symbols through one tested parser.
- Forms use inline error text, keyboard focus progression, and an explicit save result.

## Interaction and motion

- Use native sheets, navigation, menus, lists, and swipe actions.
- Use critically damped, interruptible springs for insertion, status-card changes, and payment progress. No decorative bounce.
- Use haptics only for save completion, payment completion, selection changes, warnings, and destructive outcomes.
- Respect Reduce Motion by replacing movement with short opacity changes.
- Chart selection follows the finger continuously and displays a visible rule/point for the selected month.

## Accessibility and visual system

- Use semantic system type and colors. Use monospaced digits for amounts.
- Never encode status with color alone; pair color with text and symbols.
- Avoid fixed column widths on phone. At accessibility text sizes, horizontal metric groups become vertical groups.
- Provide accessibility labels/values for icon buttons, summary cards, progress, and chart data.
- Keep translucent material on system chrome. Content surfaces remain stable and legible.

## Code structure

- `ProjectionAssumptions` and `CashFlowProjector` own projection semantics.
- `FinancialInputParser` owns locale-tolerant numeric parsing and validation.
- `DemoDataService` is the only demo-data implementation.
- `PersistenceRecoveryView` owns startup failure recovery and explicit reset.
- Shared `UndoAction` state coordinates reversible UI mutations without a third-party dependency.
- Remove unused view state and recompute expensive loan schedules only when their inputs change.

## Acceptance criteria

- No initialization path silently deletes user data.
- Empty and populated Overview states are visually distinct and truthful.
- A first asset, loan, or card can be recorded from the quick form without opening advanced fields.
- Invalid localized numbers cannot silently become zero/default values.
- Delete and payment actions can be undone.
- Projection assumptions are visible and match calculation behavior.
- Largest accessibility sizes do not rely on fixed table columns; VoiceOver receives meaningful labels.
- Reduce Motion removes nonessential movement.
- Unit tests, simulator build/tests, and a real-device launch on `corlin17mx` pass.
