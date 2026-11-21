#!/usr/bin/env python3
"""Build a standard 128-byte-header MZT using the preserved pyz80 assembler."""
from pathlib import Path
import hashlib
import json
import subprocess
import sys

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
OUT = HERE / 'build'


def main():
    OUT.mkdir(exist_ok=True)
    assembler = ROOT / 'cpm/gide/third_party/pyz80.py'
    subprocess.run([sys.executable, str(assembler),
                    '--obj=' + str(OUT / 'GIDETEST.bin'),
                    '--mapfile=' + str(OUT / 'GIDETEST.map'),
                    '--lstfile=' + str(OUT / 'GIDETEST.lst'),
                    str(HERE / 'gidetest.asm')], check=True, cwd=HERE)
    body = (OUT / 'GIDETEST.bin').read_bytes()
    symbols = {name: int(addr, 16) for addr, name in
               (line.split('=', 1) for line in (OUT / 'GIDETEST.map').read_text().splitlines())}
    assert symbols['start'] == 0x1200
    assert symbols['program_end'] <= 0xcfff
    assert len(body) == symbols['program_end'] - 0x1200 + 1
    header = bytearray(128)
    header[0] = 1
    header[1:1+len(b'GIDE TEST 1.2\r')] = b'GIDE TEST 1.2\r'
    header[0x12:0x14] = len(body).to_bytes(2, 'little')
    header[0x14:0x16] = (0x1200).to_bytes(2, 'little')
    header[0x16:0x18] = (0x1200).to_bytes(2, 'little')
    (OUT / 'GIDETEST.mzt').write_bytes(header + body)
    # MZF and MZT use the same single-file header/body representation here.
    (OUT / 'GIDETEST.mzf').write_bytes(header + body)
    report = {'version': '1.2', 'load': 0x1200, 'exec': 0x1200, 'base': 0x20,
              'body_bytes': len(body), 'end_exclusive': 0x1200 + len(body),
              'sha256': hashlib.sha256(header + body).hexdigest(),
              'assembler': 'preserved pyz80 1.3.0 in cpm/gide/third_party',
              'source_sha256': hashlib.sha256((HERE / 'gidetest.asm').read_bytes()).hexdigest()}
    (OUT / 'build.json').write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps(report, indent=2))


if __name__ == '__main__':
    main()
