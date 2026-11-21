#!/usr/bin/env python3
"""Independently check both release images and the firmware/card contracts."""
from pathlib import Path
import gzip
import hashlib
import importlib.util
import json
import struct
import sys

ROOT = Path(__file__).resolve().parents[1]
R = ROOT / 'release'
spec = importlib.util.spec_from_file_location('fat', ROOT / 'hardware/gide-menu/fat32.py')
fat = importlib.util.module_from_spec(spec)
spec.loader.exec_module(fat)


def sha(data):
    return hashlib.sha256(data).hexdigest()


def header(data):
    assert len(data) >= 128 and data[0] == 1
    length, load, entry = struct.unpack_from('<HHH', data, 18)
    assert len(data) == length + 128
    return load, entry


def main():
    for line in (R / 'SHA256SUMS').read_text().splitlines():
        expected, name = line.split('  ', 1)
        assert sha((R / name).read_bytes()) == expected, name
    rom = (R / 'rom/MZ700-GIDE-MONITOR-4K.bin').read_bytes()
    assert len(rom) == 4096
    assert sha(rom) == 'aa1b259a501845a6394116f7d3e9610d5e8ff9ebf9045ef7d3dc96037266bcf7'
    assert (R / 'rom/MZ700-GIDE-MONITOR-W27C512-64K.bin').read_bytes() == rom * 16
    basic = (R / 'GIDEBW.MZF').read_bytes()
    assert sha(basic) == '1c6560cc005e33aa5bac82d12564128f84272ef3cb4ecc6130390dfcc45d97f2'
    header(basic)
    stock = (ROOT / 'reference/mz700-monitor-and-font.bin').read_bytes()[:4096]
    for address in (0, 3, 6, 9, 12, 15, 18, 21, 24, 27, 30, 33, 36, 39, 42, 45, 48, 51, 59, 62, 65, 68, 71):
        assert rom[address:address + 3] == stock[address:address + 3]
    manifest = json.loads((R / 'manifest.json').read_text())
    native_images = []
    for mode in ('rom', 'tape'):
        name = f'gide-{mode}-card.img.gz'
        image = gzip.decompress((R / name).read_bytes())
        assert len(image) == 85983232
        assert sha(image) == manifest['images'][name]['uncompressed_sha256']
        assert image[510:512] == b'\x55\xaa'
        entries = [(image[x + 4], *struct.unpack_from('<II', image, x + 8)) for x in (446, 462)]
        assert entries == [(12, 36864, 131072), (82, 2048, 32785)]
        assert image[0x8800 * 512:0x8800 * 512 + 8] == b'GIDE40!!'
        files = fat.inspect(image[fat.START * 512:])
        assert set(files) == ({'MENU.MZF', 'CPM3.MZF', 'GIDEBW.MZF', 'GIDETST.MZF', 'HELLO.MZF', 'README.TXT'}
                              | ({'MONITOR.MZF', 'SAVE.MZF', 'TAPE.MZF'} if mode == 'rom' else set()))
        assert files['MENU.MZF'] == (R / mode / 'MENU.MZF').read_bytes()
        assert header(files['MENU.MZF']) == (0x1000, 0x1000)
        assert files['GIDEBW.MZF'] == basic
        assert files['CPM3.MZF'] == (R / 'CPM3.MZF').read_bytes()
        native_images.append(image[2048 * 512:34833 * 512])
        if mode == 'rom':
            for lba, kind, load, payload in (
                    (0x8900, 1, 0x8000, (R / 'rom/shadow-bootstrap.bin').read_bytes()),
                    (0x8920, 2, 0xd000, (R / 'rom/save-service.bin').read_bytes())):
                raw = image[lba * 512:(lba + 1) * 512]
                assert raw[:8] == b'GIDEMN01'
                length, dest, entry, checksum, sectors, actual_kind = struct.unpack_from('<HHHHBB', raw, 8)
                assert (length, dest, entry, actual_kind) == (len(payload), load, load, kind)
                assert 0 < sectors <= (8 if kind == 1 else 16)
                padded = image[(lba + 1) * 512:(lba + 1 + sectors) * 512]
                assert padded[:length] == payload and sum(padded) & 65535 == checksum
            assert image[0x8941 * 512:0x8949 * 512] == (R / 'rom/RAMMON.BIN').read_bytes()
            assert not any(image[0x8a00 * 512:0x8a18 * 512])
        else:
            assert not any(image[0x8900 * 512:0x8a18 * 512])
    assert native_images[0] == native_images[1]
    sys.path.insert(0, str(ROOT / 'cpm/gide/tools'))
    from media import hard_volume
    for i, expected in enumerate(({'CPM3.SYS', 'CCP.COM', 'DIR.COM', 'PIP.COM', 'SHOW.COM'}, {'CC.COM', 'CC2.COM', 'CLINK.COM', 'HELLO.C'})):
        volume = hard_volume(bytearray(native_images[0][i * 8388608:(i + 1) * 8388608]))
        for name in expected:
            assert volume.read(name)
    print('PASS: release hashes, both FAT32 images, fixed CP/M volumes, ROM vectors, mirrored EPROM and raw bootstrap contracts')


if __name__ == '__main__':
    main()
