#!/usr/bin/env python3
"""Build a drop-in monitor, preserving the original public helper vectors."""
from pathlib import Path
import hashlib,importlib.util,json,re,sys
import version
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1];BUILD=HERE/'build';BUILD.mkdir(exist_ok=True)
s=importlib.util.spec_from_file_location('packer',ROOT/'hardware/gide-basic/pack_driver.py');pk=importlib.util.module_from_spec(s);s.loader.exec_module(pk)
pk.BUILD=BUILD

def main():
 original=(BUILD/'stock.bin').read_bytes();assert len(original)==4096
 for a,z in ((0x3f5,0x3f9),(0x9f6,0x9ff)):assert original[a:z]==bytes(z-a)
 src=(HERE/'rom.asm').read_text().replace('; DATE_BYTES','DB '+','.join(map(str,version.DATE_LINE)))
 src=re.sub(r'(?m)^(\s*)JR\s+',r'\1JP ',src)
 boundaries=['rom_boot','rom_error','error_text','load_service','service_address','service_magic_check','service_size_ok','service_sector','service_sum','service_exit','service_bad','service_magic','ide_init','ide_read','ide_read_buffer','read_bytes','ide_write','ide_write_buffer','write_bytes','ide_command','ide_buffer_ok','ide_wait','ide_bad','ide_settle','brand_date','brand_date_text']
 starts=[src.index('\n'+x+':\n')+1 if '\n'+x+':\n' in src else src.index(x+':\n') for x in boundaries]
 assert starts==sorted(starts)
 modules=[]
 for i,name in enumerate(boundaries):
  body=src[starts[i]:starts[i+1] if i+1<len(starts) else len(src)]
  last=next((x.strip() for x in reversed(body.splitlines()) if x.strip() and not x.lstrip().startswith(';')),'')
  if name not in ('error_text','service_magic','brand_date_text') and i+1<len(starts) and not(last=='RET' or re.match(r'^JP (\w+|\(HL\))$',last)):
   body+='        JP '+boundaries[i+1]+'\n'
  modules.append((name,body))
 sy={n:0 for n in pk.labels(src)};sizes={}
 for name,body in modules:sizes[name]=len(pk.compact(body,'',sy,0,'size-'+name)[0])
 # Remove only private command handlers and the old printer command.
 # Keep the LOAD body and its error exits, as a bank-safe tape chain primitive.
 holes=[(0xad,0x1c7),(0x7a8,0x7e6),(0xd29,0xd8e),(0xf5e,0xfb1),(0xfcb,0xfd8),(0x748,0x759),(0x837,0x85b),(0x886,0x893),(0x3d5,0x3da),(0x470,0x475),(0x942,0x946),(0x3f5,0x3f9),(0x9f6,0x9ff),(0x98b,0x996)]
 reserved=[(0xad,0xb0),(0xd9,0xdc),(0x10b,0x10e),(0x10f,0x12f),(0x7a8,0x7ab),(0xd29,0xd2c),(0xf5e,0xf61)]
 for lo,hi in reserved:
  new=[]
  for a,z in holes:
   if hi<=a or lo>=z:new.append((a,z));continue
   if a<lo:new.append((a,lo))
   if hi<z:new.append((hi,z))
  holes=new
 # Keep the bank-transition JP(HL) at 0109 for the RAM monitor gateway.
 assert sizes['rom_boot']==21
 placements={'rom_boot':0xF5};free=[]
 for a,z in holes:
  if a<=0xF5<z:
   if a<0xF5:free.append((a,0xF5))
   if 0x10A<z:free.append((0x10A,z))
  else:free.append((a,z))
 names=sorted((n for n in sizes if n not in placements),key=lambda n:-sizes[n])
 failed=set()
 def pack(index):
  if index==len(names):return True
  state=(index,tuple(sorted(z-a for a,z in free)))
  if state in failed:return False
  name=names[index];size=sizes[name];seen=set()
  for capacity,i in sorted((z-a,i) for i,(a,z) in enumerate(free) if z-a>=size):
   if capacity in seen:continue
   seen.add(capacity);a,z=free[i];free[i]=(a+size,z);placements[name]=a
   if pack(index+1):return True
   free[i]=(a,z);placements.pop(name)
  failed.add(state);return False
 assert pack(0),('No compatible ROM packing',sizes)
 for name,body in modules:
  _,labels=pk.compact(body,'',sy,placements[name],'resolve-'+name);sy.update(labels)
 rom=bytearray(original);allowed=set()
 for a,z in holes:rom[a:z]=bytes(z-a);allowed.update(range(a,z))
 packing=[]
 for name,body in modules:
  data,labels=pk.compact(body,'',sy,placements[name],name);assert len(data)==sizes[name]
  at=placements[name];rom[at:at+len(data)]=data;packing.append({'module':name,'address':at,'bytes':len(data)})
 def patch(a,b):rom[a:a+len(b)]=b;allowed.update(range(a,a+len(b)))
 def jp(a):return b'\xc3'+a.to_bytes(2,'little')
 
 for entry in (0xad,0xd9,0x7a8,0xd29,0xf5e):patch(entry,jp(sy['rom_boot']))
 patch(0x10b,jp(sy['rom_error']))
 # Native initialisation still sets up the display, PPI, keyboard and timer.
 patch(0xa7,jp(sy['rom_boot'])+bytes(3))
 api=b'GIDE'+bytes([1,0x0f])+b''.join(jp(sy[n]) for n in ('ide_init','ide_read','ide_write','load_service','rom_boot'))+jp(0x111)
 assert len(api)==24;patch(0xd8e,api)
 banner=version.BANNER
 assert len(banner)<=25
 patch(0x6e7,banner.ljust(25,b'\0'))
 assert original[0x9f:0xa2]==bytes.fromhex('cd7705')
 patch(0x9f,b'\xcd'+sy['brand_date'].to_bytes(2,'little'))
 for v in json.loads((BUILD/'compatibility-audit.json').read_text())['public_vectors']:
  a=int(v['entry_hex'],16);assert rom[a:a+3]==original[a:a+3]
 changed=[i for i,(a,b) in enumerate(zip(original,rom)) if a!=b];assert set(changed)<=allowed
 target=BUILD/'MZ700-GIDE-MONITOR-4K.bin';target.write_bytes(rom)
 font=(ROOT/'reference/mz700-monitor-and-font.bin').read_bytes()[4096:8192]
 (BUILD/'emulator-rom.bin').write_bytes(rom+font+b'\xff'*8192)
 report={'monitor_sha256':hashlib.sha256(rom).hexdigest(),'monitor_bytes':4096,'public_vectors_preserved':23,'original_sha256':hashlib.sha256(original).hexdigest(),'rom_code_bytes':sum(sizes.values()),'free_bytes':sum(z-a for a,z in free),'packing':packing,'symbols':sy,'api_descriptor':0xd8e,'api_entries':dict(zip(('init','read512','write512','load_service','boot','tape_load'),range(0xd94,0xda6,3))),'raw_service_header_lba':0x8900,'save_service_header_lba':0x8920,'card_changes_made':False,'version':version.VERSION,'build_date':version.BUILD_DATE}
 (BUILD/'build.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report,indent=2))
if __name__=='__main__':main()
