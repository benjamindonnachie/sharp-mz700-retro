#!/usr/bin/env python3
"""Collect reproducible release artifacts and compressed software-only media."""
from pathlib import Path
import gzip
import hashlib
import json
import shutil

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'release'


def main():
    OUT.mkdir(exist_ok=True)
    files = {
        'rom/MZ700-GIDE-MONITOR-4K.bin': 'hardware/gide-monitor/build/MZ700-GIDE-MONITOR-4K.bin',
        'rom/MZ700-GIDE-MONITOR-W27C512-64K.bin': 'hardware/gide-monitor/build/MZ700-GIDE-MONITOR-W27C512-64K.bin',
        'rom/RAMMON.BIN': 'hardware/gide-monitor/build/RAMMON.BIN',
        'rom/shadow-bootstrap.bin': 'hardware/gide-monitor/build/shadow-bootstrap.bin',
        'rom/save-service.bin': 'hardware/gide-monitor/build/save-service.bin',
        'rom/MENU.MZF': 'hardware/gide-monitor/build/SHADOW-MENU.MZF',
        'tape/GIDE-BOOT.MZT': 'hardware/gide-menu/build/GIDE-BOOT.MZT',
        'tape/MENU.MZF': 'hardware/gide-menu/build/MENU.MZF',
        'GIDEBW.MZF': 'hardware/gide-basic/build/GIDEBW.MZF',
        'GIDETST.MZF': 'hardware/gide-diagnostic/build/GIDETEST.mzf',
        'CPM3.MZF': 'cpm/mz700-40/build-mbr/CPM3-MBR-ID.MZT',
    }
    for name, source in files.items():
        target = OUT / name
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(ROOT / source, target)
    images = {}
    for name, source in (
            ('gide-rom-card.img.gz', 'hardware/gide-monitor/build/gide-rom-card.img'),
            ('gide-tape-card.img.gz', 'hardware/gide-menu/build/gide-mz700-cpm-fat32.img')):
        data = (ROOT / source).read_bytes()
        with (OUT / name).open('wb') as f:
            with gzip.GzipFile(filename='', mode='wb', fileobj=f, mtime=0) as z:
                z.write(data)
        images[name] = {'uncompressed_bytes': len(data),
                       'uncompressed_sha256': hashlib.sha256(data).hexdigest()}
    # These hashes describe the exact historical binaries, independently of timestamps.
    manifest = {
        'version': '0.1.1', 'firmware_version': '0.1.0', 'publication_date': '2026-11-21',
        'rom_banner_date': '2026-11-18', 'gide_base': '20h',
        'cpm_filesystem': 'fixed native C/D volumes', 'cpm_fat32': 'in development',
        'images': images,
        'files': {str(p.relative_to(OUT)): hashlib.sha256(p.read_bytes()).hexdigest()
                  for p in sorted(OUT.rglob('*'))
                  if p.is_file() and p.name not in ('SHA256SUMS', 'manifest.json')},
    }
    (OUT / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
    (OUT / 'SHA256SUMS').write_text(''.join(
        f'{hashlib.sha256(p.read_bytes()).hexdigest()}  {p.relative_to(OUT)}\n'
        for p in sorted(OUT.rglob('*')) if p.is_file() and p.name != 'SHA256SUMS'))


if __name__ == '__main__':
    main()
