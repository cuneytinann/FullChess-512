#!/usr/bin/env python3
"""Run a 16-bit DOS .COM (or boot image) under Unicorn with BIOS int 10h/16h hooks.
usage: run16.py prog.com "e2e4 e7e5 ..." [--boot] [--trace-board]
Keys are fed to int 16h one character at a time (spaces in the script are dropped,
'|' is sent as Enter). Output of int 10h AH=0Eh is collected and printed."""
import sys
from unicorn import *
from unicorn.x86_const import *

RUNS = {}

# BIOS int 16h AH=00h: AH = tarama kodu (ABD duzeni), AL = ASCII. Ctrl+harf, harfin tarama kodunu verir.
_ROWS = {0x02: '1234567890-=', 0x10: 'qwertyuiop[]', 0x1E: "asdfghjkl;'`", 0x2B: '\\zxcvbnm,./'}
_SHIFT = {'!': '1', '@': '2', '#': '3', '$': '4', '%': '5', '^': '6', '&': '7', '*': '8', '(': '9', ')': '0',
          '_': '-', '+': '=', '{': '[', '}': ']', ':': ';', '"': "'", '~': '`', '|': '\\', '<': ',', '>': '.', '?': '/'}
SCAN = {}
for _b, _r in _ROWS.items():
    for _i, _c in enumerate(_r): SCAN[ord(_c)] = _b + _i
for _c in range(ord('a'), ord('z') + 1):
    SCAN[_c - 0x20] = SCAN[_c]; SCAN[_c - 0x60] = SCAN[_c]        # buyuk harf, Ctrl+harf
for _k, _v in _SHIFT.items(): SCAN[ord(_k)] = SCAN[ord(_v)]
SCAN.update({0x20: 0x39, 0x0D: 0x1C, 0x08: 0x0E, 0x09: 0x0F, 0x1B: 0x01, 0x00: 0x03, 0x1C: 0x2B,
             0x1D: 0x1B, 0x1E: 0x07, 0x1F: 0x0C, 0x7F: 0x0E, 0xE0: 0x48})
def scan_code(ch): return SCAN.get(ch, 0)       # bilinmeyen (ör. Alt+sayi tus takimi): AH = 0

def run(path, keys, boot=False, max_insn=None, on_key=None):
    import os as _os
    if max_insn is None: max_insn = int(_os.environ.get("MAXINSN", 400_000_000))
    code = open(path, 'rb').read()
    mu = Uc(UC_ARCH_X86, UC_MODE_16)
    mu.mem_map(0, 0x110000)
    base = 0x7C00 if boot else 0x100
    mu.mem_write(base, code)
    if not boot:
        mu.mem_write(0, b'\xcd\x20')          # PSP:0 = int 20h, so a final RET exits
    for r in (UC_X86_REG_CS, UC_X86_REG_DS, UC_X86_REG_ES, UC_X86_REG_SS):
        mu.reg_write(r, 0)
    mu.reg_write(UC_X86_REG_SP, 0xFFFE)
    mu.mem_write(0xFFFE, b'\x00\x00')
    if boot:
        # Gercek BIOS'taki gibi: DS/ES/SS:SP ve genel yazmaclar garanti degil.
        # BOOTREGS=hostile ise rastgele degerlerle baslat (program kendi kurmali).
        import os, random
        if os.environ.get('BOOTREGS') == 'hostile':
            rng = random.Random(len(keys) if not callable(keys) else 7)
            for r in (UC_X86_REG_DS, UC_X86_REG_ES):
                mu.reg_write(r, rng.choice([0x0040, 0x07C0, 0x1234, 0xF000]))
            mu.reg_write(UC_X86_REG_SS, rng.choice([0x0030, 0x9000, 0x0000]))
            mu.reg_write(UC_X86_REG_SP, rng.choice([0x00FA, 0x6F00, 0xFFD6]))
            for r in (UC_X86_REG_AX, UC_X86_REG_BX, UC_X86_REG_CX, UC_X86_REG_SI, UC_X86_REG_DI, UC_X86_REG_BP):
                mu.reg_write(r, rng.randrange(65536))
        mu.reg_write(UC_X86_REG_DX, 0x0000)   # DL = acilis surucusu (disket)
    if not boot:
        # DOS COM start registers (commonly relied on by sizecoders)
        mu.reg_write(UC_X86_REG_AX, 0); mu.reg_write(UC_X86_REG_BX, 0)
        mu.reg_write(UC_X86_REG_CX, 0xFF); mu.reg_write(UC_X86_REG_SI, 0x100)
        mu.reg_write(UC_X86_REG_DI, 0xFFFE); mu.reg_write(UC_X86_REG_BP, 0x91C)
    out = []
    RUNS[id(mu)] = out            # ekran tabanli hakem icin: o ana kadar basilanlar
    lazy = callable(keys)
    q = [] if lazy else list(keys)
    state = {'done': False, 'reason': ''}
    def next_key(uc):
        if lazy:
            ch = keys(uc)
            return ch
        return q.pop(0) if q else None

    def hook_intr(uc, intno, user):
        ah = (uc.reg_read(UC_X86_REG_AX) >> 8) & 0xFF
        if intno == 0x10 and ah == 0x0E:
            out.append(chr(uc.reg_read(UC_X86_REG_AX) & 0xFF))
        elif intno == 0x16 and ah in (0x00, 0x10):
            if on_key and not lazy: on_key(uc, len(keys) - len(q))
            ch = next_key(uc)
            if ch is None:
                state['done'] = True; state['reason'] = 'input exhausted'; uc.emu_stop(); return
            uc.reg_write(UC_X86_REG_AX, (scan_code(ord(ch)) << 8) | ord(ch))
        elif intno == 0x21 and ah in (0x01, 0x07, 0x08):
            if on_key and not lazy: on_key(uc, len(keys) - len(q))
            ch = next_key(uc)
            if ch is None:
                state['done'] = True; state['reason'] = 'input exhausted'; uc.emu_stop(); return
            ax = uc.reg_read(UC_X86_REG_AX)
            uc.reg_write(UC_X86_REG_AX, (ax & 0xFF00) | ord(ch))
            if ah == 0x01: out.append(ch)
        elif intno == 0x29:
            out.append(chr(uc.reg_read(UC_X86_REG_AX) & 0xFF))
        elif intno == 0x20 or (intno == 0x21 and ah == 0x4C):
            state['done'] = True; state['reason'] = 'exit'; uc.emu_stop()
        elif intno == 0x21 and ah == 0x02:
            out.append(chr(uc.reg_read(UC_X86_REG_DX) & 0xFF))
        else:
            state['done'] = True; state['reason'] = f'unhandled int {intno:#x} ah={ah:#x}'; uc.emu_stop()

    mu.hook_add(UC_HOOK_INTR, hook_intr)
    if boot:
        # 'jmp $' (EB FE) = oyun bitti, dur. Bunu cikis say.
        i = code.rfind(b'\xeb\xfe')
        if i >= 0:
            def hook_halt(uc, addr, size, user):
                state['done'] = True; state['reason'] = 'exit'; uc.emu_stop()
            mu.hook_add(UC_HOOK_CODE, hook_halt, begin=base + i, end=base + i)
    try:
        mu.emu_start(base, 0xFFFFF, count=max_insn)
        if not state['done']: state['reason'] = 'instruction limit / fell off'
    except UcError as e:
        state['reason'] = f'UcError {e} at {mu.reg_read(UC_X86_REG_IP):#x}'
    return ''.join(out), state['reason'], mu

def board_str(mu, board=0x7F00):
    rows = []
    for r in range(8):
        row = ''
        for c in range(8):
            p = mu.mem_read(board + r * 16 + c, 1)[0]
            t = p & 7
            ch = '.PRBQNK?'[t]
            row += ch.lower() if p & 0x20 else ch
        rows.append(row)
    return '\n'.join(rows)

if __name__ == '__main__':
    path = sys.argv[1]
    script = sys.argv[2] if len(sys.argv) > 2 else ''
    boot = '--boot' in sys.argv
    keys = script.replace(' ', '').replace('|', '\r')
    out, reason, mu = run(path, keys, boot)
    print(out.replace('\r', ''))
    print('--', reason)
    print(board_str(mu))
