"""Reject wrong distribution methods, account identities, certificates and changed app content."""
import copy
from datetime import datetime, timedelta, timezone
import hashlib
import json
from pathlib import Path
import plistlib
import tempfile
import unittest
from unittest.mock import patch

from cryptography import x509
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import rsa
from cryptography.hazmat.primitives.serialization import pkcs12

import store_signing as signing


class SigningTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
        subject = x509.Name([x509.NameAttribute(x509.NameOID.COMMON_NAME, 'Apple Distribution: LOCAL TEST FIXTURE'),
                             x509.NameAttribute(x509.NameOID.ORGANIZATIONAL_UNIT_NAME, 'TESTTEAM01')])
        now = datetime.now(timezone.utc)
        cls.certificate = (x509.CertificateBuilder().subject_name(subject).issuer_name(subject)
                           .public_key(cls.key.public_key()).serial_number(x509.random_serial_number())
                           .not_valid_before(now - timedelta(days=1)).not_valid_after(now + timedelta(days=30))
                           .sign(cls.key, hashes.SHA256()))
        cls.raw = cls.certificate.public_bytes(serialization.Encoding.DER)
        cls.udid = '00000000-0000000000000001'  # Synthetic fixture, never a real phone.
        cls.config = {'registrationVerified': True, 'teamID': 'TESTTEAM01',
                      'mainBundleID': 'com.test.untilpayday', 'widgetBundleID': 'com.test.untilpayday.widget',
                      'appGroupID': 'group.com.test.untilpayday.shared', 'version': '1.0', 'minimumOS': '17.0',
                      'certificateSHA256': hashlib.sha256(cls.raw).hexdigest()}
        cls.p12 = pkcs12.serialize_key_and_certificates(b'local-test', cls.key, cls.certificate, None,
                                                       serialization.BestAvailableEncryption(b'test-password'))

    def setUp(self):
        ads=patch.dict(signing.os.environ, {'AD_MODE':'test'})
        ads.start(); self.addCleanup(ads.stop)
        self.profile = {'UUID': '00000000-0000-0000-0000-000000000001',
                        'TeamIdentifier': ['TESTTEAM01'], 'ApplicationIdentifierPrefix': ['TESTTEAM01'],
                        'ExpirationDate': datetime.now(timezone.utc) + timedelta(days=10),
                        'DeveloperCertificates': [self.raw],
                        'Entitlements': {'application-identifier': 'TESTTEAM01.com.test.untilpayday',
                                         'com.apple.developer.team-identifier': 'TESTTEAM01',
                                         'get-task-allow': False, 'beta-reports-active': True,
                                         'com.apple.security.application-groups': [self.config['appGroupID']]}}
        self.info = {'CFBundleIdentifier': self.config['mainBundleID'], 'CFBundleVersion': '1',
                     'CFBundleShortVersionString': '1.0', 'MinimumOSVersion': '17.0', 'UIDeviceFamily': [1],
                     'AppGroupIdentifier': self.config['appGroupID'], 'CFBundleDisplayName': 'Payday Left',
                     'GADApplicationIdentifier': signing.TEST_APP_ID, 'GADInterstitialAdUnitID': signing.TEST_UNIT_ID}

    def check(self):
        signing.check_profile(self.profile, self.config['mainBundleID'], self.config)

    def test_matching_app_store_profile(self):
        self.check()

    def test_adhoc_profile_rejected(self):
        self.profile['ProvisionedDevices'] = ['00000000-0000000000000002']
        with self.assertRaises(ValueError): self.check()

    def test_even_empty_devices_field_rejected(self):
        self.profile['ProvisionedDevices'] = []
        with self.assertRaises(ValueError): self.check()

    def test_missing_app_store_beta_entitlement_rejected(self):
        del self.profile['Entitlements']['beta-reports-active']
        with self.assertRaises(ValueError): self.check()

    def test_development_profile_rejected(self):
        self.profile['Entitlements']['get-task-allow'] = True
        with self.assertRaises(ValueError): self.check()

    def test_enterprise_profile_rejected(self):
        self.profile['ProvisionsAllDevices'] = True
        with self.assertRaises(ValueError): self.check()

    def test_other_team_rejected(self):
        self.profile['TeamIdentifier'] = ['OTHERTEAM1']
        with self.assertRaises(ValueError): self.check()

    def test_other_app_group_rejected(self):
        self.profile['Entitlements']['com.apple.security.application-groups'] = ['group.other.app']
        with self.assertRaises(ValueError): self.check()

    def test_wildcard_bundle_rejected(self):
        self.profile['Entitlements']['application-identifier'] = 'TESTTEAM01.com.test.*'
        with self.assertRaises(ValueError): self.check()

    def test_expired_profile_rejected(self):
        self.profile['ExpirationDate'] = datetime.now(timezone.utc) - timedelta(seconds=1)
        with self.assertRaises(ValueError): self.check()

    def test_missing_certificate_rejected(self):
        self.profile['DeveloperCertificates'] = []
        with self.assertRaises(ValueError): self.check()

    def test_matching_private_key_and_certificate(self):
        self.assertEqual(signing.check_p12(self.p12, 'test-password', [self.profile, self.profile], self.config), self.raw)

    def test_wrong_p12_password_rejected(self):
        with self.assertRaises(ValueError):
            signing.check_p12(self.p12, 'wrong-password', [self.profile], self.config)

    def test_public_certificate_only_p12_rejected(self):
        data = pkcs12.serialize_key_and_certificates(b'local-test', None, self.certificate, None,
                                                     serialization.BestAvailableEncryption(b'test-password'))
        with self.assertRaises(ValueError):
            signing.check_p12(data, 'test-password', [self.profile], self.config)

    def test_wrong_existing_certificate_fingerprint_rejected(self):
        config = {**self.config, 'certificateSHA256': '0' * 64}
        with self.assertRaises(ValueError):
            signing.check_p12(self.p12, 'test-password', [self.profile], config)

    def test_widget_profile_cannot_replace_main_profile(self):
        self.profile['Entitlements']['application-identifier'] += '.widget'
        with self.assertRaises(ValueError): self.check()

    def test_wrong_ad_id_in_explicit_test_mode_rejected(self):
        self.info['GADInterstitialAdUnitID'] = 'ca-app-pub-production/unit'
        with self.assertRaises(ValueError):
            signing.check_info(self.info, self.config['mainBundleID'], self.config, '1', main=True)

    def test_correct_test_ad_configuration(self):
        signing.check_info(self.info, self.config['mainBundleID'], self.config, '1', main=True)

    def test_changed_app_copy_rejected(self):
        self.info['CFBundleDisplayName'] = 'Renamed'
        with self.assertRaises(ValueError):
            signing.check_info(self.info, self.config['mainBundleID'], self.config, '1', main=True)

    def test_unregistered_identity_blocks_build(self):
        with patch('store_signing.Path.read_text', return_value=json.dumps({**self.config, 'registrationVerified': False})), self.assertRaises(ValueError):
            signing.identity()

    def test_build_copy_preserves_sources_assets_and_target_membership(self):
        local = signing.ROOT / 'Build/local'
        local.mkdir(parents=True, exist_ok=True)
        with tempfile.TemporaryDirectory(dir=local) as folder:
            destination = Path(folder) / 'draft'
            profiles = [self.profile, {**self.profile, 'UUID': '00000000-0000-0000-0000-000000000002'}]
            signing.prepare_copy(destination, self.config, profiles, '1')
            from openstep_parser import OpenStepDecoder
            with (signing.ROOT / 'UntilPayday.xcodeproj/project.pbxproj').open(encoding='utf-8') as handle:
                before = OpenStepDecoder.ParseFromFile(handle)
            with (destination / 'UntilPayday.xcodeproj/project.pbxproj').open(encoding='utf-8') as handle:
                after = OpenStepDecoder.ParseFromFile(handle)
            self.assertEqual(set(before['objects']), set(after['objects']))
            for key, value in before['objects'].items():
                if value['isa'] != 'XCBuildConfiguration':
                    self.assertEqual(value, after['objects'][key])
            info = plistlib.loads((destination / 'Config/AppInfo.plist').read_bytes())
            self.assertEqual(info['GADInterstitialAdUnitID'], signing.TEST_UNIT_ID)
            self.assertEqual(info['AppGroupIdentifier'], self.config['appGroupID'])
            self.assertEqual(info['CFBundleDisplayName'], 'Payday Left')

    def test_production_mode_requires_real_ad_values(self):
        with patch.dict(signing.os.environ, {'AD_MODE':'production'}, clear=True):
            with self.assertRaises(ValueError): signing.ad_values()

    def test_production_mode_rejects_official_test_ids(self):
        with patch.dict(signing.os.environ, {'AD_MODE':'production',
            'UNTILPAYDAY_ADMOB_APP_ID':signing.TEST_APP_ID,
            'UNTILPAYDAY_ADMOB_INTERSTITIAL_ID':signing.TEST_UNIT_ID}):
            with self.assertRaises(ValueError): signing.ad_values()

    def test_missing_signing_secrets_prevents_build(self):
        with patch.dict(signing.os.environ, {}, clear=True), self.assertRaises(ValueError):
            signing.secret_material(self.config)


if __name__ == '__main__':
    unittest.main()
