# App Store screenshot production spec — Visual Master 1A

## Target

Produce six portrait screenshots at **1206 × 2622 px** for the Dynamic Island iPhone medium-display class accepted by App Store Connect.

Do not submit the AI-generated Visual Master board as a product screenshot. The shipping UI must be shown using actual Simulator/device captures.

## Capture dataset

Launch the app with:

`-ui-testing-visual-master`

Use `Docs/SCREENSHOT_CAPTURE_DATA.md` as the source of truth for deterministic money values.

## Input capture filenames

- `01_today.png`
- `02_pay_schedule.png`
- `03_plan.png`
- `04_schedule_options.png`
- `05_widgets.png`
- `06_privacy.png`

## Composition

Run:

```bash
python3 Scripts/compose_appstore_screenshots.py \
  --input-dir <captures> \
  --output-dir <final>
```

The script applies the locked Visual Master backgrounds and copy while embedding the actual application capture.

## Screenshot order

1. **Know what’s safe to spend today.**
   - Today screen
   - show Left Until Payday and Safe Today

2. **Budget by paycheck. Not by calendar month.**
   - pay-schedule onboarding/settings

3. **Bills are covered before you spend.**
   - Plan → Upcoming bills

4. **Weekly. Biweekly. Twice monthly. Monthly.**
   - full schedule-choice screen, including Irregular

5. **Your budget at a glance.**
   - Home Screen/Lock Screen widget capture

6. **No bank login. No account.**
   - Settings trust/privacy card

## Accuracy rule

All monetary figures visible in final screenshots must come from the actual app. Do not manually type `$1,327` or other concept-board numbers over the UI. The deterministic screenshot seed currently produces mathematically consistent `$1,252 left`, `$52 Safe Today`, `$48 spent`, `$100 daily pace`, and `13 days` values.
