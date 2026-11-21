#!/usr/bin/env python3
"""Verify the original monitor and record the compatibility/space baseline."""
from pathlib import Path
import hashlib,importlib.util,json,subprocess,sys
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1];BUILD=HERE/'build';BUILD.mkdir(exist_ok=True)
REF=ROOT/'cpm/mz700-monitor/reference'
s=importlib.util.spec_from_file_location('monitor_normalise',ROOT/'cpm/mz700-monitor/normalise.py');n=importlib.util.module_from_spec(s);s.loader.exec_module(n)
source=(REF/'Mz700.asm').read_bytes();provenance=json.loads((REF/'provenance.json').read_text())
assert hashlib.sha256(source).hexdigest()==provenance['source_sha256']
(BUILD/'stock.asm').write_text(n.normalise(source.decode('latin1')))
subprocess.run([sys.executable,str(ROOT/'cpm/gide/third_party/pyz80.py'),'--obj='+str(BUILD/'stock.bin'),'--mapfile='+str(BUILD/'stock.map'),str(BUILD/'stock.asm')],check=True)
rom=(BUILD/'stock.bin').read_bytes();stock=(ROOT/'reference/mz700-monitor-and-font.bin').read_bytes()[:4096]
assert len(rom)==4096 and rom==stock and hashlib.sha256(rom).hexdigest()==provenance['original_rom_sha256']
sy={name:int(addr,16) for addr,name in (line.split('=',1) for line in (BUILD/'stock.map').read_text().splitlines())}
public=[]
for addr,name in [(0,'MONIT'),(3,'GETL'),(6,'LETNL'),(9,'NL'),(12,'PRNTS'),(15,'PRNTT'),(18,'PRNT'),(21,'MSG'),(24,'MSGX'),(27,'GETKY'),(30,'BRKEY'),(33,'WRINF'),(36,'WRDAT'),(39,'RDINF'),(42,'RDDAT'),(45,'VERFY'),(48,'MELDY'),(51,'TIMST'),(59,'TIMRD'),(62,'BELL'),(65,'XTEMP'),(68,'MSTA'),(71,'MSTP')]:
 assert sy[name]==addr and rom[addr]==0xc3
 public.append({'name':name,'entry_hex':f'{addr:04X}','target_hex':f'{int.from_bytes(rom[addr+1:addr+3],"little"):04X}'})
gaps=[(0x748,17),(0x837,36),(0xd8e,24),(0x886,13),(0x3f5,4),(0x9f6,9)]
for addr,count in gaps:assert rom[addr:addr+count]==bytes(count)
report={'stock_bytes':4096,'stock_sha256':hashlib.sha256(rom).hexdigest(),'source_provenance':provenance,'public_vectors':public,'interrupt_vector_hex':'0038','interrupt_ram_target_hex':'1038','command_entry_hex':{name:f'{sy[name]:04X}' for name in ('LOAD','SAVE','VRFY','DUMP','MCOR','GOTO','PTEST')},'audited_padding_bytes':sum(c for _,c in gaps),'audited_padding':[{'address_hex':f'{a:04X}','bytes':c} for a,c in gaps],'fat32_stage1_bytes':len((ROOT/'hardware/gide-menu/build/GIDE-BOOT.MZT').read_bytes())-128,'baseline_monitor_experiment':'cpm/mz700-monitor','replacement_rom_built':False}
(BUILD/'compatibility-audit.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps({k:v for k,v in report.items() if k not in ('public_vectors','source_provenance')},indent=2))
