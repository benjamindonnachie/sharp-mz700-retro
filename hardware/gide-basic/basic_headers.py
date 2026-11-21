"""Reversible header-name repairs; the BASIC programme payload is immutable."""
import hashlib,re
from library_layout import display_title

def repair_cmt_name(row,data):
    row=dict(row)
    if not data[1:5]==b'CMT:':return row,data
    repaired=bytearray(data);repaired[1:18]=data[5:18]+b'\r'*4;repaired=bytes(repaired)
    assert repaired[:1]==data[:1] and repaired[18:]==data[18:]
    old_name=data[1:18].split(b'\r')[0].split(b'\0')[0].decode('ascii')
    name=repaired[1:18].split(b'\r')[0].split(b'\0')[0].decode('ascii')
    assert name==old_name[4:]
    row['load_name']=name
    title=re.sub(r'^CMT[: ]+','',display_title(row['title']),flags=re.I)
    if title!=row['title']:
        row.setdefault('original_catalogue_title',row['title']);row['title']=title
    row['header_adaptation']={'operation':'Removed CMT: from tape-header name','original_sha256':hashlib.sha256(data).hexdigest(),'original_load_name':old_name,'payload_sha256':hashlib.sha256(data[128:]).hexdigest()}
    row['sha256']=hashlib.sha256(repaired).hexdigest()
    return row,repaired
