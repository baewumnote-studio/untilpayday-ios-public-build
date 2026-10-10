"""App Store signing verification and an isolated native build copy; no device identifiers."""
import argparse
import base64
from datetime import datetime, timedelta, timezone
import hashlib
import json
import os
from pathlib import Path
import plistlib
import re
import shutil
import subprocess
import sys
import tempfile
import zipfile

from cryptography import x509
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.serialization import pkcs12

ROOT = Path(__file__).resolve().parents[1]
TARGETS = ('UntilPayday', 'UntilPaydayWidget')
PROFILE_NAMES = ('untilpayday-app.mobileprovision', 'untilpayday-widget.mobileprovision')
PROFILE_SECRETS = ('UNTILPAYDAY_STORE_APP_PROFILE_BASE64', 'UNTILPAYDAY_STORE_WIDGET_PROFILE_BASE64')
TEST_APP_ID = 'ca-app-pub-3940256099942544~1458002511'
TEST_UNIT_ID = 'ca-app-pub-3940256099942544/4411468910'


def identity(require_registration=True):
    result = json.loads((ROOT / 'Build/identity.json').read_text(encoding='utf-8'))
    if require_registration and result.get('registrationVerified') is not True:
        raise ValueError('UntilPayday Apple identity has not been registered and verified.')
    for field in ('mainBundleID', 'widgetBundleID', 'appGroupID'):
        if not re.fullmatch(r'[a-zA-Z0-9-]+(?:\.[a-zA-Z0-9-]+)+', result.get(field, '')):
            raise ValueError('Missing or invalid app identity.')
    if ('com.example' in result['mainBundleID'] or
            result['widgetBundleID'] != result['mainBundleID'] + '.widget' or
            not result['appGroupID'].startswith('group.') or
            not re.fullmatch(r'[A-Z0-9]{10}', result.get('teamID', '')) or
            not re.fullmatch(r'[0-9a-f]{64}', result.get('certificateSHA256', ''))):
        raise ValueError('App, widget, group, team or approved certificate identity is invalid.')
    return result


def bundles(config):
    return (config['mainBundleID'], config['widgetBundleID'])


def check_profile(profile, bundle, config):
    expiration = profile.get('ExpirationDate')
    if not isinstance(expiration, datetime):
        raise ValueError('Provisioning profile expiry is missing.')
    if expiration.tzinfo is None:
        expiration = expiration.replace(tzinfo=timezone.utc)
    entitlements = profile.get('Entitlements', {})
    if (not re.fullmatch(r'[A-Fa-f0-9]{8}(?:-[A-Fa-f0-9]{4}){3}-[A-Fa-f0-9]{12}', profile.get('UUID', '')) or
            expiration <= datetime.now(timezone.utc) + timedelta(days=1) or
            profile.get('TeamIdentifier') != [config['teamID']] or
            profile.get('ApplicationIdentifierPrefix') != [config['teamID']] or
            entitlements.get('application-identifier') != config['teamID'] + '.' + bundle or
            entitlements.get('com.apple.developer.team-identifier') != config['teamID'] or
            entitlements.get('get-task-allow') is not False or
            entitlements.get('beta-reports-active') is not True or
            'ProvisionedDevices' in profile or
            profile.get('ProvisionsAllDevices') is True or
            entitlements.get('com.apple.security.application-groups') != [config['appGroupID']]):
        raise ValueError('Expected a matching App Store distribution profile, group and valid expiry.')
    approved = [raw for raw in profile.get('DeveloperCertificates', [])
                if hashlib.sha256(raw).hexdigest() == config['certificateSHA256']]
    if len(approved) != 1:
        raise ValueError('Profile must contain the approved existing Distribution certificate.')
    check_certificate(approved[0], config)

def ad_values():
    mode = os.environ.get('AD_MODE', 'production')
    if mode == 'test':
        return TEST_APP_ID, TEST_UNIT_ID
    if mode != 'production':
        raise ValueError('Unknown advertising deployment mode.')
    app = os.environ.get('UNTILPAYDAY_ADMOB_APP_ID', '')
    unit = os.environ.get('UNTILPAYDAY_ADMOB_INTERSTITIAL_ID', '')
    if (not re.fullmatch(r'ca-app-pub-[0-9]{16}~[0-9]{10}', app) or
            not re.fullmatch(r'ca-app-pub-[0-9]{16}/[0-9]{10}', unit) or
            app.split('~')[0] != unit.split('/')[0] or
            app == TEST_APP_ID or unit == TEST_UNIT_ID):
        raise ValueError('Verified production AdMob values for this app are required.')
    return app, unit


def check_certificate(raw, config):
    certificate = x509.load_der_x509_certificate(raw)
    team = certificate.subject.get_attributes_for_oid(x509.NameOID.ORGANIZATIONAL_UNIT_NAME)
    common = certificate.subject.get_attributes_for_oid(x509.NameOID.COMMON_NAME)
    now = datetime.now(timezone.utc)
    if (hashlib.sha256(raw).hexdigest() != config['certificateSHA256'] or
            len(team) != 1 or team[0].value != config['teamID'] or
            len(common) != 1 or not common[0].value.startswith('Apple Distribution:') or
            certificate.not_valid_before_utc > now or
            certificate.not_valid_after_utc <= now + timedelta(days=1)):
        raise ValueError('The approved existing Apple Distribution certificate is invalid.')
    return certificate


def decode_profile(data, openssl='openssl'):
    # Verify CMS content/signature integrity; -noverify skips the signer trust chain.
    result = subprocess.run([str(openssl), 'cms', '-verify', '-noverify', '-inform', 'DER'],
                            input=data, capture_output=True, check=True)
    return plistlib.loads(result.stdout)


def check_p12(data, password, profiles, config):
    key, certificate, _ = pkcs12.load_key_and_certificates(data, password.encode('utf-8'))
    if key is None or certificate is None:
        raise ValueError('P12 must contain the existing certificate and matching private key.')
    public = lambda value: value.public_bytes(serialization.Encoding.DER,
                                              serialization.PublicFormat.SubjectPublicKeyInfo)
    if public(key.public_key()) != public(certificate.public_key()):
        raise ValueError('P12 private key does not match its certificate.')
    raw = certificate.public_bytes(serialization.Encoding.DER)
    check_certificate(raw, config)
    if any(raw not in profile.get('DeveloperCertificates', []) for profile in profiles):
        raise ValueError('Both profiles must match the P12 certificate.')
    return raw


def secret_material(config, openssl='openssl'):
    required = (*PROFILE_SECRETS, 'UNTILPAYDAY_DISTRIBUTION_P12_BASE64',
                'UNTILPAYDAY_DISTRIBUTION_P12_PASSWORD')
    if any(not os.environ.get(name) for name in required):
        raise ValueError('The existing P12 and both App Store profiles are required before a Mac build.')
    raws = [base64.b64decode(os.environ[name], validate=True) for name in PROFILE_SECRETS]
    profiles = [decode_profile(raw, openssl) for raw in raws]
    for profile, bundle in zip(profiles, bundles(config)):
        check_profile(profile, bundle, config)
    p12 = base64.b64decode(os.environ['UNTILPAYDAY_DISTRIBUTION_P12_BASE64'], validate=True)
    check_p12(p12, os.environ['UNTILPAYDAY_DISTRIBUTION_P12_PASSWORD'], profiles, config)
    return raws, profiles, p12


def encode(value, depth=0):
    indent = '\t' * depth
    if isinstance(value, dict):
        return '{\n' + '\n'.join(f'{indent}\t{encode(str(key))} = {encode(item, depth + 1)};'
                                  for key, item in value.items()) + '\n' + indent + '}'
    if isinstance(value, list):
        return '(\n' + '\n'.join(f'{indent}\t{encode(item, depth + 1)},' for item in value) + '\n' + indent + ')'
    return json.dumps(str(value), ensure_ascii=False)


def prepare_copy(destination, config, profiles, number):
    if destination.exists() or not re.fullmatch(r'[1-9][0-9]*', number):
        raise ValueError('Use a new build directory and positive build number.')
    sys.path.insert(0, str(ROOT / 'Build/local/tools'))
    from openstep_parser import OpenStepDecoder
    destination.mkdir(parents=True)
    for name in ('AppSources', 'AppTests', 'CorePackage', 'Config', 'Scripts', 'UntilPayday.xcodeproj'):
        shutil.copytree(ROOT / name, destination / name,
                        ignore=shutil.ignore_patterns('.build', '__pycache__', 'xcuserdata'))
    for name in ('project.yml', 'PUBLIC_SOURCE_MANIFEST.json'):
        shutil.copyfile(ROOT / name, destination / name)
    with (destination / 'UntilPayday.xcodeproj/project.pbxproj').open(encoding='utf-8') as handle:
        project = OpenStepDecoder.ParseFromFile(handle)
    objects = project['objects']
    targets = {obj['name']: obj for obj in objects.values() if obj['isa'] == 'PBXNativeTarget'}
    for name, bundle, profile in zip(TARGETS, bundles(config), profiles):
        target = targets[name]
        for reference in objects[target['buildConfigurationList']]['buildConfigurations']:
            settings = objects[reference]['buildSettings']
            settings.update(PRODUCT_BUNDLE_IDENTIFIER=bundle, DEVELOPMENT_TEAM=config['teamID'],
                            CODE_SIGN_STYLE='Manual', CODE_SIGN_IDENTITY='Apple Distribution',
                            PROVISIONING_PROFILE_SPECIFIER=profile['UUID'],
                            CURRENT_PROJECT_VERSION=number, MARKETING_VERSION=config['version'])
    (destination / 'UntilPayday.xcodeproj/project.pbxproj').write_text(
        '// !$*UTF8*$!\n' + encode(project) + '\n', encoding='utf-8')
    for filename in ('AppInfo.plist', 'WidgetInfo.plist'):
        path = destination / 'Config' / filename
        value = plistlib.loads(path.read_bytes())
        value['AppGroupIdentifier'] = config['appGroupID']
        if filename == 'AppInfo.plist':
            value['GADApplicationIdentifier'], value['GADInterstitialAdUnitID'] = ad_values()
        path.write_bytes(plistlib.dumps(value, sort_keys=False))
    for filename in ('UntilPayday.entitlements', 'UntilPaydayWidget.entitlements'):
        path = destination / 'Config' / filename
        value = plistlib.loads(path.read_bytes())
        value['com.apple.security.application-groups'] = [config['appGroupID']]
        path.write_bytes(plistlib.dumps(value, sort_keys=False))
    for folder in ('AppSources', 'AppTests', 'CorePackage/Sources', 'CorePackage/Tests'):
        for path in (ROOT / folder).rglob('*'):
            if path.is_file() and '__pycache__' not in path.parts:
                if path.read_bytes() != (destination / path.relative_to(ROOT)).read_bytes():
                    raise ValueError('Build copy changed an approved source or asset.')


def install_and_prepare(config):
    temporary = Path(os.environ['RUNNER_TEMP'])
    raws, profiles, p12 = secret_material(config)
    folder = Path.home() / 'Library/MobileDevice/Provisioning Profiles'
    folder.mkdir(parents=True, exist_ok=True)
    for raw, profile, name in zip(raws, profiles, PROFILE_NAMES):
        for path in (temporary / name, folder / (profile['UUID'] + '.mobileprovision')):
            path.write_bytes(raw)
            path.chmod(0o600)
    path = temporary / 'untilpayday-distribution.p12'
    path.write_bytes(p12)
    path.chmod(0o600)
    options = {'method': 'app-store-connect', 'destination': 'export', 'teamID': config['teamID'],
               'signingStyle': 'manual', 'signingCertificate': 'Apple Distribution',
               'manageAppVersionAndBuildNumber': False, 'uploadSymbols': False,
               'provisioningProfiles': {bundle: profile['UUID'] for bundle, profile in zip(bundles(config), profiles)}}
    (temporary / 'untilpayday-export.plist').write_bytes(plistlib.dumps(options))
    prepare_copy(temporary / 'untilpayday-build', config, profiles, os.environ['BUILD_NUMBER'])


def check_info(info, bundle, config, number, main=False):
    if (info.get('CFBundleIdentifier') != bundle or info.get('CFBundleVersion') != number or
            info.get('CFBundleShortVersionString') != config['version'] or
            info.get('MinimumOSVersion') != config['minimumOS'] or
            info.get('UIDeviceFamily') != [1] or
            info.get('AppGroupIdentifier') != config['appGroupID']):
        raise ValueError('Target identity, version, iPhone support, minimum OS or group changed.')
    if main and (info.get('GADApplicationIdentifier') != ad_values()[0] or
                 info.get('GADInterstitialAdUnitID') != ad_values()[1] or
                 info.get('CFBundleDisplayName') != 'Payday Left'):
        raise ValueError('Release name or explicitly selected advertising deployment values changed.')


def check_ipa(path, config, number, openssl='openssl'):
    with zipfile.ZipFile(path) as archive:
        infos = [n for n in archive.namelist() if n.startswith('Payload/') and
                 n.endswith('.app/Info.plist') and n.count('/') == 2]
        if len(infos) != 1:
            raise ValueError('Expected one UntilPayday app.')
        parent = infos[0].removesuffix('Info.plist')
        widgets = [n for n in archive.namelist() if n.startswith(parent + 'PlugIns/') and
                   n.endswith('.appex/Info.plist') and n.count('/') == 4]
        if len(widgets) != 1:
            raise ValueError('Expected exactly one embedded widget.')
        for index, (name, bundle) in enumerate(zip(infos + widgets, bundles(config))):
            check_info(plistlib.loads(archive.read(name)), bundle, config, number, main=index == 0)
            raw = archive.read(name.removesuffix('Info.plist') + 'embedded.mobileprovision')
            check_profile(decode_profile(raw, openssl), bundle, config)


def check_native(path, config, number):
    extensions = list((path / 'PlugIns').glob('*.appex'))
    if len(extensions) != 1:
        raise ValueError('Archive must contain exactly one widget.')
    for index, (target, bundle) in enumerate(zip((path, extensions[0]), bundles(config))):
        check_info(plistlib.loads((target / 'Info.plist').read_bytes()), bundle, config, number, main=index == 0)
        subprocess.run(['codesign', '--verify', '--deep', '--strict', str(target)], check=True, capture_output=True)
        with tempfile.TemporaryDirectory() as cert_folder:
            subprocess.run(['codesign', '-d', '--extract-certificates', str(target)],
                           cwd=cert_folder, capture_output=True, check=True)
            check_certificate((Path(cert_folder) / 'codesign0').read_bytes(), config)
        result = subprocess.run(['codesign', '-d', '--entitlements', '-', '--xml', str(target)],
                                capture_output=True, check=True)
        output = result.stdout + result.stderr
        start, end = output.find(b'<?xml'), output.find(b'</plist>')
        if start < 0 or end < start:
            raise ValueError('Cannot read signed target entitlements.')
        value = plistlib.loads(output[start:end + len(b'</plist>')])
        if (value.get('application-identifier') != config['teamID'] + '.' + bundle or
                value.get('com.apple.developer.team-identifier') != config['teamID'] or
                value.get('com.apple.security.application-groups') != [config['appGroupID']] or
                value.get('get-task-allow', False) is not False):
            raise ValueError('Actual signed target entitlements mismatch.')
        check_profile(decode_profile((target / 'embedded.mobileprovision').read_bytes()), bundle, config)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('mode', choices=('preflight', 'prepare', 'verify-archive', 'verify-ipa'))
    parser.add_argument('--path', type=Path)
    args = parser.parse_args()
    config = identity()
    ad_values()
    if args.mode == 'preflight':
        secret_material(config)
    elif args.mode == 'prepare':
        install_and_prepare(config)
    elif args.mode == 'verify-archive':
        apps = list((args.path / 'Products/Applications').glob('*.app'))
        if len(apps) != 1:
            raise ValueError('Expected one archive app.')
        check_native(apps[0], config, os.environ['BUILD_NUMBER'])
    else:
        check_ipa(args.path, config, os.environ['BUILD_NUMBER'])
    print('UntilPayday ' + args.mode + ' checks passed; credentials are not logged.')


if __name__ == '__main__':
    try:
        main()
    except (OSError, ValueError, KeyError, subprocess.SubprocessError, zipfile.BadZipFile) as error:
        import traceback
        phase = traceback.extract_tb(error.__traceback__)[-1].name
        print('UntilPayday signing verification failed: ' + type(error).__name__ + ' in ' + phase + '; credential values are not logged.', file=sys.stderr)
        raise SystemExit(1)
