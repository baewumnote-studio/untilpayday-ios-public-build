# Payday Left — UntilPayday native iOS build source

This is an independent build repository containing the existing SwiftUI, SwiftData,
WidgetKit and UntilPaydayCore implementation. It is not a Flutter project. There is
no Dart source, pubspec, CocoaPods dependency, Flutter analyze or Flutter test step.
Dependencies are resolved by Swift Package Manager.

The private original repository and its Git history are preserved separately.
`PUBLIC_SOURCE_MANIFEST.json` records the 84 unchanged source, test, core and app
asset files selected from the reviewed original. No software license was added.
Public visibility does not itself establish a license to reuse the source or assets.

## Build and verification

`Native iOS compile, tests and widget` is manual only (`workflow_dispatch`). It
runs only on this repository's public `main` branch, dispatched by its owner.
Linux performs the native handoff script and Core tests first. The standard
`xcode-27` GitHub-hosted runner then compiles the unsigned iPhone Release with the
embedded widget, runs existing iOS Unit/UI tests, launches the Simulator, captures
six actual app screens using synthetic data, and exercises the real Home widget.
It has no signing or App Store credentials. No automatic push/PR builds are used.

Use Swift 6.4, Xcode 27.0 and iOS 17 or later, matching the previously verified
native project. Standard GitHub-hosted runners for public repositories are free:
https://docs.github.com/en/actions/reference/runners/github-hosted-runners

Local Mac verification, after installing `Build/requirements.txt`:

```sh
bash Scripts/verify_handoff.sh
bash Scripts/verify_ios_on_macos.sh
```

## Deployment

The registered main bundle ID, widget ID and App Group are preserved in
`Build/identity.json`. The app's display name is Payday Left. Release signing is
separate from unsigned verification and uses a protected `app-store` environment.
The release workflow is manual, checks a successful verification run for the same
commit, validates both App Store profiles and the existing Distribution
certificate, and directly uploads to App Store Connect. It never publishes an IPA
or xcarchive artifact in this repository. Store review is a separate owner action.

Private delivery retention must be configured before the release workflow runs:
a narrowly scoped credential writes an unpublished draft Release's IPA and
xcarchive assets in the existing private repository, without changing its source
or commit history. This requires separate owner authorization. The credential
never reaches unsigned tests or an external pull request.

Production AdMob identifiers, consent configuration, public privacy/support/
marketing URLs, app-ads.txt publisher identity, final privacy disclosures and
remaining physical iPhone QA must be verified before store review. The checked-in
app plist retains its original sample App ID and empty Release ad unit. The
release build replaces only these deployment values in an isolated build copy.

See `Docs/RELEASE_STATUS_KO.md` for the actual current results and remaining gates.
