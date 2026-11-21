#!/usr/bin/env python3
"""Link the tested FAT writer as a separate upper-RAM card service."""
from pathlib import Path
import importlib.util,json,re,sys
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1];BUILD=HERE/'build';BASIC=ROOT/'hardware/gide-basic'
s=importlib.util.spec_from_file_location('assembler',BASIC/'pack_driver.py');pk=importlib.util.module_from_spec(s);s.loader.exec_module(pk);pk.BUILD=BUILD

def main():
 old=json.loads((BASIC/'build/build.json').read_text());symbols=json.loads((BASIC/'build/symbols.json').read_text())
 reloc=[(old['workspaces']['persistent'],195,0xF000),(old['workspaces']['history'],256,0xF200),(old['workspaces']['context'],old['context_bytes']+old['post_boot_bytes'],0xF400),(0xE000,512,0xFA00)]
 ram={}
 for name,addr in symbols.items():
  for lo,size,dest in reloc:
   if lo<=addr<lo+size:ram[name]=dest+addr-lo;break
 for name in ('PLAN','SEEN','STACK_TOP','BUF'):ram.pop(name,None)
 defs='BASE: EQU 32\nBUF: EQU 0xF800\nPLAN: EQU 0xF200\nSEEN: EQU 0xF200\nSTACK_TOP: EQU 0xCFF0\nFREE_RETURN: EQU 0xF680\nNATIVE_HEADER: EQU 0xF600\nRAM_PUTC: EQU 0xD006\nRAM_GETKEY: EQU 0xD009\nRAM_GETLINE: EQU 0xD00C\n'+''.join(f'{n}: EQU {a}\n' for n,a in ram.items())
 menu=(ROOT/'hardware/gide-menu/menu.asm').read_text()
 common=menu[menu.index('selected_cluster:\n'):menu.index('; ---------- monitor console')].split('table_address:\n')[0]
 common=common.replace('selected_cluster:\n','selected_cluster:\n        CALL selected_cluster_unchecked\n        LD HL,cluster\n        JP validate_cluster\nselected_cluster_unchecked:\n',1).replace('        LD (cluster+2),HL\n        LD HL,cluster\n        JP validate_cluster','        LD (cluster+2),HL\n        RET',1)
 a=common.index('next_cluster:\n');z=common.index('        LD DE,cluster\n        CALL copy32',a)
 common=common[:a]+'''next_cluster:
        LD HL,cluster
        CALL fat_address_for
        LD DE,BUF
        ADD HL,DE
        CALL read_sector
'''+common[z:]
 a=common.index('read_try:\n');z=common.index('        LD HL,BUF\n',a)
 common=common[:a]+'''read_try:
        LD A,0x20
        CALL begin_write_transfer
        JP C,read_retry
'''+common[z:]
 common=common.replace('read_sector:\n','read_sector:\n        XOR A\n        LD (fat_cache_valid),A\n',1)
 driver=(BASIC/'driver.asm').read_text();driver=re.sub(r'(?m)^\s*ORG[^\n]*\n','',driver)
 a=driver.index('get_name:\n');z=driver.index('begin_directory:\n',a);driver=driver[:a]+'get_name:\n        JP io_error\n'+driver[z:]
 a=driver.index('get_header:\n');z=driver.index('change_directory:\n',a);driver=driver[:a]+'get_header:\nget_data:\n        JP io_error\n'+driver[z:]
 writer=(BASIC/'write.asm').read_text().replace('        CP 63\n','        CP 127\n')
 # The native API preserves standard MZF attributes, including zero-length
 # blocks. The interactive UI retains its existing validation policy.
 writer=writer.replace('        LD A,(save_header)\n        CP 2', '        LD A,(native_mode)\n        OR A\n        JP NZ,native_header_type\n        LD A,(save_header)\n        CP 2',1)
 writer=writer.replace('save_type_ready:\n','native_header_type:\n        LD A,(save_header)\nsave_type_ready:\n',1)
 writer=writer.replace('        LD HL,(save_header+18)\n','        LD HL,(save_header+18)\n        LD A,(native_mode)\n        OR A\n        JP NZ,save_length_ready\n',1)
 replacement=(BASIC/'replace.asm').read_text().replace('        LD B,64\n','        LD B,128\n').replace('        CP 0x0D\n','        CP 0x46\n') # Return 66h, masked by AND DFh.
 replacement=replacement.replace('        JP save_exists\nreplace_yes:', '        LD A,(native_mode)\n        OR A\n        JP NZ,native_cancel_error\n        JP save_exists\nreplace_yes:',1)
 a=replacement.index('replace_key_release:\n');z=replacement.index('replace_text:\n',a)
 replacement=replacement[:a]+'''replace_key_release:
        CALL RAM_GETKEY
        OR A
        JR NZ,replace_key_release
        RET
'''+replacement[z:]
 mount=menu[menu.index('mount:\n'):menu.index('fat_selected:\n')].replace('        LD SP,0x2BF0\n','').replace('        OUT (0xE3),A\n','')
 mount=mount.replace('        LD HL,(BUF+17)', '        LD HL,(BUF+48)\n        LD (fsinfo_number),HL\n        LD HL,(BUF+50)\n        LD (backup_number),HL\n        LD HL,(BUF+17)',1)
 for line in ('        LD (depth),A\n','        LD (menu_ready),A\n','        LD (pending_cpm),A\n'):mount=mount.replace(line,'')
 init=(ROOT/'hardware/gide-menu/stage1.asm').read_text().split('initialise:\n',1)[1].split('; Common, validated')[0];init='initialise:\n'+init
 init=init.replace('        LD A,(BUF+99)', '''        XOR A
        LD (flush_required),A
        LD A,(BUF+167)
        AND 0xD0
        CP 0x50
        JP NZ,cache_capability
        LD A,1
        LD (flush_required),A
cache_capability:
        LD A,(BUF+170)
        AND 0x20
        JP Z,cache_safe
        LD A,(flush_required)
        OR A
        JP Z,init_retry
cache_safe:
        LD A,(BUF+99)''',1)
 diag=(ROOT/'hardware/gide-diagnostic/gidetest.asm').read_text();reg=diag[diag.index('register_test:\n'):diag.index('read_sector:\n')]
 source=(HERE/'save-ui.asm').read_text()+driver+common+'two32: DB 2,0,0,0\neoc32: DB 248,255,255,15\n'+writer+replacement+(BASIC/'boot.asm').read_text()+init+mount+reg+'patterns: DB 0,255,85,170,1,2,4,8,16,32,64,128\nfat32_minimum: DB 245,255,0,0\nsave_service_end:\n'
 source=source.replace('        CALL 0x396C','        CALL ascii_value').replace('        CALL 0x0012','        CALL RAM_PUTC').replace('        CALL 0x001B','        CALL RAM_GETKEY').replace('        CALL 0x0006','        LD A,13\n        CALL RAM_PUTC')
 # The gate bytes call the actual ROM, not themselves.
 source=source.replace('OUT (0xE3),A\n        CALL RAM_PUTC','OUT (0xE3),A\n        CALL 0x0012').replace('OUT (0xE3),A\n        CALL RAM_GETKEY','OUT (0xE3),A\n        CALL 0x001B')
 for line in ('        LD (0x38BF),A\n','        LD (0x38C0),A\n'):source=source.replace(line,'')
 data,sy=pk.run(defs+source,'save-service')
 assert sy['save_entry']==0xD000 and sy['save_service_end']<0xF000,(len(data),hex(sy['save_service_end']))
 assert data[sy['ram_gates']-0xd000:sy['ram_gates_end']-0xd000]==bytes.fromhex('d3e3cd1200d3e1c9d3e3cd1b00d3e1c9d3e3cd0300d3e1c9')
 (BUILD/'save-symbols.json').write_text(json.dumps(sy,indent=2)+'\n');print('Card save service:',len(data),'bytes, end',hex(sy['save_service_end']))
if __name__=='__main__':main()
