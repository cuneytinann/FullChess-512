#!/usr/bin/env python3
"""Play an L1 BOT build (bot = black) against random white moves from python-chess.
Checks: every bot move is legal (the engine board after it equals python-chess's board
after some legal black move), illegal white attempts are refused, white's moves are
accepted, and the game end (#/=) matches python-chess. Also reports how often the bot
captured / avoided hanging material, as a sanity check that scoring works.
usage: botfuzz.py prog.com [games] [seed] [--boot]"""
import sys, os, random, chess
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))   # run16/fuzz bu klasorde
from run16 import run
from fuzz import engine_board, expected, PROMO_KEY, biased_choice, LIGHT

VAL = {chess.PAWN: 1, chess.KNIGHT: 3, chess.BISHOP: 3, chess.ROOK: 5, chess.QUEEN: 9, chess.KING: 0}

def keys_for(m):
    s = chess.square_name(m.from_square) + chess.square_name(m.to_square)
    return s + (PROMO_KEY[m.promotion] if m.promotion else '\r')

def play_game(path, rng, maxply, boot):
    b = chess.Board()
    st = {'q': [], 'expect_same': None, 'err': None, 'bot_moves': 0, 'bot_caps': 0, 'plies': 0,
          'bot_best': 0}
    def provider(uc):
        if st['err']: return None
        if st['q']:
            return st['q'].pop(0)
        eb = engine_board(uc)
        if st['expect_same'] is not None:          # previous entry was an illegal attempt
            if eb != st['expect_same']:
                st['err'] = 'illegal white attempt was accepted'; return None
            st['expect_same'] = None
        if LIGHT and (b.is_checkmate() or b.is_stalemate()):   # light: sonuc yok, tahta donmali
            if eb != expected(b):
                st['err'] = 'board changed after game end'; return None
            st['ended'] = '#' if b.is_checkmate() else '='
            return None
        if b.turn == chess.BLACK:                    # the bot must have replied
            found = None
            for m in b.legal_moves:
                b.push(m)
                if expected(b) == eb: found = m
                b.pop()
                if found: break
            if found is None:
                st['err'] = 'bot move not found among legal moves (illegal or wrong)'; return None
            # scoring sanity: compare with the 2-ply material score of the best move
            def score(mv):
                cap = b.piece_at(mv.to_square)
                gain = VAL[cap.piece_type] if cap else 0
                b.push(mv)
                worst = 0
                for r in b.legal_moves:
                    c = b.piece_at(r.to_square)
                    if c: worst = max(worst, VAL[c.piece_type])
                b.pop()
                return gain - worst
            sc = {m: score(m) for m in b.legal_moves}
            if sc[found] == max(sc.values()): st['bot_best'] += 1
            if b.is_capture(found): st['bot_caps'] += 1
            st['bot_moves'] += 1
            b.push(found); st['plies'] += 1
        if b.is_checkmate() or b.is_stalemate():
            if LIGHT:
                st['ended'] = '#' if b.is_checkmate() else '='; return None
            st['err'] = f'engine asks for input in a finished game ({b.fen()})'; return None
        if st['plies'] >= maxply:
            return None
        if expected(b) != eb and b.turn == chess.WHITE and st['bot_moves'] == 0 and st['plies'] == 0:
            pass
        # random illegal attempt
        if rng.random() < 0.25:
            pl = [m for m in b.pseudo_legal_moves if not b.is_legal(m)]
            if pl and rng.random() < 0.6:
                m = rng.choice(pl)
            else:
                f, t = rng.randrange(64), rng.randrange(64)
                m = chess.Move(f, t)
            if f'{m}' != '0000' and not b.is_legal(m) and m.from_square != m.to_square:
                st['expect_same'] = eb
                st['q'] = list(keys_for(m))
                return st['q'].pop(0)
        m = biased_choice(b, rng)
        if os.environ.get('MATEPREF') == '1':      # beyaz: mat varsa mat et, yoksa almayi tercih et
            mates = [x for x in b.legal_moves if (b.push(x) or b.is_checkmate() or b.is_stalemate(), b.pop())[0]]
            caps = [x for x in b.legal_moves if b.is_capture(x)]
            if mates: m = rng.choice(mates)
            elif caps and rng.random() < 0.7: m = rng.choice(caps)
        b.push(m); st['plies'] += 1
        st['q'] = list(keys_for(m))
        return st['q'].pop(0)
    out, reason, mu = run(path, provider, boot)
    st['moves'] = [m.uci() for m in b.move_stack]
    if st['err']: return st['err'], st
    if reason == 'exit':
        end = out.rstrip()[-1:]
        eb = engine_board(mu)
        if b.turn == chess.BLACK and expected(b) != eb:
            # the bot replied, then white had no legal move
            found = None
            for m in b.legal_moves:
                b.push(m)
                if expected(b) == eb: found = m; break
                b.pop()
            if found is None:
                return 'engine ended game; final position is not reachable by a legal bot move', st
            st['bot_moves'] += 1
        if expected(b) != eb:
            return 'final board mismatch', st
        if not (b.is_checkmate() or b.is_stalemate()):
            return f'engine ended game but side to move has legal moves ({b.fen()})', st
        want = '#' if b.is_checkmate() else '='
        if end != want: return f'wrong result {end!r} want {want!r}', st
        st['ended'] = want
    elif reason != 'input exhausted':
        # SPIN: bot hamle bulamazsa doner (jmp $ gibi): yalniz oyun bittiyse ve tahta degismediyse dogru
        if (LIGHT and os.environ.get('SPIN') == '1' and reason.startswith('instruction limit')
                and b.turn == chess.BLACK and (b.is_checkmate() or b.is_stalemate())
                and engine_board(mu) == expected(b)):
            st['ended'] = '#' if b.is_checkmate() else '='
            st['spin'] = st.get('spin', 0) + 1
            return None, st
        return f'engine stopped: {reason}', st
    return None, st

if __name__ == '__main__':
    path = sys.argv[1]
    games = int(sys.argv[2]) if len(sys.argv) > 2 else 10
    seed = int(sys.argv[3]) if len(sys.argv) > 3 else 1
    rng = random.Random(seed)
    fails = 0; tot = {'bot_moves': 0, 'bot_caps': 0, 'bot_best': 0, 'mates': 0, 'stales': 0}
    for g in range(games):
        err, st = play_game(path, rng, rng.choice([60, 120, 200]), '--boot' in sys.argv)
        for k in ('bot_moves', 'bot_caps', 'bot_best'): tot[k] += st[k]
        if st.get('ended') == '#': tot['mates'] += 1
        if st.get('ended') == '=': tot['stales'] += 1
        tot['spin'] = tot.get('spin', 0) + st.get('spin', 0)
        if err:
            fails += 1; print(f'game {g}: {err}')
            if '--moves' in sys.argv: print('  moves:', ' '.join(st.get('moves', [])))
            if fails >= 3: break
    print(f"{games} games, {fails} failing; bot moves={tot['bot_moves']}, bot captures={tot['bot_caps']}, "
          f"bot picked a top-2ply-material move {tot['bot_best']}/{tot['bot_moves']}, mates={tot['mates']}, stalemates={tot['stales']}, bot-spun={tot.get('spin', 0)}")
    sys.exit(1 if fails else 0)
