#!/bin/bash
# Builds every version: boot sector (.bin + 1.44 MB floppy image .img) and DOS .COM.
# Usage: bash build.sh        (requires nasm)
# Main versions go to bin/, the others to bin/extras/.
# DOS names are kept to 8.3 so they run in plain DOS / DOSBox.
set -e
cd "$(dirname "$0")"
mkdir -p bin/extras
lst=$(mktemp); trap 'rm -f "$lst"' EXIT
b() { # boot-name dos-name source flags...
  local boot=$1 dos=$2 src=$3; shift 3
  nasm -f bin "$@" src/$src -o $dos.com
  if nasm -f bin -Dboot "$@" src/$src -o $boot.bin 2>/dev/null; then
    cp $boot.bin $boot.img; truncate -s 1440k $boot.img
    # boot code bytes = address where the padding starts (no padding line when code is exactly 510)
    nasm -f bin -Dboot "$@" src/$src -o /dev/null -l "$lst"; n=$(awk '/times 510/{print $2}' "$lst")
    [[ "$n" =~ ^[0-9A-F]{8}$ ]] && n=$((16#$n)) || n=510
  else n="does-not-fit"; rm -f $boot.bin $boot.img; fi
  printf '%-30s boot %-13s %-24s %s\n' "$boot" "$n" "$dos.com" "$(stat -c%s $dos.com)"
}
echo "== main versions =="
b bin/fullchess             bin/fchess           fullchess.asm     -DFIFTY -DFLIP
b bin/fullchess-cpu         bin/fcvscpu          fullchess-cpu.asm -DPLY=1 -DSPIN
echo "== extras: two players =="
b bin/extras/2p             bin/extras/2p        fullchess.asm
b bin/extras/2p50           bin/extras/2p50      fullchess.asm     -DFIFTY
b bin/extras/2pflip         bin/extras/2pflip    fullchess.asm     -DFLIP
b bin/extras/2plight        bin/extras/2plight   fullchess.asm     -DLIGHT
b bin/extras/2plightr       bin/extras/2plightr  fullchess.asm     -DLIGHT -DREDRAW
echo "== extras: vs computer =="
b bin/extras/cpu2           bin/extras/cpu2      fullchess-cpu.asm -DPLY=2 -DSPIN
b bin/extras/cpu2or         bin/extras/cpu2or    fullchess-cpu.asm -DPLY=2 -DOR2 -DSPIN
b bin/extras/cpu3           bin/extras/cpu3      fullchess-cpu.asm -DPLY=3 -DSPIN
b bin/extras/cpu3or         bin/extras/cpu3or    fullchess-cpu.asm -DPLY=3 -DOR2 -DSPIN
b bin/extras/cpu4           bin/extras/cpu4      fullchess-cpu.asm -DPLY=4 -DSPIN
b bin/extras/cpu4or         bin/extras/cpu4or    fullchess-cpu.asm -DPLY=4 -DOR2 -DSPIN
