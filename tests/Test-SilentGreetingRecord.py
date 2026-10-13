"""Check the private candidate record without installing or running Skyrim."""
from pathlib import Path
import struct, sys, zlib
data=Path(sys.argv[1] if len(sys.argv)>1 else 'build/silent-greeting-probe/Acheron.esm').read_bytes()
records={}
def walk(start,end):
    while start<end:
        tag=data[start:start+4]
        size,flags,form=struct.unpack_from('<III',data,start+4)
        if tag==b'GRUP':walk(start+24,start+size);start+=size;continue
        if form&0xFFFFFF in (0x84A,0x84B):
            body=data[start+24:start+24+size]
            if flags&0x40000:body=zlib.decompress(body[4:])
            fields={}; p=0
            while p<len(body):
                key,length=struct.unpack_from('<4sH',body,p)
                assert key!=b'XXXX','Unexpected extended probe field'
                fields[key]=body[p+6:p+6+length];p+=6+length
            records[form&0xFFFFFF]=(tag,fields)
        start+=24+size
walk(0,len(data))
assert records[0x84A][0]==b'DIAL'
tag,fields=records[0x84B]
assert tag==b'INFO' and fields[b'NAM1'].rstrip(b'\0').strip()==b'','Silent text lost or nonempty'
assert b'DNAM' not in fields and b'VMAD' not in fields,'Shared voice or script attached'
assert struct.unpack_from('<I',fields[b'TRDT'],16)[0]==0,'Sound attached'
assert struct.unpack_from('<H',fields[b'ENAM'])[0]&0xC00==0xC00,'NoLip/CanMove flags lost'
assert struct.unpack('<I',records[0x84A][1][b'TIFC'])[0]==1,'Private topic child count lost'
assert records[0x84A][1][b'BNAM'],'Private topic needs normal branch registration'
print('PASS: private silent INFO has blank NAM1, no shared response/script/sound, NoLip/CanMove flags and registered parent branch')
