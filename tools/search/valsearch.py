#!/usr/bin/env python3
"""Kaba kuvvet: AL = tur (0 sessiz,1..5) uzerinde, AH bilinmiyor, bayraklar bilinmiyor.
Maliyet <= MAXC bayt x86 dizileri; durum = her girdi icin (AL, AH|None). Tekrar eden durumlar atilir."""
import sys, itertools
MAXC = int(sys.argv[1]) if len(sys.argv) > 1 else 5
T = [0,1,2,3,4,5]
def s8(x): return x-256 if x>127 else x
ops = []  # (name, cost, fn(al,ah)->(al,ah) or None)
ops.append(('inc ax',1,lambda a,h:((a+1)&255, None if h is None else (h+(a==255))&255)))
ops.append(('dec ax',1,lambda a,h:((a-1)&255, None if h is None else (h-(a==0))&255)))
ops.append(('cbw',1,lambda a,h:(a, 255 if a>127 else 0)))
for k in range(256):
    ops.append((f'xor al,{k:#x}',2,lambda a,h,k=k:(a^k,h)))
    ops.append((f'add al,{k:#x}',2,lambda a,h,k=k:((a+k)&255,h)))
    ops.append((f'and al,{k:#x}',2,lambda a,h,k=k:(a&k,h)))
    ops.append((f'or al,{k:#x}',2,lambda a,h,k=k:(a|k,h)))
    ops.append((f'imul ax,ax,{k:#x}',3,lambda a,h,k=k:((a*k)&255, None)))
    if k:
        ops.append((f'aam {k:#x}',2,lambda a,h,k=k:(a%k, a//k)))
    ops.append((f'aad {k:#x}',2,lambda a,h,k=k:None if h is None else ((a+h*k)&255,0)))
for nm,f in [('neg al',lambda a:(-a)&255),('not al',lambda a:a^255),('shl al,1',lambda a:(a<<1)&255),
             ('shr al,1',lambda a:a>>1),('sar al,1',lambda a:(a>>1)|(a&128)),
             ('rol al,1',lambda a:((a<<1)|(a>>7))&255),('ror al,1',lambda a:((a>>1)|(a<<7))&255)]:
    ops.append((nm,2,lambda a,h,f=f:(f(a),h)))
for n in range(2,8):
    ops.append((f'shl al,{n}',3,lambda a,h,n=n:((a<<n)&255,h)))
    ops.append((f'shr al,{n}',3,lambda a,h,n=n:(a>>n,h)))
    ops.append((f'sar al,{n}',3,lambda a,h,n=n:((s8(a)>>n)&255,h)))
    ops.append((f'rol al,{n}',3,lambda a,h,n=n:(((a<<n)|(a>>(8-n)))&255,h)))
ops.append(('mov ah,al',2,lambda a,h:(a,a)))
ops.append(('xchg al,ah',2,lambda a,h:None if h is None else (h,a)))

def apply(state, fn):
    out=[]
    for a,h in state:
        r = fn(a,h)
        if r is None: return None
        out.append(r)
    return tuple(out)

start = tuple((t,None) for t in T)
best = {start:(0,[])}
frontier=[start]
levels={0:[start]}
for c in range(1,MAXC+1):
    levels[c]=[]
for c in range(0,MAXC+1):
    for st in levels.get(c,[]):
        if best[st][0]!=c: continue
        for nm,cost,fn in ops:
            nc=c+cost
            if nc>MAXC: continue
            ns=apply(st,fn)
            if ns is None: continue
            if ns in best and best[ns][0]<=nc: continue
            best[ns]=(nc,best[st][1]+[nm])
            levels[nc].append(ns)

ALPH = {'mevcut P1 R2 B3 Q4 N5': dict(P=1,R=2,B=3,Q=4,N=5),
        'takas  P1 B2 R3 Q4 N5': dict(P=1,B=2,R=3,Q=4,N=5)}
res=[]
for st,(c,seq) in best.items():
    al=[s8(a) for a,h in st]
    for an,m in ALPH.items():
        q,r,b,n,p,z = (al[m['Q']],al[m['R']],al[m['B']],al[m['N']],al[m['P']],al[0])
        # MIN mod (FRONT 0x7F): kucuk = iyi
        if q<r<min(b,n) and max(b,n)<p<z and max(al)<127:
            res.append((c,'MIN',an,abs(b-n),seq,dict(Q=q,R=r,B=b,N=n,P=p,bos=z)))
        if q>r>max(b,n) and min(b,n)>p>z and min(al)>-128:
            res.append((c,'MAX',an,abs(b-n),seq,dict(Q=q,R=r,B=b,N=n,P=p,bos=z)))
res.sort(key=lambda x:(x[0],x[3]))
print(f'durum sayisi {len(best)}, aday {len(res)}')
seen=set()
for c,mode,an,d,seq,v in res[:60]:
    print(c,'B', mode, an, '|', '; '.join(seq), '|', v)
