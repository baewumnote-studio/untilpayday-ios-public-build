#!/usr/bin/env bash
# Run on an Xcode macOS host, after the original handoff verification succeeds.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
mkdir -p AssemblyVerification/ios
LOGS="$ROOT/AssemblyVerification/ios"

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "Xcode/iOS SDK verification requires macOS." >&2
  exit 2
fi

xcodebuild -version | tee "$LOGS/xcode-version.log"
xcodebuild -showsdks | tee "$LOGS/apple-sdks.log"
swift --version | tee "$LOGS/swift-version.log"

# The user's required ordering: full original verification before any iOS build.
python3 Build/verify_source.py 2>&1 | tee "$LOGS/verify-handoff.log"
# Type-check the recorded compatibility fixes in the actual iOS build below;
# also syntax-parse the patched source before resolving/building any target.
while IFS= read -r file; do
  swiftc -frontend -parse "$file" >/dev/null
done < <(find AppSources AppTests CorePackage/Sources CorePackage/Tests -type f -name '*.swift' | sort)

plutil -lint UntilPayday.xcodeproj/project.pbxproj | tee "$LOGS/project-plist-lint.log"
python3 Scripts/verify_xcode_assembly.py | tee "$LOGS/assembly-structure.log"
xcodebuild -resolvePackageDependencies -project UntilPayday.xcodeproj -scheme UntilPayday \
  -clonedSourcePackagesDirPath "$LOGS/SourcePackages" 2>&1 | tee "$LOGS/spm-resolve.log"
xcodebuild -list -json -project UntilPayday.xcodeproj > "$LOGS/xcode-project-list.json"
xcrun simctl list devices available -j > "$LOGS/simulator-devices.json"
python3 - <<'PY'
import json, pathlib
folder = pathlib.Path('AssemblyVerification/ios')
data = json.loads((folder / 'simulator-devices.json').read_text())
devices = [(runtime, device) for runtime, group in data['devices'].items()
           for device in group if device.get('isAvailable') and device['name'].startswith('iPhone')
           and 'iOS' in runtime]
if not devices:
    raise SystemExit('No available iPhone iOS Simulator; install an iOS runtime before continuing.')
runtime, device = sorted(devices, key=lambda pair: (pair[0], pair[1]['name']))[-1]
(folder / 'simulator-udid.txt').write_text(device['udid'])
(folder / 'selected-simulator.json').write_text(json.dumps({'runtime': runtime, **device}, indent=2))
print(f"Selected Simulator: {device['name']} / {runtime} / {device['udid']}")
PY
SIMULATOR_ID="$(cat "$LOGS/simulator-udid.txt")"
DESTINATION="platform=iOS Simulator,id=$SIMULATOR_ID"
DERIVED_DATA="$LOGS/DerivedData"
COMMON=(-project UntilPayday.xcodeproj -configuration Debug -sdk iphonesimulator
        -destination "$DESTINATION" -derivedDataPath "$DERIVED_DATA"
        -clonedSourcePackagesDirPath "$LOGS/SourcePackages"
        CODE_SIGNING_ALLOWED=YES CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY=-)

xcodebuild "${COMMON[@]}" -scheme UntilPayday build 2>&1 | tee "$LOGS/app-build.log"
xcodebuild "${COMMON[@]}" -scheme UntilPaydayWidget build 2>&1 | tee "$LOGS/widget-build.log"

# Simulator launch evidence. This is not a Home/Lock Screen widget runtime check.
APP="$DERIVED_DATA/Build/Products/Debug-iphonesimulator/UntilPayday.app"
test -d "$APP/PlugIns/UntilPaydayWidget.appex"
/usr/libexec/PlistBuddy -c 'Print :AppGroupIdentifier' "$APP/Info.plist" > "$LOGS/app-group-app.txt"
/usr/libexec/PlistBuddy -c 'Print :AppGroupIdentifier' "$APP/PlugIns/UntilPaydayWidget.appex/Info.plist" > "$LOGS/app-group-widget.txt"
cmp "$LOGS/app-group-app.txt" "$LOGS/app-group-widget.txt"
codesign -d --entitlements :- "$APP" > "$LOGS/app-signed-entitlements.plist" 2> "$LOGS/app-codesign.log"
codesign -d --entitlements :- "$APP/PlugIns/UntilPaydayWidget.appex" > "$LOGS/widget-signed-entitlements.plist" 2> "$LOGS/widget-codesign.log"
python3 Scripts/verify_simulator_entitlements.py --app "$APP" --output "$LOGS"
BUNDLE_ID="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP/Info.plist")"
if ! xcrun simctl list devices booted -j | python3 -c 'import json,sys; data=json.load(sys.stdin); sys.exit(0 if any(d["udid"]==sys.argv[1] and d["state"]=="Booted" for group in data["devices"].values() for d in group) else 1)' "$SIMULATOR_ID"; then
  xcrun simctl boot "$SIMULATOR_ID"
fi
xcrun simctl bootstatus "$SIMULATOR_ID" -b
xcrun simctl install "$SIMULATOR_ID" "$APP"
xcrun simctl launch "$SIMULATOR_ID" "$BUNDLE_ID" -ui-testing-visual-master YES | tee "$LOGS/simulator-launch.log"
sleep 3
xcrun simctl io "$SIMULATOR_ID" screenshot "$LOGS/simulator-launch.png"
ditto -c -k --sequesterRsrc --keepParent "$APP" "$LOGS/UntilPayday-Simulator.app.zip"
ditto -c -k --sequesterRsrc --keepParent UntilPayday.xcodeproj "$LOGS/UntilPayday.xcodeproj.zip"
python3 Build/verify_source.py | tee "$LOGS/manifest-after-build.log"

echo 'App Group configuration and embedded extension checked.'
echo 'WidgetSnapshotTests exercise widget calculations. The added ZZWidgetRuntimeTests exercises the real Home Screen extension, App Group refresh and Today URL; consult its actual XCTest result. Lock Screen families are not exercised by that test.'

# Preserve each suite's real result, and attempt both suites even if one fails.
set +e
UI_SELECTION=(-only-testing:UntilPaydayUITests)
UNIT_STATUS=0
UNIT_DESCRIPTION='not executed (focused widget verification)'
if [[ "${VERIFY_SCREENSHOTS_ONLY:-0}" == "1" ]]; then
  UI_SELECTION=(-only-testing:UntilPaydayUITests/ZZAppScreenshotTests)
  UNIT_DESCRIPTION='not executed (focused actual app screenshot capture)'
elif [[ "${VERIFY_WIDGET_ONLY:-0}" == "1" ]]; then
  UI_SELECTION=(-only-testing:UntilPaydayUITests/ZZWidgetRuntimeTests)
else
  xcodebuild "${COMMON[@]}" -scheme UntilPayday -only-testing:UntilPaydayTests \
    -parallel-testing-enabled NO -resultBundlePath "$LOGS/UnitTests.xcresult" test \
    2>&1 | tee "$LOGS/unit-tests.log"
  UNIT_STATUS=${PIPESTATUS[0]}
  UNIT_DESCRIPTION="executed; command exit $UNIT_STATUS"
fi
python3 Scripts/run_xcode_tests.py --log "$LOGS/ui-tests.log" --simulator "$SIMULATOR_ID" -- \
  xcodebuild "${COMMON[@]}" -scheme UntilPayday "${UI_SELECTION[@]}" \
  -parallel-testing-enabled NO -resultBundlePath "$LOGS/UITests.xcresult" test \
  2>&1
UI_STATUS=$?
for suite in UnitTests UITests; do
  if [[ -d "$LOGS/$suite.xcresult" ]]; then
    xcrun xcresulttool get test-results summary --path "$LOGS/$suite.xcresult" --compact > "$LOGS/$suite-summary.json"
    ditto -c -k --sequesterRsrc --keepParent "$LOGS/$suite.xcresult" "$LOGS/$suite.xcresult.zip"
  fi
done
if [[ -d "$LOGS/UITests.xcresult" ]]; then
  xcrun xcresulttool export attachments --path "$LOGS/UITests.xcresult" --output-path "$LOGS/UIAttachments"
  ditto -c -k --sequesterRsrc --keepParent "$LOGS/UIAttachments" "$LOGS/UIAttachments.zip"
fi
set -e
printf 'Unit test command: %s\nUI test command exit: %s\n' "$UNIT_DESCRIPTION" "$UI_STATUS" > "$LOGS/test-command-status.log"

if (( UNIT_STATUS != 0 || UI_STATUS != 0 )); then
  exit 1
fi
