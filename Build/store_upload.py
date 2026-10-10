"""Upload a verified IPA directly using the existing App Store Connect API key."""
import base64
from datetime import datetime, timedelta, timezone
import json
import os
from pathlib import Path
import plistlib
import re
import subprocess
import urllib.request

from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import ec
from cryptography.hazmat.primitives.asymmetric.utils import decode_dss_signature

def api_key():
    raw = base64.b64decode(os.environ['UNTILPAYDAY_ASC_KEY_BASE64'], validate=True)
    key = serialization.load_pem_private_key(raw, password=None)
    if not isinstance(key, ec.EllipticCurvePrivateKey) or not isinstance(key.curve, ec.SECP256R1):
        raise ValueError('Expected an existing App Store Connect P-256 API key.')
    return raw, key

def check_app():
    _, key = api_key()
    key_id = os.environ['UNTILPAYDAY_ASC_KEY_ID']
    issuer = os.environ['UNTILPAYDAY_ASC_ISSUER_ID']
    if not re.fullmatch(r'[A-Z0-9]{10}', key_id): raise ValueError('Invalid key ID')
    if not re.fullmatch(r'[a-f0-9-]{36}', issuer): raise ValueError('Invalid issuer ID')
    encode = lambda raw: base64.urlsafe_b64encode(raw).rstrip(b'=')
    now = datetime.now(timezone.utc)
    header = encode(json.dumps({'alg':'ES256','kid':key_id,'typ':'JWT'}).encode())
    body = encode(json.dumps({'iss':issuer,'iat':int(now.timestamp()),
        'exp':int((now + timedelta(minutes=5)).timestamp()),'aud':'appstoreconnect-v1'}).encode())
    signing = header + b'.' + body
    r, s = decode_dss_signature(key.sign(signing, ec.ECDSA(hashes.SHA256())))
    token = (signing + b'.' + encode(r.to_bytes(32,'big') + s.to_bytes(32,'big'))).decode()
    app_id = os.environ['UNTILPAYDAY_ASC_APP_ID']
    if not re.fullmatch(r'[1-9][0-9]*', app_id): raise ValueError('Invalid app ID')
    request = urllib.request.Request('https://api.appstoreconnect.apple.com/v1/apps/' + app_id,
        headers={'Authorization':'Bearer ' + token})
    with urllib.request.urlopen(request, timeout=30) as response: app = json.load(response)
    if app['data']['attributes']['bundleId'] != 'com.baewumnote.untilpayday':
        raise ValueError('App Store app does not match the existing bundle ID.')
    print('Existing API key can read the matching registered App Store app.')

def upload():
    check_app()
    raw, _ = api_key()
    folder = Path.home() / '.appstoreconnect/private_keys'
    folder.mkdir(parents=True, exist_ok=True)
    path = folder / ('AuthKey_' + os.environ['UNTILPAYDAY_ASC_KEY_ID'] + '.p8')
    path.write_bytes(raw); path.chmod(0o600)
    try:
        subprocess.run(['xcrun','altool','--upload-app','--type','ios','--file',
            str(Path(os.environ['RUNNER_TEMP'])/'untilpayday-ipa/UntilPayday.ipa'),
            '--apiKey',os.environ['UNTILPAYDAY_ASC_KEY_ID'],
            '--apiIssuer',os.environ['UNTILPAYDAY_ASC_ISSUER_ID']], check=True)
    finally:
        path.unlink(missing_ok=True)
    print('IPA upload request accepted. Apple processing and TestFlight availability still require verification.')

if __name__ == '__main__':
    import argparse
    p=argparse.ArgumentParser();p.add_argument('mode',choices=('check-app','upload'));mode=p.parse_args().mode
    try:
        check_app() if mode == 'check-app' else upload()
    except Exception:
        raise SystemExit('App Store API/upload failed; investigate Apple account and upload results separately.')
