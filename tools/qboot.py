#!/usr/bin/env python3
"""Boot imajini gercek QEMU+SeaBIOS'ta ac, monitor uzerinden tus gonder, ekran goruntusu al.
usage: qboot.py image.bin keys out.png [--hd]   (gerekli: qemu-system-i386, pillow)"""
import sys, os, socket, subprocess, time, tempfile
img, keys, out = sys.argv[1], sys.argv[2], sys.argv[3]
hd = '--hd' in sys.argv
work = tempfile.mkdtemp(prefix='qboot_')
data = open(img, 'rb').read()
if hd:
    path = f'{work}/disk.img'; open(path, 'wb').write(data)
    drive = ['-drive', f'file={path},format=raw,if=ide', '-boot', 'c']
else:
    path = f'{work}/floppy.img'; open(path, 'wb').write(data + b'\0' * (1474560 - len(data)))
    drive = ['-drive', f'file={path},format=raw,if=floppy', '-boot', 'a']
sock = f'{work}/mon.sock'
if os.path.exists(sock): os.remove(sock)
q = subprocess.Popen(['qemu-system-i386', '-m', '4', *drive, '-display', 'none', '-vga', 'std',
                      '-monitor', f'unix:{sock},server,nowait'], stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
for _ in range(100):
    if os.path.exists(sock): break
    time.sleep(0.05)
s = socket.socket(socket.AF_UNIX); s.connect(sock)
def cmd(c):
    s.sendall((c + '\n').encode()); time.sleep(0.12)
    try:
        s.settimeout(0.2); return s.recv(65536).decode(errors='replace')
    except Exception: return ''
time.sleep(2.5)                                   # BIOS + acilis
names = {'\r': 'ret', ' ': 'spc'}
for ch in keys:
    cmd('sendkey ' + names.get(ch, ch))
time.sleep(1.0)
cmd(f'screendump {work}/s.ppm'); time.sleep(0.5)
q.terminate(); q.wait()
subprocess.run(['python3', '-c', f"from PIL import Image; Image.open('{work}/s.ppm').save('{out}')"], check=True)
print('ok ->', out)
