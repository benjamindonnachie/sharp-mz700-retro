#!/usr/bin/env python3
"""Build a small software-only card image without the private game library."""
from pathlib import Path
import argparse
import hashlib
import importlib.util
import json
import struct
import sys

ROOT = Path(__file__).resolve().parents[1]
B = ROOT / 'hardware/gide-monitor/build'
spec = importlib.util.spec_from_file_location('fat', ROOT / 'hardware/gide-menu/fat32.py')
fat = importlib.util.module_from_spec(spec)
spec.loader.exec_module(fat)


def slot(payload, kind, load):
    assert 0 < len(payload) <= (4096 if kind == 1 else 8192)
    padded = payload + bytes((-len(payload)) % 512)
    header = bytearray(512)
    header[:8] = b'GIDEMN01'
    struct.pack_into('<HHHHBB', header, 8, len(payload), load, load,
                     sum(padded) & 65535, len(padded) // 512, kind)
    return header + padded


def mzf(name, payload, load=0x1000):
    header = bytearray(128)
    header[0] = 1
    header[1:18] = (name.encode()[:16] + b'\r').ljust(17, b'\r')
    struct.pack_into('<HHH', header, 18, len(payload), load, load)
    return header + payload


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--rom', action='store_true')
    args = parser.parse_args()
    menu_build = ROOT / 'hardware/gide-menu/build'
    native = (ROOT / 'cpm/mz700-40/build-mbr/gide-cpm3-mz700-40-mbr.img').read_bytes()
    assert len(native) == 34833 * 512
    prefix = bytearray(native)
    prefix.extend(bytes(fat.START * 512 - len(prefix)))
    prefix[:512] = (ROOT / 'reference/card-mbr.bin').read_bytes()
    files = {
        'MENU.MZF': ((B / 'SHADOW-MENU.MZF') if args.rom else menu_build / 'MENU.MZF').read_bytes(),
        'CPM3.MZF': (ROOT / 'cpm/mz700-40/build-mbr/CPM3-MBR-ID.MZT').read_bytes(),
        'GIDEBW.MZF': (ROOT / 'hardware/gide-basic/build/GIDEBW.MZF').read_bytes(),
        'GIDETST.MZF': (ROOT / 'hardware/gide-diagnostic/build/GIDETEST.mzf').read_bytes(),
        'HELLO.MZF': mzf('GIDE HELLO', bytes.fromhex('3e5a32ff90c30000'), 0x9000),
        'README.TXT': (ROOT / 'docs/CARD.txt').read_bytes().replace(b'\n', b'\r\n'),
    }
    if args.rom:
        files['MONITOR.MZF'] = mzf('RAM MONITOR', bytes.fromhex('c30000'))
        files['TAPE.MZF'] = mzf('LOAD FROM TAPE', bytes.fromhex('c31101'))
        files['SAVE.MZF'] = mzf('SAVE MEMORY TO IDE', bytes.fromhex('afd3e23e02cd9d0dda0000e9'))
        for lba, payload in (
                (0x8900, slot((B / 'shadow-bootstrap.bin').read_bytes(), 1, 0x8000)),
                (0x8920, slot((B / 'save-service.bin').read_bytes(), 2, 0xd000)),
                (0x8941, (B / 'RAMMON.BIN').read_bytes())):
            assert not any(prefix[lba * 512:lba * 512 + len(payload)])
            prefix[lba * 512:lba * 512 + len(payload)] = payload
    volume = fat.Volume()
    for directory in ('SAVES', 'BASIC', 'GAMES', 'PCG'):
        volume.mkdir(directory)
    for name, payload in files.items():
        volume.add(name, payload)
    raw_fat = volume.image()
    assert fat.inspect(raw_fat) == files
    image = prefix + raw_fat
    assert image[2048 * 512:34833 * 512] == native[2048 * 512:34833 * 512]
    target = B / 'gide-rom-card.img' if args.rom else menu_build / 'gide-mz700-cpm-fat32.img'
    target.write_bytes(image)
    target.with_suffix('.json').write_text(json.dumps({
        'bytes': len(image), 'sha256': hashlib.sha256(image).hexdigest(),
        'boot_mode': 'ROM' if args.rom else 'tape',
        'cpm_filesystem': 'native fixed C/D volumes; not FAT32',
        'files': {name: hashlib.sha256(data).hexdigest() for name, data in files.items()},
    }, indent=2) + '\n')
    print(target)


if __name__ == '__main__':
    main()
