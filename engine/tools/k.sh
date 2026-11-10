#!/bin/bash
# Kit, rig and style helper (the WP2 lab tool, moved into the engine project by WP4).
#   k.sh import                    headless import (refreshes the global class cache; the other commands do it when a script changed)
#   k.sh validate [file.json ...]  validate both style files and every layout in kits_lab/layouts (or the given layout files); exit 1 on failure
#   k.sh selftest                  headless: every part (defaults + random valid params, twice, equal hashes), every rig and clip
#                                  (120 frames), budgets; one PASS/FAIL line per case; exit 1 on failure
#   k.sh sheet [name]              windowed captures -> kits_lab/captures/: parts_sheet, biped_clips, biped_skate_chase, vehicle_sheet,
#                                  bot_sheet, rig_turntables, fracture_sheet, collision_sheet, biped_params (no name = all of them)
#   k.sh cap <layout> <cam> [user args]   windowed capture of kits_lab/layouts/<layout>.json -> kits_lab/captures/layout_<layout>_<cam>.png
#   k.sh stats <layout> [cam]      one JSON line: triangles and draw calls of a layout at 2560x1440
#   k.sh owed                      every image the brief asks for (sheets, layout_two_rinks, port comparison, style_swap)
#   k.sh docs                      regenerate the generated tables of kits/KIT.md and rigs/RIGS.md from the specs
#   k.sh swaptest                  one run that starts golden and swaps to overcast at frame 20 -> kits_lab/captures/style_swap_runtime.png
# Env: TL_GODOT (Godot console exe), RES (1920x1080), GPOS (window position, 0,1440), TMO (seconds per run).
G="${TL_GODOT:-/c/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe}"
cd "$(dirname "$0")/.."   # the engine project (kit, rigs and style live in engine/ since WP4)
RES="${RES:-1920x1080}"
GPOS="${GPOS:-0,1440}"
TMO="${TMO:-120}"
FILTER='SCRIPT ERROR|ERROR|WARNING|leaked|still in use|captured|\[lab\]|\[layout\]|\[style\]|^\{|Parse Error|Invalid|PASS|FAIL|\[selftest\]|\[validate\]'
CACHE=.godot/global_script_class_cache.cfg
if [ "$1" != "import" ] && { [ ! -f $CACHE ] || [ -n "$(find kernel kits rigs style kits_lab -name '*.gd' -newer $CACHE 2>/dev/null | head -1)" ]; }; then
  timeout 300 "$G" --headless --path . --import >/dev/null 2>&1
fi
win() { timeout $TMO "$G" --path . --position $GPOS --resolution $RES res://kits_lab/lab.tscn -- "$@" 2>&1 | grep -E "$FILTER" | head -${TAIL:-40}; }
case "$1" in
 import)
  timeout 300 "$G" --headless --path . --import 2>&1 | grep -i -E "error|fail" | head -30;;
 validate) shift
  timeout 120 "$G" --headless --path . -s kits_lab/tools/validate.gd -- "$@" 2>&1 | grep -E "\[validate\]|ERROR|usage"; exit ${PIPESTATUS[0]};;
 selftest) shift
  timeout 600 "$G" --headless --path . -s kits_lab/tools/selftest.gd -- "$@" 2>&1 | grep -E "PASS|FAIL|ERROR|\[selftest\]|WARNING"; exit ${PIPESTATUS[0]};;
 sheet) shift
  mkdir -p kits_lab/captures
  for s in ${1:-parts biped_clips biped_chase vehicle bot turntable fracture collision biped_params}; do
   case "$s" in
    parts)
     win --sheet=parts --page=0; win --sheet=parts --page=1
     ffmpeg -y -loglevel error -i kits_lab/captures/tmp_parts_0.png -i kits_lab/captures/tmp_parts_1.png -filter_complex "[0][1]vstack,format=rgb24" kits_lab/captures/parts_sheet.png && rm -f kits_lab/captures/tmp_parts_*.png && ls -la kits_lab/captures/parts_sheet.png;;
    biped_clips) win --sheet=biped_clips --out=biped_clips;;
    biped_chase) win --sheet=biped_chase --out=biped_skate_chase;;
    vehicle) win --sheet=vehicle --out=vehicle_sheet;;
    bot) win --sheet=bot --out=bot_sheet;;
    turntable) win --sheet=turntable --out=rig_turntables;;
    fracture) win --sheet=fracture --out=fracture_sheet;;
    biped_params) win --sheet=biped_params --out=biped_params;;
    collision) win --sheet=collision --out=collision_sheet;;
    *) echo "unknown sheet $s";;
   esac
  done;;
 cap) shift; lay=$1; cam=$2; shift; shift
  mkdir -p kits_lab/captures
  win --layout=$lay --cam=$cam "$@";;
 stats) shift
  RES=2560x1440 win --layout=$1 --cam=${2:-hero} --stats --out=tmp_stats; rm -f kits_lab/captures/tmp_stats.png;;
 docs)
  timeout 120 "$G" --headless --path . -s kits_lab/tools/gen_docs.gd 2>&1 | grep -E "\[docs\]|ERROR";;
 swaptest)
  win --layout=main --cam=hero --swap-at=20 --out=style_swap_runtime;;
 owed)
  "$0" sheet
  "$0" cap two_rinks hero --out=layout_two_rinks
  "$0" cap main hero --out=tmp_port_main
  ffmpeg -y -loglevel error -i kits_lab/captures/tmp_port_main.png -i ../spike/lab/b/captures/director/pass4_builder/b_hero.png -filter_complex "[0]scale=1920:1080[a];[1]scale=1920:1080[b];[a][b]hstack,format=rgb24" kits_lab/captures/port_main_vs_laneb.png && rm -f kits_lab/captures/tmp_port_main.png && ls -la kits_lab/captures/port_main_vs_laneb.png
  "$0" cap main hero --out=tmp_swap_golden
  "$0" cap main hero --style=overcast --out=tmp_swap_overcast
  ffmpeg -y -loglevel error -i kits_lab/captures/tmp_swap_golden.png -i kits_lab/captures/tmp_swap_overcast.png -filter_complex "[0][1]hstack,format=rgb24" kits_lab/captures/style_swap.png && rm -f kits_lab/captures/tmp_swap_*.png && ls -la kits_lab/captures/style_swap.png;;
 *) sed -n '2,14p' "$0";;
esac
