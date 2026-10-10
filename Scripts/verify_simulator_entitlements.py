#!/usr/bin/env python3
"""Read the actual Simulator Mach-O entitlements embedded by Xcode's linker."""
import argparse
from pathlib import Path
import plistlib
import struct

parser = argparse.ArgumentParser()
parser.add_argument('--app', required=True, type=Path)
parser.add_argument('--output', required=True, type=Path)
args = parser.parse_args()
expected = (args.output / 'app-group-app.txt').read_text().strip()

def extract(bundle: Path):
    info = plistlib.loads((bundle / 'Info.plist').read_bytes())
    binary = (bundle / info['CFBundleExecutable']).read_bytes()
    if len(binary) < 32 or binary[:4] != b'\xcf\xfa\xed\xfe':
        raise SystemExit(f'{bundle}: expected the built arm64 little-endian Mach-O 64 executable')
    commands = struct.unpack_from('<I', binary, 16)[0]
    offset = 32
    for _ in range(commands):
        command, size = struct.unpack_from('<II', binary, offset)
        if size < 8 or offset + size > len(binary):
            raise SystemExit(f'{bundle}: invalid Mach-O load command')
        if command == 0x19:  # LC_SEGMENT_64, section_64 entries
            sections = struct.unpack_from('<I', binary, offset + 64)[0]
            for index in range(sections):
                section = offset + 72 + index * 80
                if section + 80 > offset + size:
                    raise SystemExit(f'{bundle}: invalid Mach-O section table')
                name = binary[section:section+16].rstrip(b'\0')
                segment = binary[section+16:section+32].rstrip(b'\0')
                if (segment, name) == (b'__TEXT', b'__entitlements'):
                    length = struct.unpack_from('<Q', binary, section + 40)[0]
                    position = struct.unpack_from('<I', binary, section + 48)[0]
                    if position + length > len(binary):
                        raise SystemExit(f'{bundle}: embedded entitlement section out of range')
                    return plistlib.loads(binary[position:position+length].rstrip(b'\0'))
        offset += size
    raise SystemExit(f'{bundle}: no __TEXT,__entitlements section in built executable')

for name, bundle in [('app', args.app), ('widget', args.app / 'PlugIns/UntilPaydayWidget.appex')]:
    entitlements = extract(bundle)
    (args.output / f'{name}-simulator-entitlements.plist').write_bytes(plistlib.dumps(entitlements))
    if entitlements.get('com.apple.security.application-groups') != [expected]:
        raise SystemExit(f'{name}: actual embedded Simulator App Group entitlement mismatch')
print('Actual app and widget Simulator Mach-O App Group entitlements match: ' + expected)
