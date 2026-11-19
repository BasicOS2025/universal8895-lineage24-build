#!/usr/bin/env python3
"""Refresh pinned trees in place and configure the GCC-built kernel bridge."""
import json
from pathlib import Path
import subprocess
import sys
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
board = source / 'device/samsung/dreamlte/BoardConfig.mk'
text = board.read_text().split('# BEGIN CI GCC KERNEL BRIDGE')[0].rstrip()
text += "\n\n# BEGIN CI GCC KERNEL BRIDGE\n"
text += "TARGET_FORCE_PREBUILT_KERNEL := true\n"
text += "TARGET_PREBUILT_KERNEL := out/kernel-ci/arch/arm64/boot/Image\n"
text += "EXYNOS8895_DTB_DIR := $(abspath out/kernel-ci/arch/arm64/boot/dts/exynos)\n"
board.write_text(text)
