#!/usr/bin/env python3
"""Bot promotion check: position K f7, P g6, B c1 (White) vs K h8, P a2 (Black). White (human) plays
c1d2 with a chosen 5th key; Black's only legal move is a2-a1=?, and the bot must promote to the piece
of the human's last 5th key (n -> knight, r -> rook, b -> bishop, anything else -> queen).
usage: botpromo.py image [--boot]"""
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from run16 import run

BOARD, SAVE = 0x7F00, 0x8000
P, B, R, Q, N, K, BL, U = 1, 2, 3, 4, 5, 6, 0x20, 0x80      # bot alphabet
POS = {0x07: K | BL, 0x15: K, 0x26: P, 0x60: P | BL, 0x72: B}
NAME = {B: 'B', R: 'R', Q: 'Q', N: 'N'}

def trial(img, key, boot):
    seq = list('c1d2') + [key] + ['\r']          # extra key: bot replied, back at human input
    st = {'poked': False}
    def prov(uc):
        if not st['poked']:
            for base in (BOARD, SAVE + 0x80, 0x6007 + 0x80):  # board + backup (ply<3: 0x8000, ply>=3: 0x6007)
                for r in range(8):
                    uc.mem_write(base + r * 16, bytes(8))
                for sq, v in POS.items():
                    uc.mem_write(base + sq, bytes([v]))
            st['poked'] = True
        if len(seq) == 1:
            st['a1'] = uc.mem_read(BOARD + 0x70, 1)[0]
            st['a2'] = uc.mem_read(BOARD + 0x60, 1)[0]
        return seq.pop(0) if seq else None
    run(img, prov, boot)
    v = st.get('a1', 0)
    ok = st.get('a2') == 0 and (v & 0x20) and (v & 0x5F) in NAME
    return NAME[v & 0x5F] if ok else f'?{v:#04x}'

img = sys.argv[1]; boot = '--boot' in sys.argv
want = {'n': 'N', 'N': 'N', 'r': 'R', 'R': 'R', 'b': 'B', 'B': 'B', '\r': 'Q', 'q': 'Q', 'x': 'Q', '2': 'Q'}
bad = []
for k, w in want.items():
    got = trial(img, k, boot)
    if got != w: bad.append(f'{k!r}: {got} (want {w})')
print(f'{len(want)} keys, {len(bad)} failing' + (': ' + '; '.join(bad) if bad else ''))
