#!/bin/bash
# asepal - ~/dot-e-kyoshitsu に次番号の Sprite-NNNN.ase を作り、パレットを書き込む
# 使い方: asepal -c 985E30 A58035 ...   （# は付いていても無くても可）
# 仕様: 32x32 / RGBA / 透明背景 / レイヤー1枚（空）/ 1フレーム
set -eu

DIR="$HOME/dot-e-kyoshitsu"
W=32
H=32

usage() { echo "usage: asepal -c hex1 hex2 ..." >&2; exit 1; }

[ "${1:-}" = "-c" ] || usage
shift
[ $# -ge 1 ] || usage
[ $# -le 256 ] || { echo "error: 色は256色まで" >&2; exit 1; }

# 色の検証
COLORS=()
for c in "$@"; do
  h="${c#\#}"
  case "$h" in
    [0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f]) COLORS+=("$h") ;;
    *) echo "error: 不正なhex: $c" >&2; exit 1 ;;
  esac
done
N=${#COLORS[@]}

# 次の番号を決める
mkdir -p "$DIR"
max=0
for f in "$DIR"/Sprite-[0-9][0-9][0-9][0-9].ase; do
  [ -e "$f" ] || continue
  n="${f##*/Sprite-}"; n="${n%.ase}"
  n=$((10#$n))
  [ "$n" -gt "$max" ] && max=$n
done
OUT=$(printf '%s/Sprite-%04d.ase' "$DIR" $((max + 1)))

# バイナリ書き出し用ヘルパー（リトルエンディアン）
u8()  { printf "\\$(printf '%03o' "$1")"; }
u16() { u8 $(( $1 & 255 )); u8 $(( ($1 >> 8) & 255 )); }
u32() { u16 $(( $1 & 65535 )); u16 $(( ($1 >> 16) & 65535 )); }
zeros() { head -c "$1" /dev/zero; }
fsize() { wc -c < "$1" | tr -d ' '; }

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

# --- Layer chunk (0x2004) ---
{
  u16 3        # flags: visible | editable
  u16 0        # type: normal
  u16 0        # child level
  u16 0; u16 0 # default w/h (ignored)
  u16 0        # blend mode: normal
  u8 255       # opacity
  zeros 3
  name="Layer 1"
  u16 ${#name}; printf '%s' "$name"
} > "$TMP/layer.body"

# --- Old palette chunk (0x0004) 互換用 ---
{
  u16 1        # packets
  u8 0         # skip
  u8 $(( N == 256 ? 0 : N ))
  for h in "${COLORS[@]}"; do
    u8 $((16#${h:0:2})); u8 $((16#${h:2:2})); u8 $((16#${h:4:2}))
  done
} > "$TMP/oldpal.body"

# --- Palette chunk (0x2019) ---
{
  u32 "$N"     # palette size
  u32 0        # first index
  u32 $((N - 1)) # last index
  zeros 8
  for h in "${COLORS[@]}"; do
    u16 0      # entry flags (no name)
    u8 $((16#${h:0:2})); u8 $((16#${h:2:2})); u8 $((16#${h:4:2})); u8 255
  done
} > "$TMP/pal.body"

chunk() { # $1=type $2=bodyfile
  u32 $(( $(fsize "$2") + 6 )); u16 "$1"; cat "$2"
}

{
  chunk $((0x0004)) "$TMP/oldpal.body"
  chunk $((0x2019)) "$TMP/pal.body"
  chunk $((0x2004)) "$TMP/layer.body"
} > "$TMP/chunks"
NCHUNKS=3

# --- Frame ---
{
  u32 $(( $(fsize "$TMP/chunks") + 16 ))
  u16 $((0xF1FA))
  u16 $NCHUNKS
  u16 100      # duration ms
  zeros 2
  u32 $NCHUNKS
  cat "$TMP/chunks"
} > "$TMP/frame"

# --- Header (128 bytes) ---
{
  u32 $(( $(fsize "$TMP/frame") + 128 ))
  u16 $((0xA5E0))
  u16 1        # frames
  u16 $W; u16 $H
  u16 32       # color depth: RGBA
  u32 1        # flags
  u16 100      # speed (deprecated)
  u32 0; u32 0
  u8 0         # transparent index
  zeros 3
  u16 $(( N == 256 ? 0 : N ))
  u8 1; u8 1   # pixel ratio
  u16 0; u16 0 # grid x/y
  u16 16; u16 16 # grid w/h
  zeros 84
  cat "$TMP/frame"
} > "$TMP/out.ase"

mv "$TMP/out.ase" "$OUT"
echo "$OUT ($N colors)"
