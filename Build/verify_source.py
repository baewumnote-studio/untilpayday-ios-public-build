"""Verify the selected native source, targets and registered Apple identity."""
import hashlib
import json
from pathlib import Path
import plistlib
import sys

ROOT = Path(__file__).resolve().parents[1]
BASELINE_MANIFEST_SHA256 = '6a97c6acc638e9c842d54f8e55def0a4f1c84c4cc7c852156e8399974d46f9b0'
APPROVED_CHANGE_MANIFEST_SHA256 = '032cf7aa86fb2ef6b9e68fd122f1e210ae8683f1a95f11518c4d0bd4114e3b3e'
APPROVED_PATHS = {
    'AppSources/UntilPayday/Views/Settings/AboutInfoView.swift',
    'AppSources/UntilPayday/Resources/Localizable.xcstrings',
    'AppSources/UntilPayday/Services/AdManager.swift',
}

def verify():
    baseline_raw = (ROOT / 'PUBLIC_SOURCE_MANIFEST.json').read_bytes()
    if hashlib.sha256(baseline_raw).hexdigest() != BASELINE_MANIFEST_SHA256:
        raise ValueError('Original source baseline manifest changed.')
    manifest = json.loads(baseline_raw)
    expected = {entry['path']: entry for entry in manifest['files']}
    if len(expected) != 84 or manifest['sourceCodeAndAssetChanges'] != 0:
        raise ValueError('Protected source inventory changed; review before updating the manifest.')
    approved_raw = (ROOT / 'Build/approved_source_changes.json').read_bytes()
    if hashlib.sha256(approved_raw).hexdigest() != APPROVED_CHANGE_MANIFEST_SHA256:
        raise ValueError('Owner-approved source change record changed.')
    approved_record = json.loads(approved_raw)
    approved = {entry['path']: entry for entry in approved_record['approvedSourceChanges']}
    if (approved_record['baselineSourceCommit'] != manifest['sourceCommit'] or
            len(approved_record['approvedSourceChanges']) != 3 or set(approved) != APPROVED_PATHS or
            any(entry['originalSha256'] != expected[name]['sha256'] for name, entry in approved.items())):
        raise ValueError('Only the three explicitly approved release changes may differ from the original.')
    actual = set()
    for folder in ('AppSources', 'AppTests', 'CorePackage'):
        for path in (ROOT / folder).rglob('*'):
            if path.is_file() and not any(part in ('.build', '__pycache__') for part in path.parts):
                actual.add(path.relative_to(ROOT).as_posix())
    if actual != set(expected):
        raise ValueError('Missing or unreviewed protected source/asset files.')
    for name, entry in expected.items():
        raw = (ROOT / name).read_bytes()
        selected = approved.get(name, entry)
        if len(raw) != selected['bytes'] or hashlib.sha256(raw).hexdigest() != selected['sha256']:
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
    print('81 protected files match the original and 3 match explicit owner-approved release changes; app and widget identity match.')

if __name__ == '__main__':
    try:
        verify()
    except (OSError, ValueError, KeyError) as error:
        print('Source verification failed: ' + str(error), file=sys.stderr)
        raise SystemExit(1)

