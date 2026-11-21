#!/usr/bin/env python3
"""Build the SD-resident TUI and the small tape/ROM first stage."""
from pathlib import Path
import hashlib
import json
import re
import subprocess
import sys

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
BUILD = HERE / 'build'
CPM = ROOT / 'cpm/mz700-40/build-mbr'
ASM = ROOT / 'cpm/gide/third_party/pyz80.py'


def assemble(source, stem):
    source_path = BUILD / (stem+'.asm'); source_path.write_text(source)
    subprocess.run([sys.executable, str(ASM), '--obj='+str(BUILD / (stem+'.bin')),
                    '--mapfile='+str(BUILD / (stem+'.map')), str(source_path)], check=True)
    sy = {n: int(a, 16) for a, n in (line.split('=', 1) for line in (BUILD / (stem+'.map')).read_text().splitlines())}
    return (BUILD / (stem+'.bin')).read_bytes(), sy


def db(data):
    return ''.join('        DB '+','.join(str(b) for b in data[n:n+16])+'\n' for n in range(0, len(data), 16))


def assemble_compact(source, stem):
    """Use relative branches wherever their final displacement is bounded."""
    candidates = []
    pattern = re.compile(r'(?m)^([ \t]*)JP[ \t]+(?:(NZ|Z|NC|C),)?([A-Za-z_]\w*)[ \t]*(;[^\n]*)?$')
    def mark(match):
        label = '__jump_'+str(len(candidates))
        candidates.append((label, match[3], match[0]))
        return label+':\n'+match[0]
    source = pattern.sub(mark, source)
    _, sy = assemble(source, stem+'-sizing')
    for label, target, line in candidates:
        if target in sy and -126 <= sy[target]-sy[label]-2 <= 126:
            source = source.replace(label+':\n'+line, label+':\n'+line.replace('JP', 'JR', 1))
    return assemble(source, stem)


def main():
    BUILD.mkdir(exist_ok=True)
    trampoline, ts = assemble((HERE / 'trampoline.asm').read_text(), 'trampoline')
    definitions = (f'TRAMP_SIZE: EQU {len(trampoline)}\n'
                   f'TRAMP_DEST: EQU {ts["dest_instruction"]+1}\n'
                   f'TRAMP_COUNT: EQU {ts["count_instruction"]+1}\n'
                   f'TRAMP_EXEC: EQU {ts["exec_instruction"]+1}\n')
    menu_source = (HERE / 'menu.asm').read_text()
    assert menu_source.count('; TUI_INCLUDE\n') == 1
    menu_source = menu_source.replace('; TUI_INCLUDE\n', (HERE / 'tui.asm').read_text()+(HERE / 'titles.asm').read_text())
    manager, sy = assemble(definitions+menu_source+db(trampoline)+'program_end: DB 0\n', 'menu')
    assert sy['start'] == 0x1000 and sy['program_end'] < 0x2a00, (len(manager), hex(sy['program_end']))
    menu_header = bytearray(128)
    menu_header[0] = 1
    menu_header[1:18] = b'GIDE SD MENU\r'.ljust(17, b'\r')
    menu_header[18:20] = len(manager).to_bytes(2, 'little')
    menu_header[20:24] = bytes.fromhex('00100010')
    menu_file = BUILD / 'MENU.MZF'
    menu_file.write_bytes(menu_header+manager)
    # Share the exact validated FAT32/IDE algorithms with the SD menu, but
    # omit its browser, rendering, 48KiB trampoline and diagnostic payload.
    state_source = menu_source.split('partition_start: DEFS 4', 1)[1].split('trampoline_bytes:', 1)[0]
    state_source = 'partition_start: DEFS 4'+state_source
    ram, offset = [], 0
    for line in state_source.splitlines():
        match = re.fullmatch(r'(\w+): (DEFS (\d+)|DW 0|DB 0)', line.strip())
        if not match: continue
        name, kind, size = match.groups()
        ram.append(f'{name}: EQU {0x6000+offset}\n')
        offset += int(size) if size else (2 if kind == 'DW 0' else 1)
    assert offset <= 0x1f0
    # Keep the first-stage RAM contract independent of future TUI fields.
    offset = 0x1f0
    for name, size in (('saved_task', 4), ('reg_result', 1), ('init_attempts', 1)):
        ram.append(f'{name}: EQU {0x6000+offset}\n'); offset += size
    offset = 512
    state_defs = ''.join(ram)+f'STATE_BYTES: EQU {offset}\nBASE: EQU 32\nBUF: EQU 28672\nSEEN: EQU 11776\n'
    ram_symbols = {line.split(':', 1)[0]: int(line.split('EQU', 1)[1]) for line in ram}
    (BUILD / 'stage1-ram.json').write_text(json.dumps(ram_symbols, indent=2)+'\n')
    mount_code = menu_source[menu_source.index('mount:\n'):menu_source.index('fat_selected:\n')]
    mount_code = mount_code.replace('LD SP,0x2BF0', 'LD SP,0x7F00')
    common = menu_source[menu_source.index('selected_cluster:\n'):menu_source.index('; ---------- monitor console')]
    common = common.split('table_address:\n')[0]
    console = menu_source[menu_source.index('\nputc:\n')+1:menu_source.index('\nprint_name:\n')+1]
    diag = (ROOT / 'hardware/gide-diagnostic/gidetest.asm').read_text()
    register_test = diag[diag.index('register_test:\n'):diag.index('read_sector:\n')]
    first_stage = ((HERE / 'stage1.asm').read_text()+mount_code+
                   (HERE / 'stage1-file.asm').read_text()+register_test+common+console+'program_end: DB 0\n')
    boot, bs = assemble_compact('BOOT_ORIGIN: EQU 32768\n'+state_defs+first_stage, 'stage1')
    rom, rs = assemble_compact('BOOT_ORIGIN: EQU 59392\n'+state_defs+first_stage, 'stage1-rom')
    assert rs['program_end'] < 0x10000
    assert len(boot) <= 2048 and len(rom) <= 2048, 'First stage exceeds the 2 KiB ROM budget'
    (BUILD / 'GIDE-BOOT.rom.bin').write_bytes(rom.ljust(2048, b'\xff'))
    header = bytearray(menu_header)
    header[1:18] = b'GIDE SD BOOT\r'.ljust(17, b'\r')
    header[18:20] = len(boot).to_bytes(2, 'little')
    header[20:24] = bytes.fromhex('00800080')
    target = BUILD / 'GIDE-BOOT.MZT'; target.write_bytes(header+boot)
    result = {'mzt_sha256': hashlib.sha256(target.read_bytes()).hexdigest(),
              'payload_bytes': len(boot), 'manager_bytes': len(manager),
              'manager_start': 0x1000, 'manager_end': sy['program_end'],
              'menu_mzf_sha256': hashlib.sha256(menu_file.read_bytes()).hexdigest(),
              'ram_state_start': 0x6000, 'ram_state_bytes': offset,
              'rom_origin': 0xe800, 'rom_bytes': 2048,
              'filesystem': 'FAT32', 'initial_read': 'Validated MBR at physical LBA 0',
              'storage_writes': False, 'maximum_payload': 49152,
              'ui': 'Alphabetical folders first; two columns; cursor keys, Return, Delete and Space'}
    (BUILD / 'build.json').write_text(json.dumps(result, indent=2)+'\n')
    print(json.dumps(result, indent=2))


if __name__ == '__main__': main()
