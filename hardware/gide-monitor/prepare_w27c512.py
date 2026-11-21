#!/usr/bin/env python3
"""Mirror the current, metadata-checked 4 KiB monitor into a W27C512."""
import hashlib
import json
from pathlib import Path

BUILD = Path(__file__).resolve().parent / 'build'


def main():
    source = BUILD / 'MZ700-GIDE-MONITOR-4K.bin'
    rom = source.read_bytes()
    metadata = json.loads((BUILD / 'build.json').read_text())
    assert len(rom) == 4096
    assert hashlib.sha256(rom).hexdigest() == metadata['monitor_sha256']
    target = BUILD / 'MZ700-GIDE-MONITOR-W27C512-64K.bin'
    target.write_bytes(rom * 16)
    actual = target.read_bytes()
    assert len(actual) == 65536
    assert all(actual[i:i + 4096] == rom for i in range(0, len(actual), 4096))
    report = {
        'device': 'W27C512@DIP28',
        'source': source.name,
        'source_sha256': metadata['monitor_sha256'],
        'version': metadata['version'],
        'build_date': metadata['build_date'],
        'image': target.name,
        'bytes': len(actual),
        'identical_4k_banks': 16,
        'sha256': hashlib.sha256(actual).hexdigest(),
    }
    (BUILD / 'w27c512-build.json').write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps(report, indent=2))


if __name__ == '__main__':
    main()
