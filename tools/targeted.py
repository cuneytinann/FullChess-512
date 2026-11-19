#!/usr/bin/env python3
"""Targeted rule tests for an L1 asm build. Each case: SAN moves to reach a position,
then UCI attempts checked against python-chess (legal ones are played)."""
import sys, os, chess
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))   # run16/fuzz bu klasorde
from fuzz import engine_board, expected, PROMO_KEY, LIGHT, light_tail, FIFTY, end_code
from run16 import run

CASES = [
    ('O-O through check (Ba6 hits f1)', 'e4 b6 Nf3 Ba6 g3 Nc6 Bg2 Nf6', ['e1g1', 'e1f1']),
    ('O-O out of check (Qe6+)', 'e4 d5 exd5 Qxd5 Nf3 Bf5 Bc4 Qe6+', ['e1g1', 'c4e6']),
    ('O-O into check (Rg5 hits g1)', 'g4 h5 gxh5 Rxh5 Nf3 Rg5 Bh3 Nc6', ['e1g1', 'e1f1']),
    ('O-O-O with b1 attacked is legal', 'b4 a5 bxa5 Rxa5 Nc3 Rb5 d4 Nf6 Bf4 Nc6 Qd2 e6', ['e1c1']),
    ('O-O-O blocked by Nb1', 'd4 d5 Bf4 Bf5 Qd2 Qd7', ['e1c1', 'e1d1']),
    ('king moved and came back', 'e4 e5 Ke2 Ke7 Ke1 Ke8 Nf3 Nf6 Bc4 Bc5', ['e1g1', 'e1e3', 'h2h3', 'e8g8']),
    ('rook moved and came back', 'e4 e5 Nf3 Nf6 Bc4 Bc5 Rg1 Rg8 Rh1 Rh8', ['e1g1', 'e1f1', 'e8g8']),
    ('black castles both ways', 'e4 e5 Nf3 Nc6 Bc4 Bc5 d3 d6 Be3 Be6 Nc3 Qd7 Qd2', ['e8c8']),
    ('black O-O', 'e4 e5 Nf3 Nf6 Bc4 Bc5 d3', ['e8g8']),
    ('e.p. immediately', 'e4 a6 e5 d5', ['e5d6']),
    ('e.p. too late', 'e4 a6 e5 d5 Nf3 a5', ['e5d6', 'e5e6']),
    ('e.p. black', 'a3 d5 a4 d4 e4', ['d4e3']),
    ('e.p. horizontal pin', 'd4 h5 Kd2 h4 Kc3 Rh5 b4 Nf6 b5 Ng8 Kb4 Nf6 Ka5 c5', ['b5c6', 'b5b6']),
    ('double step blocked', 'e4 e5', ['e2e4', 'd2d4', 'e4e5', 'd7d5']),
    ('pinned piece', 'e4 e5 Nc3 Bb4 d3 Nf6', ['c3d5', 'c3e2', 'a2a3']),
    ('mate: fools mate', 'f3 e5 g4 Qh4#', []),
    ('stalemate: Loyd', 'e3 a5 Qh5 Ra6 Qxa5 h5 h4 Rah6 Qxc7 f6 Qxd7+ Kf7 Qxb7 Qd3 Qxb8 Qh7 Qxc8 Kg6 Qe6', []),
    ('underpromotion to knight with check', 'h4 g5 hxg5 h6 gxh6 Nf6 h7 Rg8 Nf3 Nc6', ['h7g8n']),
    ('promotion to rook by capture', 'h4 g5 hxg5 h6 gxh6 Nf6 h7 Rg8 Nf3 Nc6', ['h7g8r']),
    ('king into check refused', 'e4 f6 Qh5+', ['e8f7', 'g7g6']),
    ('rook captured, other rook arrives on h1', 'e4 Nf6 Bc4 Ng4 Ne2 Nxf2 h4 Nxh1 a4 e6 Ra3 Be7 Rh3 d6 Rxh1 Nc6', ['e1g1', 'e1f1']),
]

SHUF = 'Nf3 Nf6 Ng1 Ng8 '
if FIFTY:
    n = FIFTY // 4
    CASES += [
        ('fifty: tam esikte beraberlik', (SHUF * n).strip(), []),
        ('fifty: esikten bir eksik, oyun surer', (SHUF * (n - 1)).strip() + ' Nf3 Nf6 Ng1', ['e7e5', 'g1f3']),
        ('fifty: piyon sifirlar', (SHUF * (n - 1)).strip() + ' Nf3 e5 ' + ('Ng1 Nf6 Nf3 Ng8 ' * (n - 1)).strip(), ['f3g1']),
        ('fifty: alma sifirlar', 'e4 d5 exd5 Qxd5 ' + (SHUF * (n - 1)).strip(), ['g1f3']),
        ('fifty: rok sessiz hamle sayilir', 'e4 e5 Nf3 Nf6 Bc4 Bc5 O-O O-O ' + ('Nh4 Nh5 Nf3 Nf6 ' * (n - 2)).strip() + ' Kh1 Kh8', []),
    ]

def plan_for(san, attempts):
    b = chess.Board(); plan = []
    for s in san.split():
        m = b.parse_san(s)
        plan.append((keys(m), expected(b), True)); b.push(m)
    for a in attempts:
        m = chess.Move.from_uci(a)
        legal = b.is_legal(m)
        plan.append((keys(m), expected(b), legal))
        if legal: b.push(m)
    end = end_code(b)
    if end and LIGHT:
        import random
        plan.extend(light_tail(b, random.Random(0), n=200))
    return plan, b, end

def keys(m):
    s = chess.square_name(m.from_square) + chess.square_name(m.to_square)
    return s + (PROMO_KEY[m.promotion] if m.promotion else '\r')

def main(path, boot=False):
    bad = 0
    for name, san, attempts in CASES:
        plan, final, end = plan_for(san, attempts)
        snaps = []
        def on_key(uc, idx):
            if idx % 5 == 0: snaps.append(engine_board(uc))
        out, reason, mu = run(path, ''.join(k for k, _, _ in plan), boot, on_key=on_key)
        ok = all(i < len(snaps) and snaps[i] == exp for i, (_, exp, _) in enumerate(plan))
        ok = ok and engine_board(mu) == expected(final)
        got = out.rstrip()[-1:] if reason == 'exit' else None
        if end and LIGHT: ok = ok and reason != 'exit' and not out.rstrip().endswith(('#', '='))
        elif end: ok = ok and got == end
        else: ok = ok and reason != 'exit'
        tail = plan[len(san.split()):]
        legal_flags = ' '.join(('+' if l else '-') + k[:4] for k, _, l in tail[:6]) + (f' (+{len(tail)-6} reddedilecek)' if len(tail) > 6 else '')
        print(f"{'OK  ' if ok else 'FAIL'} {name:40s} {legal_flags} {('end ' + end) if end else ''}")
        bad += not ok
    print('failing:', bad)
    return bad

if __name__ == '__main__':
    sys.exit(1 if main(sys.argv[1], '--boot' in sys.argv) else 0)
