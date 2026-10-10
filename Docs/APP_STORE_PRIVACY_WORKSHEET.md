# App Store privacy worksheet — release-time verification required

This is a submission worksheet, not a claim that the final App Store Connect answers are already locked. Re-check the Xcode Privacy Report, Google SDK privacy manifest and current Google disclosure page for the exact versions in the archive submitted to Apple.

## Budget records

The app's own code stores the following locally and does not send them to an application server or analytics service:

- paycheck / available-funds amounts
- expense amounts
- bill names and amounts
- protected savings
- transaction notes
- pay-cycle dates

Under Apple's definition, data that remains on device is not treated as collected merely because it exists locally.

## Third-party advertising SDK

Because Google Mobile Ads / UMP are included, **do not answer “No data collected” for the app as a whole without reviewing the final privacy report.**

Google currently documents that its Mobile Ads SDK may process/collect categories including:

- approximate/general location inferred from IP address
- device identifiers
- advertising data
- product/app interaction data
- crash data
- performance data

Possible purposes can include third-party advertising, analytics, ad measurement/performance and SDK functionality.

## v1 privacy-hardening configuration

Before Google Mobile Ads initialization the app currently:

- disables Publisher first-party ID
- sets maximum ad content rating to General
- disables publisher ad personalization
- does not directly request IDFA
- does not include an intentional ATT prompt

UMP consent gating still applies where required.

## Tracking question

Do **not** pre-fill the App Store Connect Tracking answer solely from this document.

At release time:

1. Archive the exact release build in Xcode.
2. Generate/review the combined privacy report for all SDKs.
3. Confirm AdMob/UMP production configuration and mediation status.
4. Determine whether any included SDK links app/device data with third-party data for targeted advertising or advertising measurement under Apple's then-current tracking definition.
5. If tracking occurs, implement ATT and disclose tracking before submission; otherwise keep the no-ATT configuration.

No mediation adapters should be added without repeating this review.

## Likely App Store data-type rows to review

| Apple category | Why it may appear | Budget app itself sends it? |
|---|---|---|
| Coarse Location | IP-derived general location in ad SDK | No |
| Device ID | Google Mobile Ads SDK | No |
| Advertising Data | ads viewed / ad operations | No |
| Product Interaction | ad/app interaction used by SDK | No |
| Crash Data | SDK diagnostics | No |
| Performance Data | SDK performance diagnostics | No |

“Budget app itself sends it?” means Payday Left's own budgeting logic; third-party SDK behavior is still part of the app's disclosure responsibility.
