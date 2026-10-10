"""Verify the selected native source, targets and registered Apple identity."""
import hashlib
import json
from pathlib import Path
import plistlib
import sys

ROOT = Path(__file__).resolve().parents[1]

def verify():
    manifest = json.loads((ROOT / 'PUBLIC_SOURCE_MANIFEST.json').read_text(encoding='utf-8'))
    expected = {entry['path']: entry for entry in manifest['files']}
    if len(expected) != 84 or manifest['sourceCodeAndAssetChanges'] != 0:
        raise ValueError('Protected source inventory changed; review before updating the manifest.')
    actual = set()
    for folder in ('AppSources', 'AppTests', 'CorePackage'):
        for path in (ROOT / folder).rglob('*'):
            if path.is_file() and not any(part in ('.build', '__pycache__') for part in path.parts):
                actual.add(path.relative_to(ROOT).as_posix())
    if actual != set(expected):
        raise ValueError('Missing or unreviewed protected source/asset files.')
    for name, entry in expected.items():
        raw = (ROOT / name).read_bytes()
        if len(raw) != entry['bytes'] or hashlib.sha256(raw).hexdigest() != entry['sha256']:
            raise ValueError('Protected source or asset changed: ' + name)
    identity = json.loads((ROOT / 'Build/identity.json').read_text(encoding='utf-8'))
    group = identity['appGroupID']
    for name in ('AppInfo.plist', 'WidgetInfo.plist'):
        if plistlib.loads((ROOT / 'Config' / name).read_bytes())['AppGroupIdentifier'] != group:
            raise ValueError('App Group Info.plist mismatch.')
    for name in ('UntilPayday.entitlements', 'UntilPaydayWidget.entitlements'):
        if plistlib.loads((ROOT / 'Config' / name).read_bytes())['com.apple.security.application-groups'] != [group]:
            raise ValueError('App Group entitlement mismatch.')
    for name in ('project.yml', 'UntilPayday.xcodeproj/project.pbxproj'):
        text = (ROOT / name).read_text(encoding='utf-8')
        if 'com.example.untilpayday' in text:
            raise ValueError('Template bundle identifier remains.')
        for bundle in (identity['mainBundleID'], identity['widgetBundleID']):
            if bundle not in text:
                raise ValueError('Registered target bundle identifier missing.')
    print('84 source, test, core and asset files match the reviewed original; app and widget identity match.')

if __name__ == '__main__':
    try:
        verify()
    except (OSError, ValueError, KeyError) as error:
        print('Source verification failed: ' + str(error), file=sys.stderr)
        raise SystemExit(1)

