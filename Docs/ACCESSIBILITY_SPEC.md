# Accessibility specification — Visual Master v1.2 Asset Ready

This is a release requirement, not optional polish. The UI must remain understandable without color, at large Dynamic Type sizes, with Reduce Motion enabled, and with VoiceOver.

## Core principles

- Minimum interactive target: 44×44 pt.
- Blue means navigation/action and green means healthy budget state, but **no meaning may depend on color alone**.
- Amounts use text labels such as `SAFE TODAY`, `SHORT BY`, `Paid`, `Pending`, and descriptive VoiceOver values in addition to color.
- Money amounts use `monospacedDigit()` visually where useful but remain ordinary localized text semantically.
- Prefer native SwiftUI controls so Switch Control, Voice Control, keyboard focus and VoiceOver inherit platform behavior.
- Respect Reduce Motion. Numeric transitions may be suppressed when `accessibilityReduceMotion` is enabled.
- Do not lock font sizes. Hero amounts may use `minimumScaleFactor` to avoid clipping, but supporting labels must wrap rather than disappear.

## Locked accessibility identifiers

These identifiers are intentionally stable for UI testing and should not be renamed during Xcode assembly without updating tests:

| Element | Identifier |
|---|---|
| Today payday summary | `paydaySummary` |
| Left Until Payday hero | `leftUntilPaydayHero` |
| Safe Today card | `safeTodayCard` |
| Plan segmented picker | `planSegmentedControl` |
| Settings trust card | `trustSummaryCard` |
| Money entry field | `moneyAmountField` |
| History cycle card | `historyCycleCard` |
| Start new pay cycle button | `startNewPayCycleButton` |
| Start fresh cycle button | `startFreshPayCycleButton` |

## VoiceOver expectations

### Today

Payday summary:
- Normal: `13 days until payday. Next payday October 20, 2026.`
- Boundary: `Payday is here.`

Left hero:
- Label: `Money left until payday`
- Value: localized amount, e.g. `$1,252.00`

Safe Today:
- Normal: `Safe spending today. $52.00 available today. $48.00 spent today.`
- Over pace: `Safe spending today. Zero available today. Over today’s pace by …`
- Overall deficit: `Budget shortfall. Short by … before payday.`

Upcoming bill row should expose the bill name, localized amount, due date and relative status as one understandable row.

### Settings trust card

VoiceOver should read the group as a coherent trust statement:
- Your budget. Your device.
- No bank connection.
- No account required.
- No subscription.
- Budget records stay on your device.

### Widgets

Expected conceptual reading:
- Small normal: `$52 safe today. 13 days until payday.`
- Deficit: `Short by $128 before payday.`
- Payday boundary: `Payday is here. Open Payday Left to start a new cycle.`

## Dynamic Type test matrix

Test at least:
- Default
- Accessibility Large
- Accessibility Extra Extra Extra Large

Check:
- Today hero amount never overlaps labels.
- Safe Today status remains visible.
- Four tab labels remain discoverable even if iOS condenses titles.
- Plan bill rows can grow vertically.
- Forms do not truncate field labels so meaning is lost.

## Contrast / appearance

Test:
- Light mode
- Dark mode
- Increase Contrast
- Differentiate Without Color

The Visual Master palette intentionally pairs blue/green states with labels and symbols. If a color fails contrast in the actual Xcode Accessibility Inspector, adjust the semantic token rather than a one-off screen color.

## Reduce Motion

When Reduce Motion is enabled:
- Do not use celebratory movement or confetti.
- Numeric state changes may update without `.snappy` animation.
- Sheets/navigation use system behavior.

## Release gate

Before TestFlight release, run Accessibility Inspector and a manual VoiceOver pass through:
1. onboarding,
2. Today,
3. add expense,
4. Plan bill payment,
5. payday transition,
6. History detail,
7. Settings,
8. Home Screen and Lock Screen widgets.
