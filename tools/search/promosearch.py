import sys
sys.argv=['x','5']
src=open('valsearch.py').read().split("ALPH =")[0].replace("T = [0,1,2,3,4,5]","T = [0x0d,0x31,0x32,0x33,0x34]")
exec(src)
want = {  # anahtar -> tur (B2 R3 Q4 N5 alfabesinde)
 'eski (1V 2A 3K 4F)': [4,4,5,3,2],
 'dogal (1V 2K 3F 4A)':[4,4,3,2,5],
 'yeni (1V 2A 3F 4K)': [4,4,5,2,3],
}
for nm,w in want.items():
    hits=sorted([(c,seq) for st,(c,seq) in best.items() if [a for a,h in st]==w])
    print(nm, hits[:3] if hits else 'yok')
