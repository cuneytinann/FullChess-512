#!/usr/bin/env python3
"""Fuzz an L1 asm build against python-chess.
For each game: random legal moves (castling, e.p., every promotion piece), with random
illegal attempts mixed in. Before every move entry the engine's board (read from emulator
memory) must equal python-chess's board; illegal attempts must leave it unchanged; at
mate/stalemate the program must print '#' / '=' and exit.
usage: fuzz.py prog.com [games] [seed] [--boot] [--bias]"""
import sys, os, random
import chess
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))   # run16/fuzz bu klasorde
from run16 import run

PROMO_KEY = {chess.ROOK: '2', chess.BISHOP: '3', chess.KNIGHT: '5', chess.QUEEN: '4'}
if os.environ.get('PROMO') == 'v2':
    PROMO_KEY = {chess.QUEEN: '1', chess.KNIGHT: '2', chess.ROOK: '3', chess.BISHOP: '4'}
KEY_PROMO = {v: {chess.QUEEN: 'q', chess.ROOK: 'r', chess.BISHOP: 'b', chess.KNIGHT: 'n'}[k] for k, v in PROMO_KEY.items()}
CODE = {chess.PAWN: 1, chess.ROOK: 2, chess.BISHOP: 3, chess.QUEEN: 4, chess.KNIGHT: 5, chess.KING: 6}
if os.environ.get('ALPHA') == 'br':      # fil 2, kale 3 alfabesi
    CODE[chess.BISHOP], CODE[chess.ROOK] = 2, 3
_pk = os.environ.get('PROMOMAP')         # orn. 'qnbr' = 1 vezir, 2 at, 3 fil, 4 kale
if _pk == 'letters':                     # harf terfisi: n/N at, r/R kale, b/B fil, gerisi vezir
    PROMO_KEY = {chess.QUEEN: 'Q', chess.KNIGHT: 'N', chess.ROOK: 'r', chess.BISHOP: 'B'}
    KEY_PROMO = {'Q': 'q', 'N': 'n', 'r': 'r', 'B': 'b'}
elif _pk:
    _m ={'q': chess.QUEEN, 'r': chess.ROOK, 'b': chess.BISHOP, 'n': chess.KNIGHT}
    PROMO_KEY = {_m[c]: str(i + 1) for i, c in enumerate(_pk)}
    KEY_PROMO = {v: {chess.QUEEN: 'q', chess.ROOK: 'r', chess.BISHOP: 'b', chess.KNIGHT: 'n'}[k] for k, v in PROMO_KEY.items()}

LETTER = {'P': chess.PAWN, 'N': chess.KNIGHT, 'B': chess.BISHOP, 'R': chess.ROOK, 'Q': chess.QUEEN, 'K': chess.KING}

def screen_board(text):
    """Programin bastigi son tam tahta (8 ardisik '.PNBRQKpnbrqk' satiri) -> expected() kodlamasi."""
    import re
    lines = re.split(r'\r\n|\r|\n', text)
    for end in range(len(lines), 7, -1):
        grp = lines[end - 8:end]
        if all(re.fullmatch(r'[.PNBRQKpnbrqk]{8}', l) for l in grp):
            out = []
            for l in grp:
                for ch in l:
                    out.append(0 if ch == '.' else CODE[LETTER[ch.upper()]] | (0x20 if ch.islower() else 0))
            return bytes(out)
    return None

def engine_board(mu, base=0x7F00):
    if os.environ.get('BOARDSRC') == 'screen':   # arayuz hakemi: bellek duzeni ve taş kodlarindan bagimsiz
        from run16 import RUNS
        return screen_board(''.join(RUNS[id(mu)]))
    b = mu.mem_read(base, 128)
    return bytes(b[r * 16 + c] & 0x27 for r in range(8) for c in range(8))

FLIP = os.environ.get('FLIP') == '1'
FIFTY = int(os.environ.get('FIFTY', '0'))
QUIET = float(os.environ.get('QUIET', '0'))   # orn. 0.97   # orn. 100: o kadar yarim hamlede otomatik beraberlik

def game_over(board):
    return board.is_checkmate() or board.is_stalemate() or (FIFTY and board.halfmove_clock >= FIFTY)

def end_code(board):
    if board.is_checkmate(): return '#'
    if board.is_stalemate(): return '='
    if FIFTY and board.halfmove_clock >= FIFTY: return '='
    return None

def expected(board):
    out = []
    for r in range(8):            # engine row 0 = rank 8
        for c in range(8):
            p = board.piece_at(chess.square(c, 7 - r))
            out.append(0 if p is None else CODE[p.piece_type] | (0 if p.color else 0x20))
    if FLIP and board.turn == chess.BLACK:   # siyahin gozunden: 180 derece = 64'luk dizinin tersi
        out.reverse()
    return bytes(out)

def keys_for(m):
    s = chess.square_name(m.from_square) + chess.square_name(m.to_square)
    return s + (PROMO_KEY[m.promotion] if m.promotion else '\r')

def biased_choice(board, rng):
    """Prefer special moves so they get exercised."""
    legal = list(board.legal_moves)
    special = [m for m in legal if board.is_castling(m) or board.is_en_passant(m) or m.promotion]
    if special and rng.random() < 0.7:
        return rng.choice(special)
    caps = [m for m in legal if board.is_capture(m)]
    if caps and rng.random() < 0.3:
        return rng.choice(caps)
    return rng.choice(legal)

LIGHT = os.environ.get('LIGHT') == '1'

def light_tail(board, rng, n=40):
    """Oyun bitti: tum sozde-yasal hamleler (hepsi yasa disi) + birkac rastgele kare cifti."""
    pl = [m for m in board.pseudo_legal_moves]
    rng.shuffle(pl)
    tail = [(keys_for(m), expected(board), False) for m in pl[:n]]
    for _ in range(5):
        f, t = rng.randrange(64), rng.randrange(64)
        if f != t: tail.append((keys_for(chess.Move(f, t)), expected(board), False))
    return tail

def make_game(rng, maxply, bias):
    board = chess.Board()
    plan = []        # (keys, expected_board_before, legal?)
    while not game_over(board) and len(plan) < maxply:
        # random illegal attempts
        while rng.random() < 0.35:
            f = rng.randrange(64); t = rng.randrange(64)
            pm = chess.Move(f, t)
            cands = [pm] + [chess.Move(f, t, p) for p in (chess.QUEEN,)]
            if any(board.is_legal(c) for c in cands) or f == t:
                continue
            # pseudo-legal-but-illegal moves are the interesting ones
            if rng.random() < 0.6:
                pl = [m for m in board.pseudo_legal_moves if not board.is_legal(m)]
                # castling through/out of check etc. show up here too
                if pl:
                    pm = rng.choice(pl)
            if board.is_legal(pm):
                continue
            plan.append((keys_for(pm), expected(board), False))
        if QUIET:   # sayaci zorla: cogunlukla piyon disi, almasiz hamle
            legal = list(board.legal_moves)
            quiet = [x for x in legal if not board.is_capture(x) and board.piece_type_at(x.from_square) != chess.PAWN]
            m = rng.choice(quiet) if quiet and rng.random() < QUIET else rng.choice(legal)
        else:
            m = biased_choice(board, rng) if bias else rng.choice(list(board.legal_moves))
        plan.append((keys_for(m), expected(board), True))
        board.push(m)
    end = end_code(board)
    if end and LIGHT:   # light: sonuc basilmaz; her deneme (hepsi yasa disi) reddedilmeli
        plan.extend(light_tail(board, rng))
    return plan, board, end

def check(path, games, seed, boot, bias):
    rng = random.Random(seed)
    fails = 0; stats = {'moves': 0, 'illegal': 0, 'mate': 0, 'stale': 0, 'castle': 0, 'ep': 0, 'promo': 0}
    for g in range(games):
        plan, final, end = make_game(rng, rng.choice([40, 80, 160, 300]), bias)
        keys = ''.join(k for k, _, _ in plan)
        snaps = []
        def on_key(uc, idx):
            if idx % 5 == 0:
                snaps.append(engine_board(uc))
        out, reason, mu = run(path, keys, boot, on_key=on_key)
        ok = True
        for i, (k, exp, legal) in enumerate(plan):
            if i >= len(snaps):
                print(f'game {g}: engine stopped before entry {i} ({k!r}); reason={reason}'); ok = False; break
            if snaps[i] != exp:
                print(f'game {g}: board mismatch before entry {i} {k!r} (prev entry {plan[i-1][0]!r} legal={plan[i-1][2]})')
                ok = False; break
        if ok:
            fin = engine_board(mu)
            if fin != expected(final):
                print(f'game {g}: final board mismatch; reason={reason}'); ok = False
            got_end = '#' if out.rstrip().endswith('#') else '=' if out.rstrip().endswith('=') else None
            if end and LIGHT:
                if reason == 'exit' or got_end:
                    print(f'game {g}: light build ended/printed result ({got_end!r}, {reason})'); ok = False
            elif end and (reason != 'exit' or got_end != end):
                print(f'game {g}: expected end {end}, got {got_end!r} reason={reason}'); ok = False
            if not end and reason == 'exit':
                print(f'game {g}: engine ended the game early ({got_end})'); ok = False
        if not ok:
            fails += 1
            if fails >= 3: break
        b = chess.Board()
        for k, _, legal in plan:
            if not legal: stats['illegal'] += 1; continue
            m = chess.Move.from_uci(k[:4] + KEY_PROMO.get(k[4], ''))
            if b.is_castling(m): stats['castle'] += 1
            if b.is_en_passant(m): stats['ep'] += 1
            if m.promotion: stats['promo'] += 1
            b.push(m); stats['moves'] += 1
        if end == '#': stats['mate'] += 1
        if end == '=' and final.is_stalemate(): stats['stale'] += 1
        elif end == '=': stats['fifty'] = stats.get('fifty', 0) + 1
    print(f'{games} games, {fails} failing; ' + ', '.join(f'{k}={v}' for k, v in stats.items()))
    return fails

if __name__ == '__main__':
    path = sys.argv[1]
    games = int(sys.argv[2]) if len(sys.argv) > 2 else 20
    seed = int(sys.argv[3]) if len(sys.argv) > 3 else 1
    sys.exit(1 if check(path, games, seed, '--boot' in sys.argv, '--bias' in sys.argv) else 0)
