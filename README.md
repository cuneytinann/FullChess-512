# FullChess

**Chess with the full rules of movement, in a single 512-byte x86 boot sector.**
Every move FIDE allows, no move it forbids.

- Castling, with all its conditions
- En passant
- Promotion to queen, knight, bishop or rook
- No move that leaves or puts your own king in check
- Game ends on checkmate or stalemate

Two versions are the main ones:

| | Mode | Boot sector code | DOS .COM |
|---|---|---|---|
| **`fullchess.bin`** | two players | **492 bytes** | 476 B (`bin/fchess.com`) |
| **`fullchess-cpu.bin`** | you (White) vs the computer | **480 bytes** | 463 B (`bin/fcvscpu.com`) |

The two-player version also shows `#` / `=` at the end of the game, applies the 50-move rule and turns
the board around for Black; 18 of the 510 code bytes of the boot sector are still free. Promotion is
chosen with a letter: `N`, `R`, `B` (either case), any other key gives a queen. The rule set is
[FideLite](https://fidelite.art) L1.

Both files are in the top folder of this repository, and each is exactly one 512-byte sector: 510 bytes
of code and the 2-byte `55 AA` boot signature.

**Quick start:** open https://copy.sh/v86/, choose `fullchess.bin` as *Floppy disk image*, press
*Start*, then type `e2e4` and press Enter.

---

## Why "full"

Most famous tiny chess programs play a simplified game. They leave out castling, en passant or
promotion, or let you make moves that are not legal in chess. Their authors say so openly; it is how
they get so small. FullChess asks a different question: **how small can a program be if it drops none
of the rules of movement?**

The yardstick is FIDE's: a move is illegal when it breaks any of Articles 3.1–3.9 of the *Laws of
Chess*. Those articles cover castling, en passant, promotion and moving into check. The game ends in
checkmate or stalemate (Article 5).

| Program | Size | Platform | Castling | En passant | Promotion choice | Rejects illegal moves² | Ends on mate / stalemate |
|---|---|---|---|---|---|---|---|
| **FullChess** (two players) | **492 B** | boot sector | ✓ | ✓ | ✓ | ✓ | ✓ shows `#` / `=` |
| **FullChess** (vs computer) | **480 B** | boot sector | ✓ | ✓ | ✓¹ | ✓ | ✓ game halts³ |
| AttoChess (2026) | 278 B | DOS | ✗ | ✗ | ✗ no promotion | ✗ | ✗ |
| LeanChess | 288 B | DOS / BIOS | ✗ | ✗ | ✗ no promotion | ✗ | ✗ |
| Toledo Atomchess | 326–392 B | boot sector | ✗ | ✗ | ✗ no promotion | ✗ | ? |
| Super Micro Chess "mini" | 455 B | DOS | ✗ | ✗ | ✗ queen only | ? | ? |
| BootChess (2015) | 487 B | boot sector | ✗ | ✗ | ✗ queen only | ✗ king may move into check | ? |
| Super Micro Chess "full FIDE" | 583 B | DOS | ✓ | ✓ | ✓ | ? | ? |
| Toledo Atomchess Reloaded | 779 B | 2 boot sectors | ✓ | ✓ | ✗ queen only | ✓ | ? |

¹ You choose the piece; the computer promotes to the piece you chose last (normally the queen).
² Every move that breaks FIDE Article 3 is refused, including moves that leave your own king in check.
³ No indicator is shown; the game simply stops (see [Limitations](#limitations)).
? = not documented by the author.

Features are as documented by each program's author; checked on 19 November 2026 (sources at the end).
Outside x86, ChesSkelet (ZX Spectrum) holds the Guinness record for the smallest chess program
(354 bytes, 2022; later 269 bytes). It does not implement all the rules; its full version has basic
castling. 1K ZX Chess (ZX81, 672 bytes, 1982–83) has no castling, promotion or en passant.

**As far as we know, FullChess is the smallest x86 chess program that implements FIDE's rules of
movement in full and fits in one 512-byte boot sector.** Every chess program under 512 bytes we know
of plays a simplified game.

---

## All versions

Sizes are bytes of code in the boot sector, without the zero padding and the 2-byte `55 AA` signature
(at most 510). DOS sizes are file sizes. Every file is rebuilt by `build.sh`.

### Main versions — top folder (`.bin`) and `bin/` (`.img`, `.com`)

| Boot sector | DOS | Mode | Boot | DOS | Contents |
|---|---|---|---|---|---|
| `fullchess.bin` | `bin/fchess.com` | two players | **492** | 476 | full rules + `#`/`=` + 50-move rule + board flips for Black |
| `fullchess-cpu.bin` | `bin/fcvscpu.com` | vs computer | **480** | 463 | full rules, computer looks 1 ply ahead (material only) |

### Extras — `bin/extras/`

Two players (`src/fullchess.asm`):

| Name | Flags | Boot | DOS | Contents |
|---|---|---|---|---|
| `2p` | — | 466 | 450 | full rules + `#`/`=` |
| `2p50` | `-DFIFTY` | 481 | 465 | + 50-move rule |
| `2pflip` | `-DFLIP` | 477 | 461 | + board flips for Black |
| `2plight` | `-DLIGHT` | **444** | 436 | full rules, no end indicator (at mate/stalemate no move is accepted) |
| `2plightr` | `-DLIGHT -DREDRAW` | 444 | 436 | as `2plight`, board redrawn after every input |

Vs computer (`src/fullchess-cpu.asm`, all with `-DSPIN`; the main version is `-DPLY=1`):

| Name | Flags | Boot | DOS | Computer's evaluation |
|---|---|---|---|---|
| `cpu2or` | `-DPLY=2 -DOR2` | 484 | 467 | 2 plies, approximate (OR of threatened pieces) |
| `cpu2` | `-DPLY=2` | 488 | 471 | 2 plies: captured − opponent's best capture |
| `cpu3or` | `-DPLY=3 -DOR2` | 510 | 496 | 3 plies, approximate leaf |
| `cpu3` | `-DPLY=3` | (514, does not fit) | 500 | 3 plies, DOS only |
| `cpu4or` | `-DPLY=4 -DOR2` | does not fit | 513 | 4 plies, approximate leaf, DOS only |
| `cpu4` | `-DPLY=4` | does not fit | 517 | 4 plies, DOS only |

The fifty-move version can be built as a 75-move version with `-DPLIES=150` (same size; not prebuilt).

### File types
- `.bin` — the 512-byte boot sector (ends in `55 AA`). This is the program; v86 boots it directly.
- `.img` — the same 512 bytes followed by zeros up to 1.44 MB, for tools that expect a full floppy
  disk. Nothing after the first 512 bytes is ever read.
- `.com` — DOS program built from the same source (BIOS/segment setup removed). DOS names stay
  within 8.3 so they run in plain DOS and DOSBox.

---

## How to play

- Type a move as *from* and *to* squares, then Enter: `e2e4⏎`.
- Castle by moving the king: `e1g1`, `e1c1`.
- Promote by pressing a piece letter instead of Enter: **N** knight, **R** rook, **B** bishop, upper or
  lower case. Every other key (Enter, `Q`, a digit, …) gives a queen. Example: `e7e8` then `n`
  promotes to a knight. The boot sector reads the key's BIOS scan code, so it is the physical N, R or
  B key that counts (with Shift or Ctrl too); the DOS versions read the letter.
- The board is 8 text rows: `.` empty, `PNBRQK` White, `pnbrqk` Black, rank 8 on top. In
  `fullchess` the board turns around when Black is to move. Coordinates you type are always absolute.
- An illegal move is silently ignored; type it again.
- End of game: `#` checkmate, `=` stalemate or 50-move draw.
- Against the computer you play White, and the computer answers at once. When it promotes, it takes
  the piece of your last fifth key (normally Enter, so a queen).

**No line editing: Backspace does not work.**
- Every attempt is exactly **5 keys**: four coordinate keys, then Enter (or a promotion key). The program
  counts keys; it does not know "typed" from "deleted".
- Only the low 4 bits of each key are used, so `a` = `A` = `1` … `h` = `H` = `8`. `e2e4⏎`, `5254⏎` and
  `ebe4⏎` are the same move. Backspace (code 8) is read as `h` or `8`.
- Every key is echoed on screen. In BIOS, Backspace moves the cursor left but does not erase, and
  Enter returns the cursor to the start of the line. After a rejected attempt the cursor stays on the same line (except in `2plightr`).
- **Made a typo?** Do not press Backspace. Fill the attempt up to 5 keys with Enter (it will be
  rejected), then type the move again. If you already pressed Backspace, it counts as one of the 5 keys.
- **Lost count?** Type the move. If the board is not redrawn, press Enter once more and try again; each
  extra Enter shifts the count by one key, so at most 4 extra tries line it up. Rarely, a shifted input
  happens to form a legal move and is played.
- `2plightr` redraws the board after every 5 keys, so you can see where an attempt ends.

---

## Running

- **Browser, nothing to install:** https://copy.sh/v86/ → *Floppy disk image* → pick `fullchess.bin`
  (or any `.bin` / `.img`) → *Start*.
- **QEMU:** `qemu-system-i386 -fda bin/fullchess.img`
- **DOSBox / DOS:** run `fchess.com` or `fcvscpu.com`.
- **Real hardware:** write the `.bin` to the first sector of a floppy or USB stick (`dd`, RaWrite).
  Not tried yet.

## Building

```
bash build.sh      # needs nasm; rebuilds the two main .bin files, bin/ and bin/extras/, prints sizes
nasm -f bin [-Dboot] <flags> src/fullchess.asm -o x.bin     # one version by hand (no -Dboot: .COM)
```

`src/fullchess.asm` options: `-Dboot`, `-Dbios` (.COM with BIOS I/O), `-DLIGHT`, `-DREDRAW` (with LIGHT),
`-DFIFTY` (`-DPLIES=n`), `-DFLIP`.
`src/fullchess-cpu.asm` options: `-Dboot`, `-Dbios`, `-DPLY=1..4`, `-DOR2`, `-DSPIN`.

## Testing

```
pip install unicorn chess
bash build.sh && bash test.sh     # KIND=bin or KIND=com for one half; results like TEST_RESULTS.txt
```

Every shipped version is tested as a boot sector (where it fits) and as a DOS program, against
[python-chess](https://python-chess.readthedocs.io/) as referee:

- `tools/run16.py` — a 16-bit PC emulator on [Unicorn](https://www.unicorn-engine.org/), with BIOS
  (int 10h/16h, with US-layout scan codes) and DOS (int 21h/29h) services. Boot sectors start with
  random register values to catch hidden assumptions.
- `tools/targeted.py` — 22 hand-made cases (27 with the 50-move rule). Castling under every condition,
  en passant, every promotion, mate, stalemate, moving into check, a captured rook replaced by another
  rook. The board is compared after every move, and every legal and illegal attempt is checked.
- `tools/fuzz.py` — random two-player games, biased towards captures and special moves, with illegal
  attempts mixed in; a "quiet" mode forces 50-move draws.
- `tools/botfuzz.py` — random White against the computer, including illegal attempts. Every computer
  move must be legal. A mate-seeking White checks the end of the game.
- `tools/promokeys.py` — promotes a pawn once with every key code (0x00–0x7F and 0xE0) on each
  two-player version and checks the rule: N/R/B keys give knight/rook/bishop, every other key a queen
  (boot sector: by scan code; DOS: by letter, either case).
- `tools/botpromo.py` — sets up a position where the computer's only move is a promotion and checks
  that it promotes to the piece of the human's last fifth key.
- `tools/qboot.py` — boots an image in QEMU with SeaBIOS, types keys and takes screenshots.

Last full run, 25 November 2026 (`TEST_RESULTS.txt`): **0 failures** in 59 test runs. That covers the
targeted cases on every two-player version, 640 random two-player games (53,010 moves and 28,426 illegal
attempts), 326 games against the computer (17,447 computer moves), 1,548 promotions with every key
code and 40 computer promotions, in both boot and DOS form.
The main versions were also booted and played under QEMU with SeaBIOS (letter promotion, Shift held
or not).

## How it works

- **Board:** a 16-wide board in one 256-byte page. Columns 8–15 and rows 8–15 are a frame, so a step
  off the board lands on a frame square without any bounds check. The move generator is in the style
  of Óscar Toledo's Atomchess; the rule logic around it is our own.
- **Legality by trying:** each candidate move is played on a copy of the position, then all replies
  are scanned. If a reply can capture the king, the move is illegal. The same scan answers "is the king
  in check now?".
- **Castling** has no generator of its own. When the king's first step (e1→f1) is legal and the king
  has never moved, the code checks the squares up to its own unmoved rook and that the king is not in
  check now. It then puts the rook on the crossed square and tries the king's second step (e1→g1) as an
  ordinary move.
- **En passant square and 50-move counter** live in memory that is saved and restored with the
  position, so a rejected attempt undoes them automatically.
- **Mate/stalemate:** legal moves are counted while matching your input. If there are none, the
  program checks whether the opponent can capture the king right now (`#`) or not (`=`).
- **Board flip:** square addresses are XOR-ed with `0x77` when Black is to move.
- **Computer:** the reply scan that checks legality also collects the most valuable capture the
  opponent has. Score = value captured − that (1, 2, 3 or 4 plies). Weights P1 N2 B2 R3 Q4, computed
  without a table (`aam 5; aad 2`).
- **Promotion table in the start-up code:** the boot sector begins with `mov cx,0x3013; cld;
  xor ax,ax` = `B9 13 30 FC 31 C0`. Bytes 1–4 are the scan codes of R and B, a filler and N; byte 5 is
  overwritten with each key's scan code after start-up and ends the search. `CX = 0x3013` is also the
  fill count. The match position is the piece code itself (2 rook, 3 bishop, 5 knight, 6 queen).
- **Typed move on the stack:** the input pushes the two squares to the bottom of the stack, and the
  legal move that matches them falls straight into the main loop; nothing is unwound.

Inline comments in `src/` are in Turkish. The full development record (every size gained or lost, dead
ends, bugs) is in Turkish in [`docs/DEVLOG.tr.md`](docs/DEVLOG.tr.md).

## Limitations

- **No repetition draws and no dead-position draws** (threefold/fivefold repetition, insufficient
  material). FullChess covers FIDE's rules of movement and checkmate/stalemate, not every draw rule.
- **50-move rule is automatic at 50 moves.** FIDE makes the 50-move draw a claim and the 75-move draw
  automatic; `-DPLIES=150` builds the 75-move version.
- **No game-end indicator against the computer.** At mate or stalemate the game stops: if the computer
  has no move it loops idly; if you have none, no input is accepted.
- **The computer is weak by design:** it counts material only (1 ply in the main version, with weights
  1/2/2/3/4). It promotes to the piece you chose last. The 3- and 4-ply versions treat "opponent has no
  legal reply" as a big gain, so they may steer into stalemate.
- **No line editing** (see [How to play](#how-to-play)).
- Not yet tried on real hardware.

## Credits

- Move generator style: Óscar Toledo G., [Atomchess](https://nanochess.org/chess6.html).
- Rule set: [FideLite](https://github.com/cuneytinann/FideLite) L1.
- Testing: [python-chess](https://python-chess.readthedocs.io/), [Unicorn](https://www.unicorn-engine.org/);
  in-browser running: [v86](https://copy.sh/v86/).

Comparison sources: [BootChess](https://www.chessprogramming.org/BootChess) ·
[Atomchess](https://nanochess.org/chess6.html) · [toledo-atomchess](https://github.com/nanochess/toledo-atomchess) ·
[Super Micro Chess](https://smmax.sourceforge.net/) · [LeanChess](https://leanchess.github.io/) ·
[AttoChess](https://nicholas-afk.github.io/AttoChess/) ·
[1K ZX Chess](https://en.wikipedia.org/wiki/1K_ZX_Chess) ·
[ChesSkelet](https://hackaday.com/2019/03/28/writing-a-very-tiny-chess-program) ·
[Guinness record](https://www.guinnessworldrecords.com/world-records/598436-smallest-chess-computer-programme) ·
[FIDE Laws of Chess](https://rcc.fide.com/?p=842)

## License

[MIT](LICENSE)
