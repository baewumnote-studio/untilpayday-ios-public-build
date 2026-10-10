#!/usr/bin/env python3
"""Independently parse the generated project and compare it to the ZIP's map."""
import json
import pathlib
import sys
import xml.etree.ElementTree as ET

import yaml

root = pathlib.Path(__file__).resolve().parents[1]
# Local validation dependency; macOS CI installs the same package in its venv.
local_tools = root / 'AssemblyVerification/tools'
if local_tools.is_dir():
    sys.path.insert(0, str(local_tools))
from openstep_parser import OpenStepDecoder

with (root / 'UntilPayday.xcodeproj/project.pbxproj').open(encoding='utf-8') as project_file:
    project = OpenStepDecoder.ParseFromFile(project_file)
objects = project['objects']
spec = yaml.safe_load((root / 'project.yml').read_text(encoding='utf-8'))
native_targets = {obj['name']: (identifier, obj) for identifier, obj in objects.items()
                  if obj['isa'] == 'PBXNativeTarget'}
assert set(native_targets) == set(spec['targets']), 'Target names differ from project.yml'
project_object = objects[project['rootObject']]
paths = {}

def walk_group(identifier, parent=pathlib.PurePosixPath()):
    obj = objects[identifier]
    path = parent / obj.get('path', '')
    if obj['isa'] == 'PBXGroup':
        for child in obj['children']:
            walk_group(child, path)
    elif obj.get('sourceTree') == '<group>':
        paths[identifier] = path.as_posix()

walk_group(project_object['mainGroup'])
packages = {objects[p].get('repositoryURL', objects[p].get('relativePath')): p
            for p in project_object['packageReferences']}
for name, package in spec['packages'].items():
    locator = package.get('url', package.get('path'))
    assert locator in packages, f'Missing SPM reference: {name}'
    actual = objects[packages[locator]]
    if 'url' in package:
        assert actual['requirement'] == {'kind': 'upToNextMajorVersion', 'minimumVersion': str(package['from'])}

summary = {}
for name, expected in spec['targets'].items():
    identifier, target = native_targets[name]
    phases = [objects[p] for p in target['buildPhases']]
    source_phase = next(p for p in phases if p['isa'] == 'PBXSourcesBuildPhase')
    resource_phase = next(p for p in phases if p['isa'] == 'PBXResourcesBuildPhase')
    actual_sources = {paths[objects[b]['fileRef']] for b in source_phase['files']}
    actual_resources = {paths[objects[b]['fileRef']] for b in resource_phase['files']}
    expected_sources = {p.relative_to(root).as_posix() for entry in expected['sources']
                        for p in (root / entry['path']).rglob('*.swift')}
    expected_resources = {p.relative_to(root).as_posix() for entry in expected['sources']
                          for suffix in ('*.xcprivacy', '*.xcstrings', '*.xcassets')
                          for p in (root / entry['path']).rglob(suffix)}
    assert actual_sources == expected_sources, f'{name}: source membership mismatch'
    assert actual_resources == expected_resources, f'{name}: resource membership mismatch'
    assert all((root / p).exists() for p in actual_sources | actual_resources)
    products = {objects[p]['productName'] for p in target['packageProductDependencies']}
    expected_products = {d.get('product', d.get('package')) for d in expected.get('dependencies', []) if 'package' in d}
    if name == 'UntilPaydayTests':
        expected_products.add('UntilPaydayCore')
    assert products == expected_products, f'{name}: package product links mismatch'
    framework_phase = next(p for p in phases if p['isa'] == 'PBXFrameworksBuildPhase')
    assert {objects[objects[b]['productRef']]['productName'] for b in framework_phase['files']} == products
    dependencies = {objects[objects[p]['target']]['name'] for p in target['dependencies']}
    assert dependencies == {d['target'] for d in expected.get('dependencies', []) if 'target' in d}
    for c in objects[target['buildConfigurationList']]['buildConfigurations']:
        settings = objects[c]['buildSettings']
        assert settings['IPHONEOS_DEPLOYMENT_TARGET'] == str(expected['deploymentTarget'])
        assert settings['SWIFT_VERSION'] == '6.0'
        for key, value in expected.get('settings', {}).get('base', {}).items():
            assert settings[key] == str(value), f'{name}: {key} mismatch'
        if 'info' in expected:
            assert settings['INFOPLIST_FILE'] == expected['info']['path']
        if 'entitlements' in expected:
            assert settings['CODE_SIGN_ENTITLEMENTS'] == expected['entitlements']['path']
    if 'entitlements' in expected:
        assert project_object['attributes']['TargetAttributes'][identifier]['SystemCapabilities']['com.apple.ApplicationGroups.iOS']['enabled'] == '1'
    summary[name] = {'Swift files': len(actual_sources), 'resources': len(actual_resources), 'packages': sorted(products)}

app = native_targets['UntilPayday'][1]
embed = next(objects[p] for p in app['buildPhases'] if objects[p]['isa'] == 'PBXCopyFilesBuildPhase')
assert embed['dstSubfolderSpec'] == '13'
assert len(embed['files']) == 1
embedded_product = objects[objects[embed['files'][0]]['fileRef']]
assert embedded_product['path'] == 'UntilPaydayWidget.appex'
scheme = ET.parse(root / 'UntilPayday.xcodeproj/xcshareddata/xcschemes/UntilPayday.xcscheme')
assert {t.find('BuildableReference').get('BlueprintName') for t in scheme.findall('./TestAction/Testables/TestableReference')} == {'UntilPaydayTests', 'UntilPaydayUITests'}
for reference in scheme.findall('.//BuildableReference'):
    assert reference.get('BlueprintIdentifier') == native_targets[reference.get('BlueprintName')][0]
ci = yaml.safe_load((root / '.github/workflows/ios-build.yml').read_text(encoding='utf-8'))
assert set(ci['on']) == {'workflow_dispatch'}, 'Only manual workflow dispatch is allowed'
assert ci['permissions'] == {'contents': 'read'}
assert ci['jobs']['preflight']['runs-on'] == 'ubuntu-24.04'
assert ci['jobs']['ios']['needs'] == 'preflight'
assert ci['jobs']['ios']['runs-on'] == 'xcode-27'
assert ci['jobs']['ios']['env']['DEVELOPER_DIR'] == '/Applications/Xcode_27.0.app/Contents/Developer'
assert 'secrets.' not in (root / '.github/workflows/ios-build.yml').read_text(encoding='utf-8')
print(json.dumps(summary, indent=2))
print('OpenStep project parse, target membership, SPM references, entitlements/capability wiring, widget embedding, shared test scheme and CI YAML OK.')
print('Apple SDK type-checking, SPM resolution and runtime behavior are NOT verified by this static check.')
