#!/usr/bin/env python3
"""Build the published GIDE software and both card variants."""
from pathlib import Path
import argparse
import subprocess
import sys
import shutil

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--rebuild-cpm', action='store_true',
                        help='Reassemble CP/M with the included native ZXCC toolchain')
    args = parser.parse_args()
    cpm_build = ROOT / 'cpm/mz700-40/build-mbr'
    cpm_build.mkdir(parents=True, exist_ok=True)
    for source in (ROOT / 'reference/cpm-build').iterdir():
        shutil.copyfile(source, cpm_build / source.name)
    steps = []
    if args.rebuild_cpm:
        steps.append(('cpm/mz700-40/build.py', '--mbr'))
    steps += [
        ('tools/prepare_cpm.py',),
        ('cpm/mz700-40/build_identify_boot.py',),
        ('hardware/gide-diagnostic/build.py',),
        ('hardware/gide-menu/build.py',),
        ('hardware/gide-basic/build.py',),
        ('tools/make_media.py',),
        ('hardware/gide-monitor/audit.py',),
        ('hardware/gide-monitor/build.py',),
        ('hardware/gide-monitor/build_save.py',),
        ('hardware/gide-monitor/build_shadow.py',),
        ('hardware/gide-monitor/prepare_w27c512.py',),
        ('tools/make_media.py', '--rom'),
        ('tools/package.py',),
        ('tests/validate_release.py',),
    ]
    for script, *options in steps:
        print('Building:', script, flush=True)
        subprocess.run([sys.executable, str(ROOT / script), *options], cwd=ROOT, check=True)


if __name__ == '__main__':
    main()
