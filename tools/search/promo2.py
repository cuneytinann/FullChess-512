import sys
sys.argv=['x','5']
src=open('valsearch.py').read().split("ALPH =")[0].replace("T = [0,1,2,3,4,5]","T = [0x0d,0x31,0x32,0x33,0x34]")
exec(src)
targets={}
for s in (0x00,0x08,0x10,0x40):
    for b,r in ((2,3),(3,2)):
        Q,N,B,R=4|s,5,b|s,r|s
        targets[f'S={s:#04x} F{b} K{r}']=[Q,Q,N,B,R]
for nm,w in targets.items():
    hits=sorted((c,seq) for st,(c,seq) in best.items() if [a for a,h in st]==w)
    print(f'{nm:18s}', (hits[0][0], '; '.join(hits[0][1])) if hits else 'yok (<=5 B)')
