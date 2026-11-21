"""Pack runtime code/data into obsolete BASIC device areas; boot is disposable."""
from pathlib import Path
import re,subprocess,sys,json,pickle
HERE=Path(__file__).resolve().parent;BUILD=HERE/'build';ASM=HERE.parents[1]/'cpm/gide/third_party/pyz80.py'
# 2800..2900 was the retired FDD sector buffer (only 2E2A/2E36/2E77
# reference it); the live 64-entry SD directory cache ends at 2800.
# 2900..2D08 contains retired FDD file operations. Live generic CLOSE
# starts at 2D08; its FDD-only continuation at 2D18 is replaced by RET.
# Their command-table entries are replaced with unsupported-device stubs.
# 5E1D..5E48 is the retired cold-start CMT/RS auto-OPEN sequence; the live
# statement-finishing routine begins at 5E48 and must remain intact.
# Preserve the actual SD descriptor, filename/conversion table, header
# adapter, gateway, and native no-op 3C4D. CMT/FDD entry stubs are excluded.
BASE_HOLES=[(0x2800,0x2900),(0x2B6A,0x2C46),(0x2900,0x2AFC),(0x2AFC,0x2B6A),(0x2C46,0x2D08),(0x2D19,0x2FF7),(0x3014,0x38A2),(0x3984,0x39AF),(0x39B2,0x3A01),(0x3A7C,0x3A9B),(0x3ADE,0x3B3B),(0x3B3E,0x3B5C),(0x3B5F,0x3B7D),(0x3B80,0x3BC5),(0x3BC5,0x3C2D),(0x3C30,0x3C4D),(0x3CC2,0x3D80),(0x3D82,0x3D9D),(0x3DA6,0x4000),(0x1FC1,0x2000),(0x38DB,0x390B),(0x38C3,0x38CB),(0x5E1D,0x5E48)]
STUB=b'\xc3\x97\x1f'
# FDD callers outside the retired block remain fail-closed; the arithmetic
# comparison helper 2FC9..2FCE is retained unchanged.
FD_ENTRIES=[0x2B7A,0x2B7F,0x2BEC,0x2907,0x2A4C,0x2AD2,0x2AE0,0x2D6A,0x2DD0,0x2DD8,0x2E24,0x2E2A,0x2E36,0x2E5E,0x2E77,0x2ED0,0x2F4B,0x2F6E]
LEGACY_STUBS=[(a,STUB) for a in FD_ENTRIES]+[(0x2F37,b'\0'+STUB),(0x2FCF,b'\0\0'+STUB),(0x1CD5,STUB)]+[(a,STUB) for a in (0x21,0x24,0x27,0x2a,0x2d)]
LEGACY_STUBS.extend((a,STUB) for a in (0x2AFC,0x2C46,0x2C67,0x2CB6,0x2CE2))
LEGACY_STUBS.append((0x3D9D,bytes.fromhex('f3afd3e2d3e3c30000')))
BOUNDARIES=['save_prepare','save_type_ready','save_name_loop','save_name_done','save_bad_name','scan_save_directory','save_dir_loop','save_count_entry','save_dir_next','save_directory_eoc','save_dir_end','capture_slot','fat_address','fat_get','fat_load_sector','read_fat_value','verify_free_mirror','scan_free_clusters','free_scan_loop','get_free','plan_address','load_plan_cluster','fat_set','fat_copies_checked','fat_set_copy','save_commit','save_recheck','save_write_cluster','save_write_sector','save_fill_byte','save_chain_loop','save_chain_set','save_publish','publish_existing_slot','publish_entry','publish_check','publish_slot_valid','publish_sector','invalidate_fsinfo','invalidate_one_info','write_sector','verify_sector_byte','begin_write_transfer','flush_disk','save_extension','seq_begin','seq_begin_buffer','seq_clear','seq_append','seq_appended','seq_flush','seq_close','seq_close_plan','check_old_fats','replace_found','replace_confirm','replace_prompt','replace_first','replace_validate','replace_release','replace_slot_check','replace_key_release','replace_text']
def labels(src):return set(re.findall(r'(?m)^(\w+):',src))
def run(src,stem):
 p=BUILD/(stem+'.asm');p.write_text(src)
 r=subprocess.run([sys.executable,str(ASM),'--obj='+str(BUILD/(stem+'.bin')),'--mapfile='+str(BUILD/(stem+'.map')),'--exportfile='+str(BUILD/(stem+'.symbols')),str(p)],capture_output=True,text=True)
 if r.returncode:raise RuntimeError(r.stdout+r.stderr)
 return (BUILD/(stem+'.bin')).read_bytes(),pickle.loads((BUILD/(stem+'.symbols')).read_bytes())
def compact(src,defs,external,origin,stem):
 local=labels(src);jumps=[]
 pattern=re.compile(r'(?m)^([ \t]*)JP[ \t]+(?:(NZ|Z|NC|C),)?(\w+)[ \t]*(;[^\n]*)?$')
 def mark(m):
  if m[3] not in local:return m[0]
  name='__pk_jump_'+str(len(jumps));jumps.append((name,m[3],m[0]));return name+':\n'+m[0]
 marked=pattern.sub(mark,src)
 prefix=defs+''.join(f'{n}: EQU {a}\n' for n,a in external.items() if n not in local)+f'        ORG {origin}\n'
 _,sy=run(prefix+marked,stem+'-size')
 for name,target,line in jumps:
  if -126<=sy[target]-sy[name]-2<=126:marked=marked.replace(name+':\n'+line,name+':\n'+line.replace('JP','JR',1))
 data,sy=run(prefix+marked,stem)
 return data,{n:a for n,a in sy.items() if n in local}
def holes():
 free=list(BASE_HOLES)
 for lo,hi in [(a,a+len(d)) for a,d in LEGACY_STUBS]+[(0x2FC9,0x2FCF)]:
  out=[]
  for a,z in free:
   if hi<=a or lo>=z:out.append((a,z));continue
   if a<lo:out.append((a,lo))
   if hi<z:out.append((hi,z))
  free=out
 return free

def pack_driver(kernel,writer,boot,make_defs,data_blocks):
 writer=re.sub(r'(?m)^(\w+):[ \t]+(DEFM|DB)',r'\1:\n        \2',writer)
 kernel=re.sub(r'(?m)^\s*ORG[^\n]*\n','',kernel)
 all_names=labels(kernel+writer+boot);starts=[writer.index('\n'+n+':\n')+1 for n in BOUNDARIES];assert starts==sorted(starts)
 modules=[('kernel',kernel)]
 for i,name in enumerate(BOUNDARIES):
  block=writer[starts[i]:starts[i+1] if i+1<len(starts) else len(writer)]
  last=next((l.strip() for l in reversed(block.splitlines()) if l.strip() and not l.strip().startswith(';')), '')
  if i+1<len(starts) and not (last=='RET' or re.match(r'^JP\s+\w+\s*$',last)):block+='        JP '+BOUNDARIES[i+1]+'\n'
  modules.append((name,block))
 global_sy={n:0 for n in all_names};sizes={};defs=make_defs({n:0 for n in data_blocks})
 for name,src in modules+[('boot',boot)]:sizes[name]=len(compact(src,defs,global_sy,0xE800,'pack-'+name)[0])
 placements={'boot':0xE800};free=holes()
 objects=[(n,sizes[n],'code') for n,s in modules]+[(n,z,'workspace') for n,z in data_blocks.items()]
 for name,size,kind in sorted(objects,key=lambda x:-x[1]):
  fits=[(hi-lo,i) for i,(lo,hi) in enumerate(free) if hi-lo>=size]
  if not fits:raise AssertionError(('No original-footprint space',name,size,[(hex(a),z-a) for a,z in free],sizes))
  _,i=min(fits);lo,hi=free[i];placements[name]=lo;free[i]=(lo+size,hi)
 workspaces={n:placements[n] for n in data_blocks};defs=make_defs(workspaces)
 for name,src in modules+[('boot',boot)]:
  data,sy=compact(src,defs,global_sy,placements[name],'pack-'+name);assert len(data)==sizes[name];global_sy.update(sy)
 final=[];packing=[];boot_bytes=None
 for name,src in modules+[('boot',boot)]:
  data,sy=compact(src,defs,global_sy,placements[name],'pack-'+name);assert len(data)==sizes[name]
  if name=='boot':boot_bytes=data;continue
  final.append((placements[name],data));packing.append({'module':name,'address':f'{placements[name]:04X}','bytes':len(data),'kind':'code','reclaimed':True})
 for name,size in data_blocks.items():
  final.append((placements[name],bytes(size)))
  packing.append({'module':name,'address':f'{placements[name]:04X}','bytes':size,'kind':'workspace','reclaimed':True})
 (BUILD/'packing.json').write_text(json.dumps(packing,indent=2)+'\n');(BUILD/'driver.map').write_text(''.join(f'{a:04X}={n}\n' for n,a in global_sy.items()));(BUILD/'driver.bin').write_bytes(b'')
 return b'',global_sy,final,packing,boot_bytes,workspaces
