#!/usr/bin/env python3
"""Feasible static checks; this deliberately does not claim Swift compilation."""
import hashlib
import json
import plistlib
import re
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
info = plistlib.loads((ROOT / 'Micophone-iOS/Info.plist').read_bytes())
assert info['UIBackgroundModes'] == ['audio']
assert info['NSMicrophoneUsageDescription'] and info['NSLocalNetworkUsageDescription']
assert 'NSBonjourServices' not in info
privacy = plistlib.loads((ROOT / 'Micophone-iOS/Resources/PrivacyInfo.xcprivacy').read_bytes())
assert privacy['NSPrivacyTracking'] is False
metadata = json.loads((ROOT / 'Upstream/UPSTREAM.json').read_text())
for filename, digest in metadata['sha256'].items():
    assert hashlib.sha256((ROOT / 'Upstream' / filename).read_bytes()).hexdigest() == digest, filename
assert metadata['commit'] == 'e7d977d3bf5fce6b8666a28f5602c45ab422b1ba'
pbx = (ROOT / 'Micophone-iOS.xcodeproj/project.pbxproj').read_text()
for path in (ROOT / 'Micophone-iOS').rglob('*.swift'):
    assert path.relative_to(ROOT).as_posix() in pbx, path
for path in (ROOT / 'Tests').rglob('*.swift'):
    assert path.relative_to(ROOT).as_posix() in pbx, path
for path in re.findall(r'"path" = "([^"]+)";', pbx):
    if path.endswith(('.app', '.xctest')): continue
    assert (ROOT / path).exists(), path
ET.parse(ROOT / 'Micophone-iOS.xcodeproj/xcshareddata/xcschemes/Micophone-iOS.xcscheme')
assert not list((ROOT / 'Micophone-iOS').rglob('*.entitlements')), 'No restricted entitlements are needed'
assert 'CODE_SIGNING_ALLOWED=NO' in (ROOT / 'Scripts/build_unsigned.sh').read_text()
print('Static project, permissions, resources, scheme and pinned-source checks passed. Swift compilation is a separate check.')
