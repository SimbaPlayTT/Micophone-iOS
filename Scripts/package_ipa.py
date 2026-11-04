#!/usr/bin/env python3
"""Package only a real Xcode-built iOS device .app; never manufacture an executable."""
import argparse
import hashlib
import plistlib
import struct
import zipfile
from pathlib import Path


def package(archive, destination):
    app = archive / 'Products/Applications/Micophone-iOS.app'
    with (app / 'Info.plist').open('rb') as file:
        info = plistlib.load(file)
    executable = app / info['CFBundleExecutable']
    binary = executable.read_bytes()
    if info.get('CFBundleSupportedPlatforms') != ['iPhoneOS']:
        raise ValueError('Only an iPhoneOS device build can be packaged, not a simulator app.')
    if len(binary) < 32 or binary[:4] != b'\xcf\xfa\xed\xfe' or struct.unpack_from('<I', binary, 4)[0] != 0x0100000C:
        raise ValueError('Expected a real arm64 Mach-O executable from Xcode.')
    if (app / '_CodeSignature').exists() or (app / 'embedded.mobileprovision').exists():
        raise ValueError('Expected the unsigned archive produced by build_unsigned.sh.')
    destination.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(destination, 'w', zipfile.ZIP_DEFLATED) as output:
        for path in sorted(app.rglob('*')):
            if path.is_file():
                name = 'Payload/' + path.relative_to(app.parent).as_posix()
                entry = zipfile.ZipInfo.from_file(path, name)
                entry.create_system = 3
                entry.external_attr = (0o100755 if path == executable else 0o100644) << 16
                output.writestr(entry, path.read_bytes(), compress_type=zipfile.ZIP_DEFLATED)
    digest = hashlib.sha256(destination.read_bytes()).hexdigest()
    destination.with_suffix('.ipa.sha256').write_text(f'{digest}  {destination.name}\n')
    print(f'Created {destination}: UNSIGNED; must be signed before installation.')


if __name__ == '__main__':
    p = argparse.ArgumentParser()
    p.add_argument('archive', type=Path)
    p.add_argument('destination', type=Path)
    args = p.parse_args()
    package(args.archive, args.destination)
