#!/usr/bin/env python3
import argparse, json, pathlib, re, sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
CATALOG = ROOT / 'AppSources/UntilPayday/Resources/Localizable.xcstrings'
SOURCE_DIRS = [ROOT / 'AppSources/UntilPayday', ROOT / 'AppSources/UntilPaydayWidget']

PATTERNS = [
    re.compile(r'\b(?:Text|Button|Label|Section|NavigationLink|Picker|LabeledContent|ContentUnavailableView)\(\s*"((?:\\.|[^"\\])*)"'),
    re.compile(r'\bString\(localized:\s*"((?:\\.|[^"\\])*)"'),
    re.compile(r'\.accessibilityLabel\(\s*"((?:\\.|[^"\\])*)"'),
]


def unescape_swift(s: str) -> str:
    # Keep interpolation syntax verbatim; decode only common escaped quote/backslash/newline.
    return s.replace('\\"', '"').replace('\\n', '\n').replace('\\\\', '\\')


def extract_keys() -> set[str]:
    keys: set[str] = set()
    for base in SOURCE_DIRS:
        for path in base.rglob('*.swift'):
            text = path.read_text(encoding='utf-8')
            for pattern in PATTERNS:
                for match in pattern.finditer(text):
                    value = unescape_swift(match.group(1)).strip()
                    if value:
                        keys.add(value)
    return keys


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()

    catalog = json.loads(CATALOG.read_text(encoding='utf-8'))
    strings = catalog.setdefault('strings', {})
    source_keys = extract_keys()
    missing = sorted(source_keys - set(strings))

    if args.check:
        if missing:
            print('Missing localization keys:', file=sys.stderr)
            for key in missing:
                print(f'  {key}', file=sys.stderr)
            return 1
        print(f'Localization coverage OK ({len(source_keys)} extracted source keys; {len(strings)} catalog keys)')
        return 0

    for key in missing:
        strings[key] = {}

    catalog['strings'] = dict(sorted(strings.items(), key=lambda item: item[0].casefold()))
    CATALOG.write_text(json.dumps(catalog, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print(f'Added {len(missing)} localization keys; catalog now has {len(strings)} keys')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
