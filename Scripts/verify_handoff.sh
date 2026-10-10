#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "[1/10] CorePackage tests"
(cd CorePackage && swift test)

echo "[2/10] Swift syntax parse"
while IFS= read -r file; do
  swiftc -frontend -parse "$file" >/dev/null
done < <(find AppSources AppTests CorePackage/Sources CorePackage/Tests -type f -name '*.swift' | sort)

echo "[3/10] Empty Swift file scan"
if find AppSources AppTests CorePackage/Sources CorePackage/Tests -type f -name '*.swift' -size 0 | grep -q .; then
  echo "Empty Swift source found" >&2
  find AppSources AppTests CorePackage/Sources CorePackage/Tests -type f -name '*.swift' -size 0 >&2
  exit 1
fi

echo "[4/10] Source marker / unsafe construct scan"
if grep -RInE 'TODO|FIXME|IMPLEMENT[ _-]?ME|PSEUDOCODE|NOT IMPLEMENTED' AppSources AppTests CorePackage/Sources CorePackage/Tests; then
  echo "Unfinished-source marker found" >&2
  exit 1
fi
if grep -RInE 'try![[:space:]]' AppSources/UntilPayday AppSources/Shared AppSources/UntilPaydayWidget; then
  echo "Production try! found" >&2
  exit 1
fi

echo "[5/10] JSON / plist-family validation"
python3 -m json.tool AppSources/UntilPayday/Resources/Localizable.xcstrings >/dev/null
python3 - <<'PY'
import plistlib, pathlib
for p in list(pathlib.Path('Config').glob('*.plist')) + list(pathlib.Path('Config').glob('*.entitlements')) + list(pathlib.Path('AppSources').rglob('*.xcprivacy')):
    with p.open('rb') as f: plistlib.load(f)
print('plist-family OK')
PY

echo "[6/10] Localization coverage"
python3 Scripts/sync_localization.py --check

echo "[7/10] project.yml / target-map / Visual Master / store metadata validation"
python3 - <<'PY'
import json, pathlib, plistlib, yaml
p = pathlib.Path('project.yml')
data = yaml.safe_load(p.read_text())
required_targets = {'UntilPayday','UntilPaydayWidget','UntilPaydayTests','UntilPaydayUITests'}
missing = required_targets - set(data.get('targets',{}))
if missing: raise SystemExit(f'missing targets: {sorted(missing)}')
required_packages = {'UntilPaydayCore','GoogleMobileAds','GoogleUserMessagingPlatform'}
missing = required_packages - set(data.get('packages',{}))
if missing: raise SystemExit(f'missing packages: {sorted(missing)}')
with open('Config/AppInfo.plist','rb') as f: app_info=plistlib.load(f)
with open('Config/WidgetInfo.plist','rb') as f: widget_info=plistlib.load(f)
with open('Config/UntilPayday.entitlements','rb') as f: app_ent=plistlib.load(f)
with open('Config/UntilPaydayWidget.entitlements','rb') as f: widget_ent=plistlib.load(f)
groups = [app_info.get('AppGroupIdentifier'), widget_info.get('AppGroupIdentifier'), app_ent.get('com.apple.security.application-groups',[None])[0], widget_ent.get('com.apple.security.application-groups',[None])[0]]
if len(set(groups)) != 1: raise SystemExit(f'App Group mismatch: {groups}')
router = pathlib.Path('AppSources/UntilPayday/App/AppRouter.swift').read_text()
main_tabs = pathlib.Path('AppSources/UntilPayday/App/MainTabView.swift').read_text()
for name in ['today','plan','history','settings']:
    if f'case {name}' not in router: raise SystemExit(f'router tab missing: {name}')
if 'SettingsView(settings: settings)' not in main_tabs: raise SystemExit('Settings fourth-tab source missing')
seed = pathlib.Path('AppSources/UntilPayday/Services/UITestBootstrap.swift').read_text()
if '-ui-testing-visual-master' not in seed: raise SystemExit('Visual Master screenshot seed missing')
for ident in ['leftUntilPaydayHero','safeTodayCard','trustSummaryCard','planSegmentedControl','paydaySummary']:
    found = any(ident in f.read_text() for f in pathlib.Path('AppSources/UntilPayday').rglob('*.swift'))
    if not found: raise SystemExit(f'accessibility identifier missing: {ident}')
metadata = json.loads(pathlib.Path('Config/AppStoreMetadata.json').read_text())
if len(metadata['name']) > 30: raise SystemExit('App Store name exceeds 30 characters')
if len(metadata['subtitle']) > 30: raise SystemExit('App Store subtitle exceeds 30 characters')
if len(metadata['promotionalText']) > 170: raise SystemExit('promotional text exceeds 170 characters')
if len(metadata['keywords'].encode('utf-8')) > 100: raise SystemExit('keywords exceed 100 UTF-8 bytes')
if app_info.get('CFBundleDisplayName') != metadata['name']: raise SystemExit('display name / store metadata mismatch')
print('project.yml + target map + Visual Master + store metadata OK')
PY

echo "[8/10] Production visual assets"
python3 - <<'PYASSET'
from pathlib import Path
from PIL import Image
import json
root=Path('.')
icon=root/'AppSources/UntilPayday/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png'
contents=root/'AppSources/UntilPayday/Resources/Assets.xcassets/AppIcon.appiconset/Contents.json'
if not icon.is_file() or not contents.is_file(): raise SystemExit('production AppIcon asset missing')
im=Image.open(icon)
if im.size != (1024,1024): raise SystemExit(f'AppIcon wrong size: {im.size}')
if im.mode not in ('RGB','L'): raise SystemExit(f'AppIcon must have no alpha; mode={im.mode}')
meta=json.loads(contents.read_text())
if not any(x.get('filename')=='AppIcon-1024.png' and x.get('size')=='1024x1024' for x in meta.get('images',[])):
    raise SystemExit('AppIcon Contents.json missing 1024 entry')
print('production visual assets OK')
PYASSET

echo "[9/10] Source inventory"
SWIFT_COUNT=$(find AppSources AppTests CorePackage/Sources CorePackage/Tests -type f -name '*.swift' | wc -l | tr -d ' ')
SWIFT_LINES=$(find AppSources AppTests CorePackage/Sources CorePackage/Tests -type f -name '*.swift' -print0 | xargs -0 cat | wc -l | tr -d ' ')
LOC_KEYS=$(python3 - <<'PY'
import json
with open('AppSources/UntilPayday/Resources/Localizable.xcstrings') as f: d=json.load(f)
print(len(d.get('strings',{})))
PY
)
echo "Swift files: $SWIFT_COUNT"
echo "Swift lines: $SWIFT_LINES"
echo "Localization keys: $LOC_KEYS"

echo "[10/10] Manifest"
python3 Build/verify_source.py

echo "Handoff verification OK"
