"""Retain verified signed files only as draft assets in the existing PRIVATE repo."""
import hashlib
import json
import os
from pathlib import Path
import re
import urllib.request

PRIVATE = 'baewumnote-studio/untilpayday-ios'

def request(path, data=None, method=None):
    req=urllib.request.Request('https://api.github.com' + path, method=method,
        data=json.dumps(data).encode() if data is not None else None,
        headers={'Authorization':'Bearer ' + os.environ['UNTILPAYDAY_PRIVATE_DELIVERY_TOKEN'],
            'Accept':'application/vnd.github+json','Content-Type':'application/json',
            'X-GitHub-Api-Version':'2026-03-10'})
    with urllib.request.urlopen(req,timeout=30) as response: return json.load(response)

def check_destination():
    repo=request('/repos/' + PRIVATE)
    if repo['private'] is not True or repo['full_name'] != PRIVATE:
        raise ValueError('Signed files may only go to the existing private repository.')
    original=request('/repos/' + PRIVATE + '/commits/main')['sha']
    expected=json.loads((Path(__file__).parent/'identity.json').read_text())['validatedSourceCommit']
    if original != expected:
        raise ValueError('Original source changed; review the private delivery target before continuing.')
    return original

def preserve():
    original=check_destination()
    number=os.environ['BUILD_NUMBER']
    if not re.fullmatch(r'[1-9][0-9]*',number): raise ValueError('Invalid build number')
    temp=Path(os.environ['RUNNER_TEMP'])
    files=[temp/'untilpayday-ipa/UntilPayday.ipa',temp/'UntilPayday.xcarchive.tar.gz']
    if not all(p.is_file() and p.stat().st_size > 0 for p in files): raise ValueError('Missing verified delivery files')
    title='Payday Left App Store 1.0 (' + number + ')'
    previous=request('/repos/' + PRIVATE + '/releases?per_page=100')
    if any(r['name'] == title for r in previous):
        raise ValueError('Existing delivery with this build number; inspect before retrying.')
    body='Private signed delivery. Public source commit: ' + os.environ['GITHUB_SHA'] + '\n\n'
    for path in files:
        body+=path.name + ' SHA256 ' + hashlib.sha256(path.read_bytes()).hexdigest() + '\n'
    release=request('/repos/' + PRIVATE + '/releases', {'name':title,
        'tag_name':'untilpayday-store-1.0-' + number,'target_commitish':original,
        'draft':True,'prerelease':False,'body':body})
    if release['draft'] is not True: raise ValueError('Delivery must remain an unpublished draft')
    for path in files:
        check_destination()
        url='https://uploads.github.com/repos/' + PRIVATE + '/releases/' + str(release['id']) + '/assets?name=' + path.name
        req=urllib.request.Request(url,method='POST',data=path.read_bytes(),headers={
            'Authorization':'Bearer ' + os.environ['UNTILPAYDAY_PRIVATE_DELIVERY_TOKEN'],
            'Content-Type':'application/octet-stream','Accept':'application/vnd.github+json',
            'X-GitHub-Api-Version':'2026-03-10'})
        with urllib.request.urlopen(req,timeout=120) as response: asset=json.load(response)
        if asset['size'] != path.stat().st_size or asset['state'] != 'uploaded':
            raise ValueError('Private artifact upload incomplete')
        digest=asset.get('digest')
        if digest and digest != 'sha256:' + hashlib.sha256(path.read_bytes()).hexdigest():
            raise ValueError('Private artifact digest mismatch')
    check_destination()
    print('Verified IPA and original xcarchive retained in an unpublished private draft Release.')

if __name__ == '__main__':
    import argparse
    p=argparse.ArgumentParser();p.add_argument('mode',choices=('check','preserve'));args=p.parse_args()
    try:
        check_destination() if args.mode == 'check' else preserve()
    except Exception:
        raise SystemExit('Private delivery retention failed. Do not upload signed files as public artifacts.')
