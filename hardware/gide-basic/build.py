#!/usr/bin/env python3
"""Reproducible, hash-checked patch of archived UniCard BASIC MZ-5Z008."""
from pathlib import Path
import argparse,hashlib,json,re,subprocess,sys,struct
from pack_driver import pack_driver,LEGACY_STUBS
HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[1];BUILD=HERE/'build';BUILD.mkdir(exist_ok=True)
SOURCE=ROOT/'reference/BASIC_5Z-008_for_unicard.mzf'
SOURCE_SHA='61bf47315c57d47eac1c2d64745d153341a5c17d06839e41f6745549833a605f'
ASM=ROOT/'cpm/gide/third_party/pyz80.py'
def assemble(src,name):
 p=BUILD/(name+'.asm');p.write_text(src)
 subprocess.run([sys.executable,str(ASM),'--obj='+str(BUILD/(name+'.bin')),'--mapfile='+str(BUILD/(name+'.map')),str(p)],check=True)
 sy={n:int(a,16) for a,n in (l.split('=',1) for l in (BUILD/(name+'.map')).read_text().splitlines())}
 return (BUILD/(name+'.bin')).read_bytes(),sy

def main():
 parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--source',type=Path,default=SOURCE);args=parser.parse_args()
 original=args.source.read_bytes();assert hashlib.sha256(original).hexdigest()==SOURCE_SHA
 basic=bytearray(original[128:]);assert len(basic)==34303
 menu=(ROOT/'hardware/gide-menu/menu.asm').read_text()
 state=menu.split('partition_start: DEFS 4',1)[1].split('trampoline_bytes:',1)[0]
 state='partition_start: DEFS 4'+state
 ram={};sizes={};offset=0
 for line in state.splitlines():
  match=re.fullmatch(r'(\w+): (DEFS (\d+)|DW 0|DB 0)',line.strip())
  if match:
   name,kind,size=match.groups();sizes[name]=int(size) if size else 2 if kind=='DW 0' else 1
 extra={'booting':1,'mounted':1,'driver_stack':2,'caller_pointer':2,'caller_count':2,'service':1,'ordinal':1,'file_open':1,'file_pointer':2,'file_remaining':2,'resolving':1,'saved_directory':4,'component':11,'path_cursor':2,'path_next':2,'cwd_path':128,'saved_path':128,'path_input':64,'saved_task':4,'reg_result':1,'init_attempts':1, 'save_pending':1,'save_header':128,'save_name':11,'save_length':2,'save_total':2,'save_clusters':1,'plan_count':1,'plan_needed':1,'plan_pointer':2,'alloc_cursor':4,'fat_value':4,'fat_offset':2,'fat_lba':4,'fat_old':4,'fat_new':4,'fat_target':4,'dir_slot_lba':4,'dir_slot_offset':2,'slot_found':1,'slot_end':1,'dir_grow':1,'dir_tail':4,'dir_link_old':4,'terminator_lba':4,'terminator_needed':1,'save_dir':4,'save_source':2,'save_left':2,'write_cluster_index':1,'write_cluster_sectors':1,'write_pointer':2,'visible_count':1,'free_sectors':2,'fsinfo_number':2,'backup_number':2,'fsinfo_target':2,'scan_mode':1,'verify_bad':1,'write_command':1,'fat_copy_index':1,'fat_cache_lba':4,'fat_cache_cluster':4,'fat_cache_valid':1,'flush_required':1}
 extra.update({'seq_active':1,'seq_operation':1,'replace_pending':1,'replace_entry':32})
 sizes.update(extra)
 common=menu[menu.index('selected_cluster:\n'):menu.index('; ---------- monitor console')].split('table_address:\n')[0].replace('        CP 128\n','        CP 64\n')
 common=common.replace('selected_cluster:\n','selected_cluster:\n        CALL selected_cluster_unchecked\n        LD HL,cluster\n        JP validate_cluster\nselected_cluster_unchecked:\n',1).replace('        LD (cluster+2),HL\n        LD HL,cluster\n        JP validate_cluster','        LD (cluster+2),HL\n        RET',1)
 # Both backends share FAT address calculation and ATA command setup.
 begin=common.index('next_cluster:\n');end=common.index('        LD DE,cluster\n        CALL copy32',begin)
 common=common[:begin]+"""next_cluster:
        LD HL,cluster
        CALL fat_address_for
        LD DE,BUF
        ADD HL,DE
        CALL read_sector
"""+common[end:]
 begin=common.index('read_try:\n');end=common.index('        LD HL,BUF\n',begin)
 common=common[:begin]+"""read_try:
        LD A,0x20
        CALL begin_write_transfer
        JP C,read_retry
"""+common[end:]
 common=common.replace('read_sector:\n','read_sector:\n        XOR A\n        LD (fat_cache_valid),A\n',1)
 mount=menu[menu.index('mount:\n'):menu.index('fat_selected:\n')].replace('        LD SP,0x2BF0\n','').replace('        OUT (0xE3),A\n','')
 mount=mount.replace('        LD HL,(BUF+17)', '        LD HL,(BUF+48)\n        LD (fsinfo_number),HL\n        LD HL,(BUF+50)\n        LD (backup_number),HL\n        LD HL,(BUF+17)',1)
 mount=mount.replace('        LD (depth),A\n','').replace('        LD (menu_ready),A\n','').replace('        LD (pending_cpm),A\n','')
 init=(ROOT/'hardware/gide-menu/stage1.asm').read_text().split('initialise:\n',1)[1].split('; Common, validated')[0]
 init='initialise:\n'+init
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
 constants='patterns: DB 0,255,85,170,1,2,4,8,16,32,64,128\ntwo32: DB 2,0,0,0\neoc32: DB 248,255,255,15\nfat32_minimum: DB 245,255,0,0\n'
 kernel=(HERE/'driver.asm').read_text()+common+'two32: DB 2,0,0,0\neoc32: DB 248,255,255,15\n'
 writer=(HERE/'write.asm').read_text()+'\n'+(HERE/'sequential.asm').read_text()+'\n'+(HERE/'replace.asm').read_text()
 boot=(HERE/'boot.asm').read_text()+init+mount+reg+'patterns: DB 0,255,85,170,1,2,4,8,16,32,64,128\nfat32_minimum: DB 245,255,0,0\n'
 body=kernel+writer+boot
 used={n:v for n,v in sizes.items() if re.search(r'\b'+n+r'\b',body)}
 path_names=('saved_directory','component','path_cursor','path_next','saved_path','path_input')
 write_names=set(extra)-set(('booting','mounted','driver_stack','caller_pointer','caller_count','service','ordinal','file_open','file_pointer','file_remaining','resolving','cwd_path','saved_task','reg_result','init_attempts'))-set(path_names)
 persistent_write={'seq_active','seq_operation','save_pending','fsinfo_number','backup_number','fat_cache_lba','fat_cache_valid','fat_cache_cluster','flush_required','write_command'}
 write_names-=persistent_write
 temporary=set(path_names)|write_names
 boot_only={n for n in used if not re.search(r'\b'+n+r'\b',kernel+writer)}
 post_names={'seq_active','seq_operation','caller_pointer','caller_count','service','ordinal','file_open','file_pointer','file_remaining','resolving','save_pending','fat_cache_lba','fat_cache_cluster','directory_budget','entry_pointer','seen_count','within_cluster','chain_end','entries_left','selected'}
 persistent_offsets={};post_offsets={};boot_offsets={}
 post_size=0;boot_size=0
 for name,size in used.items():
  if name in temporary:continue
  if name in boot_only:boot_offsets[name]=boot_size;boot_size+=size
  elif name in post_names:post_offsets[name]=post_size;post_size+=size
  else:persistent_offsets[name]=offset;offset+=size
 context_sizes={}
 context_offsets={}
 for group,names in [('directory',path_names),('save',[n for n in used if n in write_names])]:
  size=0
  for name in names:
   if name in used:context_offsets[name]=size;size+=used[name]
  context_sizes[group]=size
 context_size=max(context_sizes.values())
 # Directory resolution and SAVE never run concurrently. Their scratch
 # fields share a union; post-boot fields remain live across both services.
 assert context_size+post_size<=512,(context_sizes,post_size)
 def make_defs(addresses):
  nonlocal ram
  ram={n:addresses['persistent']+a for n,a in persistent_offsets.items()}
  ram.update({n:addresses['context']+a for n,a in context_offsets.items()})
  ram.update({n:addresses['context']+context_size+a for n,a in post_offsets.items()})
  ram.update({n:0xE000+a for n,a in boot_offsets.items()})
  return ('BASE: EQU 32\nBUF: EQU 65024\nSEEN: EQU '+str(addresses['history'])+'\nPLAN: EQU '+str(addresses['history'])+'\nSTACK_TOP: EQU '+str(addresses['stack']+128-8)+'\nFREE_RETURN: EQU 15744\n'+''.join(f'{n}: EQU {a}\n' for n,a in ram.items()))
 driver,sy,reclaimed,packing,boot_bytes,workspaces=pack_driver(kernel,writer,boot,make_defs,{'persistent':offset,'history':256,'stack':128,'context':context_size+post_size})
 gate,gs=assemble(make_defs(workspaces)+f'DRIVER_ENTRY: EQU {sy["driver_entry"]}\n'+(HERE/'gateway.asm').read_text(),'gateway')
 assert 0x3c50+len(gate)<=0x3CC2 and not any(basic[0x3c50:0x3c50+len(gate)])
 changes=[]
 def patch(a,expected,replacement,reason):
  assert basic[a:a+len(expected)]==expected,(hex(a),basic[a:a+len(expected)].hex(),expected.hex())
  basic[a:a+len(replacement)]=replacement
  changes.append({'address':f'{a:04X}','before':expected.hex(),'after':replacement.hex(),'reason':reason})
 def jp(n):return b'\xc3'+struct.pack('<H',gs[n])
 # The original FF00 ceiling and 30134-byte free-memory banner are retained.

 patch(0x3A48,b'\x66',b'\x54','Recognise uppercase MZT as well as MZF file extensions')
 patch(0x3981,b'\xf3\xf5\xd5',jp('free_hook'),'Report create-only write availability, capped to 32 KiB')
 patch(0x39af,b'\xc5\xe5\x3e',jp('name_hook'),'Enumerate FAT32 directory entries')
 block=bytes(basic[0x3a71:0x3a9b])
 replacement=b'\xe1\xe5\xcd'+struct.pack('<H',gs['header_hook'])+b'\xda'+struct.pack('<H',gs['header_error'])+b'\xc3\x9b\x3a'
 patch(0x3a71,block,replacement.ljust(len(block),b'\x00'),'Read MZF/MZT header from selected FAT32 file')
 for a,n,reason in ((0x3adb,'save_header_hook','Prepare create-only SAVE'),(0x3b3b,'read_hook','Read file data via GIDE ATA sectors'),(0x3b5c,'save_data_hook','Commit a new file without replacing an existing entry'),(0x3b7d,'chdir_hook','Resolve INIT directory paths'),(0x3c2d,'select_hook','Replace UniCard device selection/status with GIDE state')):
  patch(a,bytes(basic[a:a+3]),jp(n),reason)
 patch(0x3c50,bytes(len(gate)),gate,'Bank/stack gateway in verified unused UniCard patch area')
 # Remove RS/FDD device registrations and guard their former common paths.
 patch(0x4031,b'\xcd\x1d\x5e',b'\xcd'+struct.pack('<H',sy['runtime_ready']),'Skip retired automatic cassette/serial OPEN commands at startup')
 patch(0x2FF7,b'\x59\x33',b'\xa2\x38','Link CMT directly to SD, removing obsolete RS and FD registrations')
 patch(0x0CD3,b'\x8d\x35',b'\xa2\x38','Select SD module during startup instead of legacy FDD module')
 patch(0x1FB4,b'\xcd\x8d\x36',b'\xaf\0\0','Remove unconditional legacy FDD motor-off call from common error path')


 patch(0x0CCC,b'\xf7\x2f',b'\xa2\x38','Use SD as the device-chain head instead of the retired cassette module')
 patch(0x2D18,bytes(basic[0x2D18:0x2D19]),b'\xc9','Return after generic close-all without entering removed FDD-only cleanup')
 for addr,data in LEGACY_STUBS:
  patch(addr,bytes(basic[addr:addr+len(data)]),data,'Fail closed for a retired cassette/FDD/monitor entry point')
 for addr,data in reclaimed:
  patch(addr,bytes(basic[addr:addr+len(data)]),data,'Place SAVE code in audited obsolete device code/unused padding')
 # Keep credits to SHARP and NOBOMI-SOFT; identify our hardware adaptation.
 banner=basic.find(b'UNICARD\x05MK3B')
 assert banner>=0
 patch(banner,b'UNICARD\x05MK3B',b'GIDE IDE   '+b' ', 'Identify GIDE hardware adaptation')
 # Loadable through the existing 1000..CFFF GIDE menu. A short bridge at
 # C800 relocates BASIC to its required address 0000 and installs the driver.
 bridge=f'''ORG 0xC800
 DI
 OUT (0xE0),A
 OUT (0xE1),A
 LD HL,0x1000
 LD DE,0
 LD BC,{len(basic)}
 LDIR
 LD HL,{0x1000+len(basic)}
 LD DE,0xE800
 LD BC,{len(boot_bytes)}
 LDIR
 LD SP,0xE700
 CALL {sy['boot_entry']}
 JP 0
'''
 bridge_bytes,_=assemble(bridge,'bridge')
 start=0x1000+len(basic)+len(boot_bytes)
 wrapper=(b'\xf3\x21'+struct.pack('<H',start+15)+b'\x11\x00\xc8\x01'+struct.pack('<H',len(bridge_bytes))+b'\xed\xb0\xc3\x00\xc8'+bridge_bytes)
 payload=basic+boot_bytes+wrapper;assert 0x1000+len(payload)<0xC800
 header=bytearray(original[:128]);header[1:18]=b'GIDE BASIC700\r'.ljust(17,b'\r');struct.pack_into('<HHH',header,18,len(payload),0x1000,start)
 target=BUILD/'GIDEBAS.MZF';target.write_bytes(header+payload)
 (BUILD/'GIDEBW.MZF').write_bytes(header+payload)
 # A tokenised BASIC demonstration, matching the independently verified
 # editor tokens and the fragmented-file fixture used by the emulator tests.
 def basic_line(number,tokens):
  data=struct.pack('<H',number)+tokens+b'\0'
  return struct.pack('<H',len(data)+2)+data
 demo=basic_line(10,b'\x8f "GIDE BASIC LOAD OK"')+basic_line(20,b'\x98')
 demo+=b''.join(basic_line(n,b'\x97 '+b'Z'*80) for n in range(100,600,10))+b'\0\0'
 demo_header=bytearray(128);demo_header[0]=5;demo_header[1:18]=b'GIDELOAD\r'.ljust(17,b'\r')
 struct.pack_into('<HHH',demo_header,18,len(demo),0x85ff,0)
 (BUILD/'GIDELOAD.MZF').write_bytes(demo_header+demo)

 (BUILD/'symbols.json').write_text(json.dumps(dict(sy,**ram,BUF=0xFE00,STACK_TOP=workspaces['stack']+120,PLAN=workspaces['history'],SEEN=workspaces['history']),indent=2)+'\n')
 report={'source':str(args.source),'source_sha256':SOURCE_SHA,'source_url':'https://www.sharpwiki.cz/doku.php?id=en:unicard:z50download','output':'GIDEBW.MZF','sha256':hashlib.sha256(target.read_bytes()).hexdigest(),'driver_bytes':sum(p['bytes'] for p in packing if p['kind']=='code'),'driver_start':f'{sy["driver_entry"]:04X}','state_bytes':offset+context_size+post_size,'additional_reserved_ram':0,'original_basic_free_bytes':30134,'basic_free_bytes':30134,'workspaces':workspaces,'context_bytes':context_size,'post_boot_bytes':post_size,'cold_boot_bytes':len(boot_bytes),'gateway_bytes':len(gate),'shared_workspace':context_sizes,'reclaimed_code_bytes':sum(p['bytes'] for p in packing if p['kind']=='code'),'packing':packing,'payload_bytes':len(payload),'basic_ceiling':'FF00','commands':'DIR, INIT, LOAD, RUN, SAVE and WOPEN/PRINT/T/CLOSE/ROPEN/INPUT/T via GIDE; confirmed overwrite','patches':changes}
 (BUILD/'build.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps({k:v for k,v in report.items() if k!='patches'},indent=2))

if __name__=='__main__':main()
