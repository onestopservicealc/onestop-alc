#!/usr/bin/env bash
# สร้างไอคอน GIF (ขยับวนไม่หยุด) + ภาพนิ่ง PNG สำหรับการ์ดระบบ
#
#   bash tools/build-icons.sh                  # อ่านชื่อไอคอนจาก index.html อัตโนมัติ
#   bash tools/build-icons.sh 28-calendar ...  # หรือระบุชื่อเอง
#   FPS=15 bash tools/build-icons.sh           # ลด fps ถ้าไฟล์ใหญ่เกิน/เครื่องช้า
#   STILL=12 bash tools/build-icons.sh 28-calendar   # เลือกเฟรมที่ใช้เป็นภาพนิ่ง
#
# ต้องมีแค่ curl + ffmpeg ไม่ต้องติดตั้งอะไรเพิ่ม
# ชื่อไอคอนดูจาก lordicon.com หมวด wired/lineal (ใช้ชื่อไฟล์ เช่น 2873-megaphone)
set -eo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="$ROOT/icons/sys"
SRC="https://media.lordicon.com/icons/wired/lineal"

SIZE="${SIZE:-136}"      # 2x ของกล่อง .icon (68px) เพื่อให้คมบนจอ retina
FPS="${FPS:-25}"
COLORS="${COLORS:-64}"
STILL="${STILL:-0}"      # เฟรมที่ใช้ทำภาพนิ่ง (ไอคอนชุด lineal เฟรม 0 เป็นรูปสมบูรณ์แล้ว)

names=("$@")
if [ "${#names[@]}" -eq 0 ]; then
  while IFS= read -r n; do names+=("$n"); done < <(
    grep -o 'icon:"[a-z0-9-]*"' "$ROOT/index.html" | cut -d'"' -f2 | sort -u)
fi
[ "${#names[@]}" -gt 0 ] || { echo "ไม่พบชื่อไอคอนใน index.html" >&2; exit 1; }

mkdir -p "$OUT"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT

for n in "${names[@]}"; do
  raw="$TMP/$n.gif"
  printf '→ %s\n' "$n"
  curl -fsSL --retry 2 -o "$raw" "$SRC/$n.gif"
  head -c 3 "$raw" | grep -q GIF || { echo "  ✗ $n: ไม่ใช่ไฟล์ GIF" >&2; exit 1; }

  # 1) GIF ขยับ วนไม่หยุด
  ffmpeg -y -v error -i "$raw" \
    -vf "fps=$FPS,scale=$SIZE:$SIZE:flags=lanczos,split[a][b];[a]palettegen=max_colors=$COLORS:stats_mode=diff[p];[b][p]paletteuse=dither=bayer:bayer_scale=3" \
    -loop 0 "$OUT/$n.gif"

  # 2) ภาพนิ่ง PNG โปร่งใส (ใช้เมื่อผู้ใช้ตั้งค่า "ลดการเคลื่อนไหว")
  ffmpeg -y -v error -i "$raw" \
    -vf "select=eq(n\,$STILL),scale=$SIZE:$SIZE:flags=lanczos,format=rgba" \
    -frames:v 1 -update 1 "$OUT/$n.png"
done

printf '\n'; ls -lh "$OUT" | tail -n +2
printf '\nรวม: '; du -ch "$OUT"/*.gif "$OUT"/*.png | tail -1

printf '\n--- คัดลอกไปแทน ICONS ใน sw.js แล้วเปลี่ยนเลข CACHE ---\nconst ICONS = [\n'
for n in "${names[@]}"; do
  printf "  './icons/sys/%s.gif', './icons/sys/%s.png',\n" "$n" "$n"
done
printf '];\n'
