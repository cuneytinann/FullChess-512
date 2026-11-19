#!/bin/bash
# Full regression of every shipped version, boot sector and DOS .COM.
# Usage: bash build.sh && bash test.sh     (requires python3, pip install unicorn chess)
#   KIND=bin or KIND=com runs only one of the two. The 3- and 4-ply .COM tests are slow.
# Referees: tools/targeted.py (targeted cases), tools/fuzz.py (random two-player games),
#           tools/botfuzz.py (human vs computer). All compare against python-chess.
R=$(cd "$(dirname "$0")" && pwd); M=$R/bin; X=$R/bin/extras; cd "$R/tools"
C="BOARDSRC=screen PROMOMAP=qnbr"
r() { local name=$1; shift; local out; out=$(env $C "$@" 2>&1 | tail -n 1); printf '%-30s %s\n' "$name" "$out"; }
for k in ${KIND:-bin com}; do
  B=""; H=""; [ $k = bin ] && B="--boot" && H="BOOTREGS=hostile"
  if [ $k = bin ]; then F=$M/fullchess.bin; P=$M/fullchess-cpu.bin; else F=$M/fchess.com; P=$M/fcvscpu.com; fi
  n=$(basename $F); c=$(basename $P)
  r "$n targeted"            FLIP=1 FIFTY=100 $H python3 targeted.py $F $B
  r "$n random"              FLIP=1 FIFTY=100 $H python3 fuzz.py $F 40 213 --bias $B
  r "$n random(quiet)"       FLIP=1 FIFTY=100 QUIET=0.98 $H python3 fuzz.py $F 40 207 $B
  r "$c"                     SPIN=1 LIGHT=1 ALPHA=br $H python3 botfuzz.py $P 30 217 $B
  r "$c (mate-seeking)"      MATEPREF=1 SPIN=1 LIGHT=1 ALPHA=br $H python3 botfuzz.py $P 20 219 $B
  r "2p.$k targeted"         $H python3 targeted.py $X/2p.$k $B
  r "2p.$k random"           $H python3 fuzz.py $X/2p.$k 60 205 --bias $B
  r "2p50.$k targeted"       FIFTY=100 $H python3 targeted.py $X/2p50.$k $B
  r "2p50.$k random(quiet)"  FIFTY=100 QUIET=0.98 $H python3 fuzz.py $X/2p50.$k 40 207 $B
  r "2pflip.$k targeted"     FLIP=1 $H python3 targeted.py $X/2pflip.$k $B
  r "2pflip.$k random"       FLIP=1 $H python3 fuzz.py $X/2pflip.$k 40 209 --bias $B
  r "2plight.$k targeted"    LIGHT=1 $H python3 targeted.py $X/2plight.$k $B
  r "2plight.$k random"      LIGHT=1 $H python3 fuzz.py $X/2plight.$k 60 201 --bias $B
  r "2plightr.$k targeted"   LIGHT=1 $H python3 targeted.py $X/2plightr.$k $B
  r "2plightr.$k random"     LIGHT=1 $H python3 fuzz.py $X/2plightr.$k 40 203 --bias $B
  for p in cpu2 cpu2or; do
    r "$p.$k"                SPIN=1 LIGHT=1 ALPHA=br $H python3 botfuzz.py $X/$p.$k 30 217 $B
    r "$p.$k (mate-seeking)" MATEPREF=1 SPIN=1 LIGHT=1 ALPHA=br $H python3 botfuzz.py $X/$p.$k 20 219 $B
  done
  r "cpu3or.$k"              MAXINSN=6000000000 SPIN=1 LIGHT=1 ALPHA=br $H python3 botfuzz.py $X/cpu3or.$k 6 221 $B
done
if [ "${KIND:-com}" != bin ]; then
  r "cpu3.com"               MAXINSN=6000000000 SPIN=1 LIGHT=1 ALPHA=br python3 botfuzz.py $X/cpu3.com 6 223
  r "cpu4.com"               MAXINSN=40000000000 SPIN=1 LIGHT=1 ALPHA=br python3 botfuzz.py $X/cpu4.com 4 225
  r "cpu4or.com"             MAXINSN=40000000000 SPIN=1 LIGHT=1 ALPHA=br python3 botfuzz.py $X/cpu4or.com 4 227
fi
