#!/usr/bin/env python3
"""Promotion with every key (two-player builds). Plays 1.a4 b5 2.axb5 a6 3.bxa6 Bb7 4.axb7 Nc6 5.bxa8=?
once for every key code 0x00..0x7F and 0xE0 as the 5th key, and checks that the pawn always becomes
a legal piece (queen, rook, bishop or knight) and that Enter/1/2/3/4 give Q/Q/N/B/R.
usage: promokeys.py image [--boot]"""
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from run16 import run

PIECE = {2: 'R', 3: 'B', 5: 'N', 6: 'Q'}          # two-player piece codes
PRE = 'a2a4\rb7b5\ra4b5\ra7a6\rb5a6\rc8b7\ra6b7\rb8c6\r'
DOC = {0x0D: 'Q', 0x31: 'Q', 0x32: 'N', 0x33: 'B', 0x34: 'R'}

def promote(img, code, boot):
    seq = list(PRE + 'b7a8') + [chr(code)]
    st = {}
    def prov(uc):
        if seq: return seq.pop(0)
        st['a8'] = uc.mem_read(0x7F00, 1)[0]
        st['b7'] = uc.mem_read(0x7F11, 1)[0]
        return None
    run(img, prov, boot)
    v = st.get('a8', 0)
    ok = st.get('b7') == 0 and not (v & 0x20) and (v & 0x7F) in PIECE
    return (PIECE[v & 0x7F] if ok else None), v

img = sys.argv[1]; boot = '--boot' in sys.argv
codes = list(range(0x80)) + [0xE0]
bad = []
for c in codes:
    p, v = promote(img, c, boot)
    if p is None or (c in DOC and p != DOC[c]):
        bad.append(f'{c:#04x}->{v:#04x}')
print(f'{len(codes)} keys, {len(bad)} failing' + (': ' + ' '.join(bad[:10]) if bad else ''))
