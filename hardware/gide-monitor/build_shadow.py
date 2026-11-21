#!/usr/bin/env python3
"""Build the SD-loaded lower-RAM monitor and its bank-safe bootstrap."""
from pathlib import Path
import importlib.util,json,hashlib,struct
import version
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1];BUILD=HERE/'build'
s=importlib.util.spec_from_file_location('shadow_assembler',ROOT/'hardware/gide-basic/pack_driver.py');a=importlib.util.module_from_spec(s);s.loader.exec_module(a);a.BUILD=BUILD

def main():
 stock=bytearray((BUILD/'stock.bin').read_bytes());sy={n:int(v,16) for v,n in (l.split('=') for l in (BUILD/'stock.map').read_text().splitlines())}
 # Restore the full original monitor UI in RAM. G replaces the obsolete
 # printer self-test; F also returns to GIDE instead of probing F000h.
 gate='''        ORG 0x155
ram_gide:
        DI
        OUT (0xE1),A
        LD HL,rom_gate
        LD DE,0xF000
        LD BC,rom_gate_end-rom_gate
        LDIR
        JP 0xF000
rom_gate:
        OUT (0xE2),A
        JP 0x0DA0
rom_gate_end:
'''
 code,_=a.run(gate,'shadow-gide-gate');stock[0x155:0x155+len(code)]=code
 banner=version.BANNER;assert len(banner)<=25
 stock[0x6e7:0x700]=banner.ljust(25,b'\0')
 stock[0xa7:0xad]=b'\xc3'+sy['ST1'].to_bytes(2,'little')+bytes(3)
 stock[0xff:0x102]=bytes.fromhex('c35501')
 # CP 'P' immediately before JR PTEST, verified against pinned stock.
 at=bytes(stock).index(bytes.fromhex('fe5028'));stock[at+1]=ord('G')
 for v in json.loads((BUILD/'compatibility-audit.json').read_text())['public_vectors']:
  p=int(v['entry_hex'],16);assert stock[p:p+3]==(BUILD/'stock.bin').read_bytes()[p:p+3]
 import build_redirect
 stock=build_redirect.install(stock)
 (BUILD/'RAMMON.BIN').write_bytes(stock)
 first=(ROOT/'hardware/gide-menu/build/stage1.asm').read_text().replace('BOOT_ORIGIN: EQU 32768','BOOT_ORIGIN: EQU 33024').replace('OUT (0xE2),A','OUT (0xE0),A')
 boot,_=a.run(first,'shadow-stage1');assert len(boot)<=0xf00
 wrapper=f'''        ORG 0x8000
shadow_start:
        DI
        LD SP,0x7F00
        OUT (0xE1),A
        LD IX,0x11D0
        LD (IX+0),0x41
        LD (IX+1),0x89
        LD (IX+2),0
        LD (IX+3),0
        LD (IX+4),0
        LD (IX+5),0xD0
        LD B,8
shadow_read:
        PUSH BC
        CALL 0x0D97
        POP BC
        JR C,shadow_error
        INC (IX+0)
        INC (IX+5)
        INC (IX+5)
        DJNZ shadow_read
        LD HL,0xD000
        LD BC,4096
        LD DE,0
shadow_sum:
        LD A,(HL)
        INC HL
        ADD A,E
        LD E,A
        JR NC,shadow_next
        INC D
shadow_next:
        DEC BC
        LD A,B
        OR C
        JR NZ,shadow_sum
        LD HL,{sum(stock)&65535}
        OR A
        SBC HL,DE
        JR NZ,shadow_error
        ; Execute outside the bank being replaced throughout the copy.
        OUT (0xE0),A
        LD HL,0xD000
        LD DE,0
        LD BC,4096
        LDIR
        OUT (0xE3),A
        JP 0x8100
shadow_error:
        OUT (0xE3),A
        LD DE,shadow_text
        CALL 0x0015
shadow_wait:
        CALL 0x001B
        CP 0x52
        JR NZ,shadow_wait
        JP 0
shadow_text: DEFM "RAM MONITOR ERROR - R RETRIES"
        DB 13
'''
 prefix,_=a.run(wrapper,'shadow-wrapper');assert len(prefix)<=256
 (BUILD/'shadow-bootstrap.bin').write_bytes(prefix+bytes(256-len(prefix))+boot)
 # The menu and transfer trampoline retain lower RAM for application entry.
 menu=bytearray((ROOT/'hardware/gide-menu/build/MENU.MZF').read_bytes())
 pattern=bytes.fromhex('d3e2');offsets=[]
 for i in range(128,len(menu)-1):
  if menu[i:i+2]==pattern:offsets.append(i)
 assert len(offsets)==2,offsets
 for i in offsets:menu[i+1]=0xe0
 (BUILD/'SHADOW-MENU.MZF').write_bytes(menu)
 report={'version':version.VERSION,'build_date':version.BUILD_DATE,'ram_monitor_bytes':len(stock),'ram_monitor_sha256':hashlib.sha256(stock).hexdigest(),'bootstrap_bytes':256+len(boot),'bootstrap_sha256':hashlib.sha256((BUILD/'shadow-bootstrap.bin').read_bytes()).hexdigest(),'shadow_monitor_lba':0x8941,'menu_sha256':hashlib.sha256(menu).hexdigest(),'menu_bank_switch_offsets':offsets,'public_vectors_preserved':23,'monitor_commands':'J/L/M/V/D/B retained; S and WRINF/WRDAT save to GIDE; G/F/# return to GIDE. Printer self-test removed.'}
 (BUILD/'shadow-build.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report,indent=2))
if __name__=='__main__':main()
