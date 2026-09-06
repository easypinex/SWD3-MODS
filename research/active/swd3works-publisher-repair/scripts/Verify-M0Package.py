"""Reverse-extract the two-frame no-op M0 fixture, not a general ssmod reader."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import struct
import zstandard

p = argparse.ArgumentParser()
p.add_argument('package', type=Path)
p.add_argument('source', type=Path)
p.add_argument('output', type=Path)
a = p.parse_args()
raw = a.package.read_bytes()
assert raw[:4] == b'SMOD' and struct.unpack_from('<I', raw, 4)[0] == 4, 'Unknown archive format'
offsets = [m.start() for m in re.finditer(re.escape(bytes.fromhex('28b52ffd')), raw)]
assert len(offsets) == 2, 'M0 fixture must contain exactly two Zstandard frames'
frames = [zstandard.ZstdDecompressor().decompress(raw[offset:]) for offset in offsets]
names = ['studio_m0_fixture.ext', 'data/Main.lua']
assert frames[0] == (a.source / names[0]).read_bytes(), 'Metadata differs'
assert frames[1] == (a.source / names[1]).read_bytes(), 'Lua differs'
assert all(not line.strip() or line.lstrip().startswith('--') for line in frames[1].decode('utf-8-sig').splitlines()), 'Fixture is not a no-op'
a.output.mkdir(parents=True, exist_ok=False)
rows = []
for name, offset, data in zip(names, offsets, frames):
    target = a.output / name
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_bytes(data)
    rows.append(dict(name=name, offset=offset, size=len(data), sha256=hashlib.sha256(data).hexdigest().upper()))
report = dict(result='PASS', method='two-frame M0 reverse extraction and byte comparison', zstandard=zstandard.__version__,
              package_sha256=hashlib.sha256(raw).hexdigest().upper(), files=rows)
(a.output / 'verification.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
print(json.dumps(report))
