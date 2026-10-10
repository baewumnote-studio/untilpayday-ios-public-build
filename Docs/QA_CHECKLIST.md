# QA checklist

A checked item means it was actually verified in this package-authoring environment. Unchecked Apple/Xcode/device items must not be reported as completed until they are actually run there.

## Executed pure-Swift core tests — 33/33 passing

### Budget / Safe Today
- [x] $1,300 / 13 => $100 Safe Today.
- [x] $40 flexible spend leaves $60 Safe Today.
- [x] Overspend floors Safe Today at zero and exposes over-pace amount.
- [x] Negative free funds exposes Short By without overflow.
- [x] Payday transition avoids division and preserves closing balance.
- [x] Planned bill paid at planned amount does not double-subtract.
- [x] Planned $100 / actual $120 changes free money by only $20.
- [x] Planned $100 / actual $80 restores $20.
- [x] Pending/overdue bill reserve behavior remains correct.
- [x] Extreme Int64 aggregate paths do not trap.

### Money
- [x] Same-currency Money addition/subtraction.
- [x] Currency mismatch is rejected.
- [x] Money overflow is rejected/safely handled.
- [x] Negative-money edge behavior is covered.

### Pay schedule
- [x] Weekly = 7 nominal calendar days.
- [x] Biweekly = exactly 14 nominal calendar days.
- [x] Semi-monthly 1st/15th.
- [x] Semi-monthly 15th/last day.
- [x] Invalid duplicate semi-monthly custom day rules rejected.
- [x] February month end.
- [x] Leap-year February 29.
- [x] Fixed day 31 clamps only when needed.
- [x] Monthly true-last-day semantics.
- [x] Weekend previous weekday.
- [x] Weekend next weekday.
- [x] Weekend adjustment does not become recurrence anchor.
- [x] Previous-weekday adjustment never returns an already-past payday for the reference date.
- [x] Oct 7 → Oct 20 = 13 calendar days.
- [x] Irregular next payday.
- [x] DST-safe calendar-day calculation path.

## Additional executable harness verification

- [x] Widget Safe Today same-day calculation.
- [x] Widget next-day redistribution.
- [x] Widget deficit/Short By calculation.
- [x] Ad History use 1–3 not eligible; 4th eligible.
- [x] 24-hour ad cooldown blocks and then expires.
- [x] USD formatting/parsing uses two fractional digits.
- [x] JPY formatting/parsing uses zero fractional digits.
- [x] Excessively large money input is rejected.

## Source/static verification

- [x] All delivered Swift files pass `swiftc -frontend -parse` in this environment.
- [x] No `TODO`, `FIXME`, `IMPLEMENT ME`, `PSEUDOCODE`, or `NOT IMPLEMENTED` marker in delivered Swift source.
- [x] No production-source force unwrap/`try!` found by final scan.
- [x] Localization catalog parses as JSON.
- [x] plist, entitlements and privacy manifests parse.
- [x] project.yml parses as YAML.

## Xcode/simulator/device work still required

- [ ] XcodeGen/project creation succeeds on macOS.
- [ ] Main iOS target type-checks/links with Apple iOS SDK.
- [ ] Widget target type-checks/links and embeds correctly.
- [ ] XCTest target runs under iOS simulator.
- [ ] UI smoke tests run under iOS simulator.
- [ ] SwiftData first-launch and reset flows smoke tested.
- [ ] Add/edit/pay/skip bill flows smoke tested end-to-end.
- [ ] Monthly/semi-monthly onboarding rules exercised visually.
- [ ] Large Dynamic Type + VoiceOver pass.
- [ ] Light/dark mode visual pass.
- [ ] Notification authorization/delivery on Apple runtime.
- [ ] App Group widget synchronization on device/simulator.
- [ ] UMP test-geography/configuration runtime check.
- [ ] Debug AdMob test interstitial runtime check.
- [ ] Production AdMob IDs configured only after account setup.
- [ ] TestFlight smoke test.
