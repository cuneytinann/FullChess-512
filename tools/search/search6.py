"""<=6 baytlik diziler: (<=4 B durum) + analitik son 2-baytlik islem, (<=5 B durum) + 1-baytlik,
(<=3 B durum) + 3-baytlik imul/kaydirma. Girdi: tus kodlari; AH bilinmiyor."""
import sys
sys.argv=['x','5']
src=open('valsearch.py').read().split("ALPH =")[0].replace("T = [0,1,2,3,4,5]","T = [0x0d,0x31,0x32,0x33,0x34]")
exec(src)
def last2(al, w):
    out=[]
    k=al[0]^w[0]
    if all(a^k==t for a,t in zip(al,w)): out.append(f'xor al,{k:#x}')
    k=(w[0]-al[0])&255
    if all((a+k)&255==t for a,t in zip(al,w)): out.append(f'add al,{k:#x}')
    # and: t must be subset of a; k must contain all t bits and exclude bits in a&~t
    need=0; forb=0
    for a,t in zip(al,w):
        if t & ~a & 255: need=None; break
        need|=t; forb|=a & ~t
    if need is not None and not (need & forb): out.append(f'and al,{need:#x}')
    need=0; ok=True; forb=0
    for a,t in zip(al,w):
        if a & ~t & 255: ok=False; break
        need|=t & ~a; forb|= ~t & 255
    if ok and not (need & forb):
        # or k: t = a|k for all -> k must cover t&~a and avoid bits where t is 0
        k=need
        if all((a|k)==t for a,t in zip(al,w)): out.append(f'or al,{k:#x}')
    for k in range(1,256):
        if all(a%k==t for a,t in zip(al,w)): out.append(f'aam {k:#x}'); break
    for nm,f in [('neg al',lambda a:(-a)&255),('not al',lambda a:a^255),('shl al,1',lambda a:(a<<1)&255),
                 ('shr al,1',lambda a:a>>1),('rol al,1',lambda a:((a<<1)|(a>>7))&255),('ror al,1',lambda a:((a>>1)|(a<<7))&255)]:
        if all(f(a)==t for a,t in zip(al,w)): out.append(nm)
    return out
targets={}
for s in (0x00,0x08,0x10,0x40):
    for b,r in ((2,3),(3,2)):
        targets[f'S={s:#04x} F{b} K{r}']=[4|s,4|s,5,b|s,r|s]
res={k:[] for k in targets}
for st,(c,seq) in best.items():
    al=[a for a,h in st]
    for nm,w in targets.items():
        if c<=4:
            for op in last2(al,w): res[nm].append((c+2,seq+[op]))
        if c<=5:
            if all(((a+1)&255)==t for a,t in zip(al,w)): res[nm].append((c+1,seq+['inc ax']))
            if all(((a-1)&255)==t for a,t in zip(al,w)): res[nm].append((c+1,seq+['dec ax']))
        if c<=3:
            for k in range(256):
                if all((a*k)&255==t for a,t in zip(al,w)): res[nm].append((c+3,seq+[f'imul ax,ax,{k:#x}']))
for nm in targets:
    h=sorted(res[nm])
    print(f'{nm:18s}', (h[0][0], '; '.join(h[0][1])) if h else 'yok (<=6 B)', f'(+{len(h)-1} esdeger)' if len(h)>1 else '')
