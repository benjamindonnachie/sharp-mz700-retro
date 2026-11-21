#!/usr/bin/env python3
"""Prepare the fixed-partition CP/M image and its matching tape bootstrap."""
from pathlib import Path
import gzip
import hashlib
import json
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
B = ROOT / 'cpm/mz700-40/build-mbr'


def main():
    B.mkdir(parents=True, exist_ok=True)
    data = bytearray(gzip.decompress((ROOT / 'reference/cpm-fixed-partition.bin.gz').read_bytes()))
    pinned = json.loads((ROOT / 'reference/cpm-fixed-partition.json').read_text())
    assert len(data) == pinned['bytes']
    assert hashlib.sha256(data).hexdigest() == pinned['sha256']
    sys.path.insert(0, str(ROOT / 'cpm/gide/tools'))
    from media import hard_volume
    drive = hard_volume(bytearray(data[:8388608]))
    drive.write('CPM3.SYS', (B / 'cpm3.sys').read_bytes())
    drive.write('CCP.COM', (B / 'ccp.com').read_bytes())
    data[:8388608] = drive.data
    loader = (B / 'cpmldr.com').read_bytes()
    padded = loader.ljust((len(loader) + 511) // 512 * 512, b'\0')
    assert len(padded) == 8192, 'The fixed boot slot holds sixteen sectors'
    data[32768 * 512:32769 * 512] = b'GIDE40!!' + bytes(504)
    data[32769 * 512:] = padded
    mbr = bytearray((ROOT / 'reference/card-mbr.bin').read_bytes())
    mbr[446:462] = mbr[462:478]
    mbr[462:510] = bytes(48)
    image = bytearray(2048 * 512) + data
    image[:512] = mbr
    image_path = B / 'gide-cpm3-mz700-40-mbr.img'
    image_path.write_bytes(image)
    driver = int(re.search(r'(?i)([0-9a-f]{4})\s+DRIVER', (B / 'cpmldr.sym').read_text())[1], 16)
    body = (ROOT / 'cpm/mz700-40/bootstrap-diagnostic.asm').read_text()
    assert body.count('LD DE,32768') == 1
    body = body.replace('LD DE,32768', 'LD DE,34816')
    source = (f'LOADER_DRIVER: EQU {driver}\nLOADER_LBA: EQU 34817\n'
              f'LOADER_SECTORS: EQU 16\nLOADER_SUM: EQU {sum(padded) & 65535}\n' + body)
    (B / 'stage.asm').write_text(source)
    subprocess.run([sys.executable, str(ROOT / 'cpm/gide/third_party/pyz80.py'),
                    '--obj=' + str(B / 'stage.bin'), '--mapfile=' + str(B / 'stage.map'),
                    str(B / 'stage.asm')], check=True)
    payload = (B / 'stage.bin').read_bytes()
    header = bytearray(128)
    header[0] = 1
    header[1:18] = b'CPM3 GIDE20' + b'\r' * 6
    header[18:20] = len(payload).to_bytes(2, 'little')
    header[20:24] = bytes.fromhex('00800080')
    (B / 'CPM3-MBR.MZT').write_bytes(header + payload)
    report = json.loads((B / 'build.json').read_text())
    report['boot'] = {'header_lba': 34816, 'loader_lba': 34817,
                      'checksum': sum(padded) & 65535, 'sectors': 16}
    report.setdefault('files', {})[image_path.name] = {
        'bytes': len(image), 'sha256': hashlib.sha256(image).hexdigest()}
    (B / 'build.json').write_text(json.dumps(report, indent=2) + '\n')


if __name__ == '__main__':
    main()
