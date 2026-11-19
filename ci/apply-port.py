#!/usr/bin/env python3
"""Refresh pinned trees in place and configure the GCC-built kernel bridge."""
import json
import os
from pathlib import Path
import subprocess
import sys
import xml.etree.ElementTree as ET
control = Path(__file__).resolve().parents[1]
source = Path(sys.argv[1]).resolve()
for project in json.loads((control / 'sources.json').read_text()):
    if project['path'] in ('device/samsung/dream2lte', 'device/samsung/greatlte'):
        continue
    folder = source / project['path']
    current = subprocess.check_output(['git', '-C', str(folder), 'rev-parse', 'HEAD'], text=True).strip()
    if current != project['revision']:
        url = 'https://github.com/' + project.get('owner', 'BasicOS2025') + '/' + project['repository'] + '.git'
        subprocess.run(['git', '-C', str(folder), 'fetch', '--depth=1', url, project['revision']], check=True)
        subprocess.run(['git', '-C', str(folder), 'checkout', '--detach', '--force', project['revision']], check=True)
# Gradle supplies this namespace, but the platform manifest merger needs it
# explicitly in the source manifest when PhhIms is built by Soong.
ims_manifest = source / 'packages/apps/PhhIms/app/src/main/AndroidManifest.xml'
text = ims_manifest.read_text()
ims_package = ET.fromstring(text).get('package')
if ims_package is None:
    text = text.replace('<manifest ', '<manifest package="me.phh.ims" ', 1)
    if ET.fromstring(text).get('package') != 'me.phh.ims':
        raise ValueError('Could not set PhhIms manifest package')
    ims_manifest.write_text(text)
elif ims_package != 'me.phh.ims':
    raise ValueError('Unexpected PhhIms manifest package: ' + ims_package)

board = source / 'device/samsung/dreamlte/BoardConfig.mk'
text = board.read_text().split('# BEGIN CI GCC KERNEL BRIDGE')[0].rstrip()
text += "\n\n# BEGIN CI GCC KERNEL BRIDGE\n"
text += "TARGET_FORCE_PREBUILT_KERNEL := true\n"
text += "TARGET_PREBUILT_KERNEL := out/kernel-ci/arch/arm64/boot/Image\n"
text += "EXYNOS8895_DTB_DIR := $(abspath out/kernel-ci/arch/arm64/boot/dts/exynos)\n"
board.write_text(text)

# Keep Make image packaging on the legacy non-Treble system/vendor layout.
soong = source / 'build/soong'
patch = control / 'patches/soong-legacy-system-vendor.patch'
target = soong / 'fsgen/filesystem_creator.go'
text = target.read_text()
old = 'ctx.DeviceConfig().VendorPath() == "system/vendor"'
new = 'proptools.String(ctx.Config().ProductVariables().VendorPath) == "system/vendor"'
if 'Legacy non-Treble products are packaged by Make' in text and old in text:
    target.write_text(text.replace(old, new, 1))
reverse = subprocess.run(['git', '-C', str(soong), 'apply', '--reverse', '--check', str(patch)], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
if reverse.returncode != 0:
    subprocess.run(['git', '-C', str(soong), 'apply', '--check', str(patch)], check=True)
    subprocess.run(['git', '-C', str(soong), 'apply', str(patch)], check=True)
print('Applied legacy system/vendor Make packaging compatibility', flush=True)

# Respect a cloud-specific job count while keeping the free-runner default at one.
jobs = int(os.environ.get('BUILD_JOBS', '1'))
if not 1 <= jobs <= 32:
    raise ValueError('BUILD_JOBS must be between 1 and 32')
envsetup = source / 'build/envsetup.sh'
marker = '# CI single-job memory limit'
text = envsetup.read_text().split(marker)[0].rstrip()
envsetup.write_text(text + '\n\n' + marker + '\n' +
                   'export GOMAXPROCS=' + str(jobs) + '\n')
