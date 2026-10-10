# Deterministic screenshot capture data

The generated Visual Master image is an art-direction reference, not a source of financial truth. Some illustrative numbers in that image are intentionally not copied when they conflict with the real Safe Today formula.

Use the DEBUG launch argument:

`-ui-testing-visual-master`

`UITestBootstrap` creates a deterministic, mathematically consistent dataset for simulator screenshots and visual regression.

## Today state

- Currency: USD
- Payday: 13 calendar days from launch date
- Starting paycheck: $2,800
- Protected savings: $300
- Rent: $900, already paid and linked to its bill occurrence
- Flexible spend today: $48
- Pending bills before payday: $300 total
  - Electricity $86 — 3 days
  - Internet $55 — 5 days
  - Phone $70 — 8 days
  - Car Insurance $89 — 11 days

Therefore:

- Expenses already paid: $948 ($900 reserved Rent payment + $48 flexible spending)
- Pending bill reserve: $300
- Protected savings: $300
- Left Until Payday: `$2,800 - $948 - $300 - $300 = $1,252`
- Reconstructed start-of-day flexible pool: `$1,252 + $48 = $1,300`
- Daily pace: `$1,300 / 13 = $100`
- Safe Today after $48 spent: `$52`

This is the screenshot truth. Do not force `$1,327` from the promotional concept image into the real app if the underlying inputs do not mathematically support it.

## Plan state

Recurring templates are seeded for:
- Rent
- Electricity
- Internet
- Phone

The Plan screen should show paid/pending status based on actual model data rather than hard-coded screenshot labels.

## Screenshot order

1. Today — `Know what’s safe to spend today.`
2. Pay Schedule — `Budget by paycheck. Not by calendar month.`
3. Plan — `Bills are covered before you spend.`
4. Pay Schedule choices — `Weekly. Biweekly. Twice monthly. Monthly.`
5. Widgets — `Your budget at a glance.`
6. Settings trust card — `No bank login. No account.`

## UI test attachments

`VisualMasterScreenshotSmokeTests.swift` captures Today, Plan and Settings screenshots as kept XCTest attachments when run under Xcode. Final App Store marketing composites should still be created from clean simulator captures at an Apple-approved screenshot size.
