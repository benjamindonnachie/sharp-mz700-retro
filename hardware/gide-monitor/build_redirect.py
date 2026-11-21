#!/usr/bin/env python3
"""Pack a data-preserving native SAVE adapter into retired RAM tape code."""
from pathlib import Path
import importlib.util,json,re,hashlib
import version
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1];B=HERE/'build'
s=importlib.util.spec_from_file_location('redirect_packer',ROOT/'hardware/gide-basic/pack_driver.py');pk=importlib.util.module_from_spec(s);s.loader.exec_module(pk);pk.BUILD=B

def install(stock):
 rom=(B/'MZ700-GIDE-MONITOR-4K.bin').read_bytes();assert rom[0x109]==0xe9 and rom[0x6b:0x6d]==bytes.fromhex('d3e0')
 orig={n:int(v,16) for v,n in (line.split('=') for line in (B/'stock.map').read_text().splitlines())}
 rs=json.loads((B/'build.json').read_text())['symbols'];writer=(B/'save-service.bin').read_bytes();sectors=(len(writer)+511)//512
 constants={'TIMFG':orig['TIMFG'],'WRITER_SECTORS':sectors,'EXPECTED_WRITER_SUM':sum(writer)&65535,'ROM_COMMAND_ADDRESS':rs['ide_command'],'ROM_WAIT_ADDRESS':rs['ide_wait'],'ORIGINAL_RDINF':orig['QRDI'],'ORIGINAL_RDDAT':orig['QRDD'],'ORIGINAL_VERFY':orig['QVRFY'],'ORIGINAL_MOTOR':orig['MOTOR'],'ORIGINAL_MSTOP':orig['MSTOP'],'ORIGINAL_MELDY':orig['QMLDY']}
 defs=''.join(f'{n}: EQU {v}\n' for n,v in constants.items())
 src=(HERE/'native-save.asm').read_text().replace('; DATE_BYTES','DB '+','.join(map(str,version.DATE_LINE)));partition_bytes=(ROOT/'hardware/gide-menu/build/gide-mz700-cpm-fat32.img').read_bytes()[446:512];src=src.replace('; EXPECTED_PARTITIONS_BYTES','DB '+','.join(map(str,partition_bytes)));src=re.sub(r'(?m)^(\s*)JR\s+',r'\1JP ',src);src=re.sub(r'DEFS (\d+)',lambda m:'DB '+','.join(['0']*int(m[1])),src);src=re.sub(r'(?m)^(\w+): (DB|DW)',r'\1:\n        \2',src)
 boundaries=['native_wrinf','check_range','check_workspace','save_bad','native_wrdat','save_finish_bad','save_finish','save_return_flags','check_card_layout','backup_upper','scratch_context','next_sector','verify_backup','load_writer','restore_upper','rom_read','rom_write','rom_command','rom_wait','raw_call','bank_return','check_stack','console_putc','console_key','console_line','console_call','read_header','read_data','verify_tape','tape_motor','tape_stop','play_melody','monitor_date','monitor_date_text','expected_partitions','copy_s_name','restore_text','pending_header','private_stack','raw_context','caller_sp','pending','save_result','verify_mismatch','restore_attempts','raw_active','raw_low_sp','service_low_sp','console_high_sp','raw_transfer_sp']
 starts=[src.index(n+':\n') for n in boundaries];assert starts==sorted(starts)
 modules=[]
 for i,n in enumerate(boundaries):modules.append((n,src[starts[i]:starts[i+1] if i+1<len(starts) else len(src)]))
 sy={n:0 for n in pk.labels(src)};sy.update(constants);sizes={n:len(pk.compact(body,defs,sy,0,'redirect-size-'+n)[0]) for n,body in modules}
 # Retain keyboard FLKEY, QLOAD, sound RET3, all public vectors, and the
 # complete S/M/D command parsers. Tape reads dispatch to physical ROM.
 holes=[(0x5e,0x6b),(0x109,0x10f),(0x16b,0x180),(0x18d,0x1c7),(0x1ca,0x2a6),(0x436,0x577),(0x588,0x5f0),(0x601,0x69b),(0x6a2,0x6e7),(0x703,0x71a),(0x748,0x762),(0x767,0x7a8),(0x84f,0x85b),(0x886,0x893),(0xa01,0xa32),(0xd8e,0xda6)]
 for lo,hi in [(orig[n],orig[n]+3) for n in ('QWRI','QWRD','QRDI','QRDD','QVRFY')]:
  holes=[part for a,z in holes for part in ([(a,z)] if hi<=a or lo>=z else ([(a,lo)] if a<lo else [])+([(hi,z)] if hi<z else []))]
 free=holes.copy();places={'console_putc':0x837,'console_key':0x83f,'console_line':0x847}
 for n in sorted((n for n in sizes if n not in places),key=lambda x:-sizes[x]):
  fits=[(z-a,i) for i,(a,z) in enumerate(free) if z-a>=sizes[n]]
  if not fits:raise AssertionError((n,sizes[n],sum(sizes.values()),[(hex(a),z-a) for a,z in free]))
  _,i=min(fits);a,z=free[i];places[n]=a;free[i]=(a+sizes[n],z)
 for n,body in modules:sy.update(pk.compact(body,defs,sy,places[n],'redirect-resolve-'+n)[1])
 for a,z in holes:stock[a:z]=bytes(z-a)
 for n,body in modules:
  data,labels=pk.compact(body,defs,sy,places[n],'redirect-'+n);assert len(data)==sizes[n];stock[places[n]:places[n]+len(data)]=data
 def jp(n):return b'\xc3'+sy[n].to_bytes(2,'little')
 stock[0x9f:0xa2]=b'\xcd'+sy['monitor_date'].to_bytes(2,'little')
 for old,new in [('QWRI','native_wrinf'),('QWRD','native_wrdat'),('QRDI','read_header'),('QRDD','read_data'),('QVRFY','verify_tape'),('MOTOR','tape_motor'),('MSTOP','tape_stop'),('QMLDY','play_melody')]:stock[orig[old]:orig[old]+3]=jp(new)
 # A common transition into the unchanged physical ROM's JP(HL) at 0109.
 # Native/IDE return through ROM OUT E0 at 006B, then RAM POP HL / RET.
 stock[0x107:0x109]=bytes.fromhex('d3e2');stock[0x6d:0x70]=jp('bank_return')
 stock[0x5b:0x5e]=bytes.fromhex('c35501') # legacy # expansion boot -> GIDE
 # Move only the private error handler displaced by the bank gate.
 err=bytes.fromhex('fe02caad0011')+orig['MSGE1'].to_bytes(2,'little')+bytes.fromhex('dfc3ad00')
 assert len(err)<=13;stock[0x180:0x180+len(err)]=err
 load_errors=[i for i in range(0x111,0x12d) if stock[i]==0x38 and i+2+int.from_bytes(stock[i+1:i+2],'little',signed=True)==0x107]
 assert load_errors==[0x114,0x124]
 for i in load_errors:stock[i+1]=(0x180-i-2)&255
 save=bytes(stock[0xf5e:0xfb1]);needle=bytes.fromhex('da0701');assert save.count(needle)==2
 stock[0xf5e:0xfb1]=save.replace(needle,bytes.fromhex('da8001'))
 name_loop=bytes.fromhex('131a7723fe0d20f8');assert bytes(stock).count(name_loop)==1
 at=bytes(stock).index(name_loop);stock[at:at+8]=b'\xcd'+sy['copy_s_name'].to_bytes(2,'little')+bytes(5)
 verify=bytes(stock[0xfcb:0xfd8]);assert verify.count(needle)==1
 stock[0xfcb:0xfd8]=verify.replace(needle,bytes.fromhex('da8001'))
 for n in ('console_putc','console_key','console_line'):assert sizes[n]<=8
 report={'symbols':sy,'module_sizes':sizes,'placements':places,'free_bytes':sum(z-a for a,z in free),'private_stack_bytes':64,'backup_first_lba':0x8a00,'backup_sectors':24,'writer_bytes':len(writer),'writer_checksum':sum(writer)&65535,'writer_sha256':hashlib.sha256(writer).hexdigest(),'source_range':'1000..CFFF; excludes 10F0..11F3 and 64 bytes below the caller stack plus its return address','public_write_vectors':[0x21,0x24],'private_S_entry':0xf5e,'deferred_header':True,'upper_ram_restored':True,'partition_table_checked_before_scratch_write':True,'native_error_codes':{'success':0,'error':1,'cancelled':2},'physical_rom_sha256':hashlib.sha256(rom).hexdigest()}
 (B/'redirect-build.json').write_text(json.dumps(report,indent=2)+'\n');return stock
