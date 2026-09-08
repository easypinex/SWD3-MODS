"""Read-only AMD64 minidump exception registers and captured stack words.

Usage: python ReadCrashDump.py <dump>. Does not attach to or run the game.
"""
import struct,sys
from pathlib import Path
b=Path(sys.argv[1]).read_bytes()
assert b[:4]==b'MDMP'
def unpack(fmt,at): return struct.unpack_from('<'+fmt,b,at)
n,directory=unpack('II',8)
streams={}
for i in range(n):
    kind,size,rva=unpack('III',directory+i*12);streams[kind]=(size,rva)
ex=streams[6][1] if 6 in streams else streams[7][1]
# MINIDUMP_EXCEPTION_STREAM is stream type 6.
thread=unpack('I',ex)[0];code=unpack('I',ex+8)[0];addr=unpack('Q',ex+24)[0]
size,ctx=unpack('II',ex+160)
print('thread',thread,'exception',hex(code),'address',hex(addr))
regs={name:unpack('Q',ctx+offset)[0] for name,offset in
    [('rax',120),('rcx',128),('rdx',136),('rbx',144),('rsp',152),('rbp',160),
     ('rsi',168),('rdi',176),('r8',184),('r9',192),('r10',200),('r11',208),
     ('r12',216),('r13',224),('r14',232),('r15',240),('rip',248)]}
for name,value in regs.items():print(name,hex(value))
game_base=None
if 4 in streams:
    rva=streams[4][1];count=unpack('I',rva)[0]
    for i in range(count):
        at=rva+4+i*108;base,sz=unpack('QI',at);nr=unpack('I',at+20)[0]
        ln=unpack('I',nr)[0];name=b[nr+4:nr+4+ln].decode('utf-16le')
        if name.lower().endswith('swd3.exe'):
            game_base=base
            print('game base',hex(base),'size',hex(sz))
ranges=[]
if 5 in streams:
    rva=streams[5][1];count=unpack('I',rva)[0]
    for i in range(count):
        start,sz,off=unpack('QII',rva+4+i*16);ranges.append((start,sz,off))
if 9 in streams:
    rva=streams[9][1];count,off=unpack('QQ',rva)
    for i in range(count):
        start,sz=unpack('QQ',rva+16+i*16);ranges.append((start,sz,off));off+=sz
for start,sz,off in ranges:
    if start<=regs['rsp']<start+sz:
        end=min(start+sz,regs['rsp']+512)
        for address in range(regs['rsp'],end-7,8):
            value=unpack('Q',off+address-start)[0]
            print('stack+'+hex(address-regs['rsp']),hex(value))
        break
if game_base is not None:
    for rva in [0x2bf3cc,0x2bf3d0,0x2bf3d4,0x2bf3d8,0x2bf40c,0x2bf414,0x2bf418,0x2bf41c,0x2bf430,0x2bf478]:
        address=game_base+rva
        for start,sz,off in ranges:
            if start<=address and address+4<=start+sz:
                print('global RVA '+hex(rva),hex(unpack('I',off+address-start)[0]));break
        else:print('global RVA '+hex(rva),'not captured')
