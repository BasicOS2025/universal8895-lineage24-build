#!/usr/bin/env python3
import hashlib
from pathlib import Path
import shutil
import sys
import zipfile

product, output = map(Path, sys.argv[1:])
packages = sorted(product.glob('lineage-24*.zip'), key=lambda p: p.stat().st_mtime)
if not packages:
    raise SystemExit('No LineageOS 24 ROM package was produced')
package = packages[-1]
with zipfile.ZipFile(package) as archive:
    if archive.testzip() is not None:
        raise SystemExit('ROM archive CRC validation failed')
    if archive.read('boot.img')[:8] != b'ANDROID!':
        raise SystemExit('Missing or invalid Android boot image')
    metadata = archive.read('META-INF/com/android/metadata').decode()
    expected = product.name
    if not any(line.startswith('pre-device=') and expected in line.split('=', 1)[1].split(',') for line in metadata.splitlines()):
        raise SystemExit('ROM target device metadata mismatch')
output.mkdir(parents=True, exist_ok=True)
shutil.copy2(package, output)
hasher = hashlib.sha256()
with package.open('rb') as stream:
    for chunk in iter(lambda: stream.read(1024 * 1024), b''):
        hasher.update(chunk)
digest = hasher.hexdigest()
checksums = output / 'SHA256SUMS'
entries = {}
if checksums.exists():
    for line in checksums.read_text().splitlines():
        old_digest, old_name = line.split('  ', 1)
        entries[old_name] = old_digest
entries[package.name] = digest
checksums.write_text(''.join(f'{entries[name]}  {name}\n' for name in sorted(entries)))
print('Validated ROM archive:', package.name)
