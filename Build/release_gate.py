"""Require an owner-dispatched successful unsigned run for this exact commit."""
import json
import os
import re
import urllib.request

NEW = 'baewumnote-studio/untilpayday-ios-public-build'

def github(path):
    request = urllib.request.Request('https://api.github.com' + path,
        headers={'Authorization': 'Bearer ' + os.environ['GH_TOKEN'],
                 'Accept': 'application/vnd.github+json', 'X-GitHub-Api-Version': '2026-03-10'})
    with urllib.request.urlopen(request, timeout=30) as response:
        return json.load(response)

def main():
    if (os.environ.get('GITHUB_REPOSITORY') != NEW or
            os.environ.get('GITHUB_REF') != 'refs/heads/main' or
            os.environ.get('GITHUB_ACTOR') != 'baewumnote-studio' or
            os.environ.get('GITHUB_EVENT_NAME') != 'workflow_dispatch'):
        raise ValueError('Only an owner-dispatched main-branch release is allowed.')
    for field in ('BUILD_NUMBER', 'VERIFIED_RUN_ID', 'UNTILPAYDAY_ASC_APP_ID'):
        if not re.fullmatch(r'[1-9][0-9]*', os.environ.get(field, '')):
            raise ValueError('Positive build, verification-run and App Store app IDs are required.')
    if github('/repos/' + NEW)['private'] is not False:
        raise ValueError('Do not consume private-repository Mac minutes.')
    run = github('/repos/' + NEW + '/actions/runs/' + os.environ['VERIFIED_RUN_ID'])
    if (run.get('conclusion') != 'success' or run.get('status') != 'completed' or
            run.get('head_sha') != os.environ['GITHUB_SHA'] or
            run.get('head_branch') != 'main' or run.get('event') != 'workflow_dispatch' or
            run.get('path') != '.github/workflows/ios-build.yml' or
            run.get('actor', {}).get('login') != 'baewumnote-studio'):
        raise ValueError('A successful original unsigned workflow for this exact commit is required.')
    print('Trusted unsigned verification for this exact release commit passed.')

if __name__ == '__main__':
    try: main()
    except Exception:
        raise SystemExit('Release gate failed; verify the app ID and successful unsigned run. No credentials are logged.')
