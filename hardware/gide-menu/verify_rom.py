#!/usr/bin/env python3
"""Verify the ROM build's relocation with an independent third origin."""
import hashlib
import json
from build import assemble, BUILD


def main():
    source = (BUILD / 'stage1.asm').read_text()
    assert source.count('BOOT_ORIGIN: EQU 32768') == 1
    third, _ = assemble(source.replace('BOOT_ORIGIN: EQU 32768', 'BOOT_ORIGIN: EQU 36864'), 'stage1-relocation-check')
    tape = (BUILD / 'stage1.bin').read_bytes()
    rom = (BUILD / 'stage1-rom.bin').read_bytes()
    assert len(tape) == len(third) == len(rom) <= 2048
    offsets = [i-1 for i, (a, b) in enumerate(zip(tape, third)) if a != b]
    expected = bytearray(tape)
    for at in offsets:
        assert at >= 0
        address = int.from_bytes(tape[at:at+2], 'little')
        assert 0x8000 <= address < 0x8000+len(tape)
        assert int.from_bytes(third[at:at+2], 'little') == address+0x1000
        expected[at:at+2] = (address+0x6800).to_bytes(2, 'little')
    assert bytes(expected) == rom
    image = (BUILD / 'GIDE-BOOT.rom.bin').read_bytes()
    assert image == rom.ljust(2048, b'\xff')
    ram = json.loads((BUILD / 'stage1-ram.json').read_text())
    assert all(0x6000 <= address < 0x6200 for address in ram.values())
    report = {'passed': True, 'code_bytes': len(rom), 'image_bytes': len(image),
              'origin': 'E800h', 'relocated_words_verified': len(offsets),
              'ram_state': '6000h..61FFh', 'sha256': hashlib.sha256(image).hexdigest(),
              'scope': 'Relocation and ROM-friendly memory layout; hardware autostart is not integrated'}
    (BUILD / 'rom-verification.json').write_text(json.dumps(report, indent=2)+'\n')
    print(json.dumps(report, indent=2))


if __name__ == '__main__': main()
