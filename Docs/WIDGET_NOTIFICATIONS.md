# Widget and notifications

## Shared widget snapshot

The widget does not open or query the SwiftData store. The main app writes a small Codable snapshot to App Group UserDefaults containing:
- current free money
- ordinary flexible spending made today
- ISO currency code
- next payday
- generated timestamp

The widget can recompute Safe Today after midnight from that snapshot, because no new spending can occur while the app remains closed.

## Families

Small:
- SAFE TODAY
- amount
- days until payday

Medium:
- Left Until Payday on left
- Safe Today on right
- Add deep link

Accessory rectangular:
- Safe Today amount
- `13d to payday`

Accessory circular:
- compact SAFE / amount / day count

Before onboarding, show `Plan to payday — Open Payday Left to get started.` Never display a fake $0 budget.

## Refresh

Main app reloads WidgetKit timelines after financial state changes. Widget timeline asks for another refresh shortly after next local midnight so day count and Safe Today can roll forward.

## Notifications

Local notifications only; no push server.

Optional:
- Payday tomorrow: 18:00 local day before payday
- Payday today: 09:00 local payday

When payday changes, cancel old requests and schedule new ones. Denying notification permission must not reduce budgeting functionality.
