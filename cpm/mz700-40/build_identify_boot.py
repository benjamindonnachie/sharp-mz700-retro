#!/usr/bin/env python3
"""Build an IDENTIFY-first tape bootstrap for the unchanged MBR image."""
from pathlib import Path
import hashlib
import json
import subprocess
import sys

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
BUILD = HERE / 'build-mbr'


def main():
    report = json.loads((BUILD / 'build.json').read_text())
    image = (BUILD / 'gide-cpm3-mz700-40-mbr.img').read_bytes()
    digest = hashlib.sha256(image).hexdigest()
    assert digest == report['files']['gide-cpm3-mz700-40-mbr.img']['sha256']
    assert image[0x8800*512:0x8800*512+8] == b'GIDE40!!'
    source = (BUILD / 'stage.asm').read_text()
    insertion = '        LDIR\n        OUT (0xE0),A'
    assert source.count(insertion) == 1
    source = source.replace(insertion, '        LDIR\n        CALL prime_identify\n        XOR A\n        OUT (0xE0),A')
    # GIDETEST leaves black attributes over the main screen. The CP/M
    # console deliberately preserves attributes, so establish white on blue
    # for all 40x25 cells immediately before initialising CPMLDR's console.
    handover = '        CALL LOADER_DRIVER\n'
    assert source.count(handover) == 1
    source = source.replace(handover, '''        XOR A
        OUT (0xE3),A
        LD HL,0xD800
        LD DE,0xD801
        LD BC,999
        LD (HL),0x71
        LDIR
        XOR A
        OUT (0xE1),A
        CALL LOADER_DRIVER
''')
    source += '\n' + (HERE / 'bootstrap-identify.asm').read_text()
    src = BUILD / 'stage-identify.asm'
    src.write_text(source)
    subprocess.run([sys.executable, str(ROOT / 'cpm/gide/third_party/pyz80.py'),
                    '--obj='+str(BUILD / 'stage-identify.bin'),
                    '--mapfile='+str(BUILD / 'stage-identify.map'), str(src)], check=True)
    body = (BUILD / 'stage-identify.bin').read_bytes()
    assert 0x8000+len(body) < 0xd000
    header = bytearray(128)
    header[0] = 1
    name = b'CPM3 MBR IDENT\r'
    header[1:1+len(name)] = name
    header[18:20] = len(body).to_bytes(2, 'little')
    header[20:24] = bytes.fromhex('00800080')
    target = BUILD / 'CPM3-MBR-ID.MZT'
    target.write_bytes(header+body)
    assert hashlib.sha256((BUILD / 'gide-cpm3-mz700-40-mbr.img').read_bytes()).hexdigest() == digest
    result = {'mzt_sha256': hashlib.sha256(target.read_bytes()).hexdigest(),
              'sd_image_sha256': digest, 'payload_bytes': len(body),
              'initial_command': 'IDENTIFY DEVICE (ECh)', 'identify_buffer': '7200h',
              'boot_header_lba': report['boot']['header_lba'],
              'loader_checksum': report['boot']['checksum'],
              'console_attributes': {'cells': 1000, 'value_hex': '71', 'foreground': 'white', 'background': 'blue'}}
    (BUILD / 'identify-build.json').write_text(json.dumps(result, indent=2)+'\n')
    print(json.dumps(result, indent=2))


if __name__ == '__main__':
    main()
