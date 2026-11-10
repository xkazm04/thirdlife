#!/bin/bash
# Lane B helper (pattern: gtai-3d-spike/tools/g.sh).
#   g.sh import                      headless import (class cache, shaders are compiled at run time)
#   g.sh cap <cam> [user args...]    one capture -> captures/b_<cam>.png   (hero|site|track|crumble|avatar|map)
#   g.sh stats [user args...]        15 s of the hero view, prints the one-line JSON
#   g.sh run [user args...]          interactive play
#   g.sh movie [name]                20 s movie -> captures/b_<name>.mp4 (relaunches itself with --write-movie)
#   g.sh play_test                   input-driven test (walk, orbit, site_advance, nitro_pass, crumble, reset, collision): PASS/FAIL lines
#   g.sh alt                         hero + site captures of the second layout (data/layout_alt.json)
#   g.sh c                           pass 3: hero + site + track + crumble captures and the play test of the third layout (data/layout_c.json)
#   g.sh validate <name|path>...    pass 4: check layout files against LAYOUT.md (unknown keys are errors); exit code 1 on failure
#   g.sh d                           pass 4: validator + captures + play test of the fourth layout (data/layout_d.json)
#   g.sh pass4                       pass 4: pass3 + validator on all layouts + layout D + the pass-4 sheets
#   g.sh compare                     pass 3 vs pass 4 sheet -> captures/b_pass4_compare.png, concept vs hero -> captures/b_pass4_ref.png
#   g.sh all                         the five captures + overcast hero + stats + movie (the acceptance set)
# Env: RES (default 1920x1080), GPOS (window position, default 0,1440 = secondary screen), TMO (seconds).
G="${GODOT:-/c/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe}"
cd "$(dirname "$0")/.."
RES="${RES:-1920x1080}"
GPOS="${GPOS:-0,1440}"
TMO="${TMO:-90}"
# pass 3: the exit-time leak filter is gone (the leak was fixed in world.gd); leak lines now show if they come back
FILTER='SCRIPT ERROR|ERROR|leaked|still in use|WARNING: .*shader|captured|\[world\]|\[wall\]|^\{|Parse Error|Invalid|movie |\[play_test\]|\[style\]|\[kit\]'
# a new class_name needs the global class cache refreshed: re-import when a script is newer than the cache
CACHE=.godot/global_script_class_cache.cfg
if [ "$1" != "import" ] && [ -n "$(find src -name '*.gd' -newer $CACHE 2>/dev/null | head -1)" ]; then
  timeout 300 "$G" --headless --path . --import >/dev/null 2>&1
fi
case "$1" in
 validate) shift
  # pass 4: layout validator (tools/validate.gd, headless). Args: layout names (main, alt, c, d) or paths to .json files.
  timeout 60 "$G" --headless --path . -s tools/validate.gd -- "$@" 2>&1 | grep -E "\[validate\]|ERROR|usage"; exit ${PIPESTATUS[0]};;
 import)
  timeout 300 "$G" --headless --path . --import 2>&1 | grep -i -E "error|fail" | head -30;;
 cap) shift; cam=$1; shift
  extra=()
  case "$cam" in crumble) extra=(--t=1.5 --fire=crumble);; esac
  timeout $TMO "$G" --path . --position $GPOS --resolution $RES res://look.tscn -- --capture=$cam "${extra[@]}" "$@" 2>&1 | grep -E "$FILTER" | head -${TAIL:-40};;
 stats) shift
  timeout $TMO "$G" --path . --position $GPOS --resolution ${RES_STATS:-2560x1440} res://look.tscn -- --stats "$@" 2>&1 | grep -E "$FILTER" | head -${TAIL:-40};;
 run) shift
  "$G" --path . --position $GPOS --resolution $RES res://look.tscn -- "$@" 2>&1 | grep -E "$FILTER" | head -${TAIL:-40};;
 movie) shift
  n=${1:-movie}; mkdir -p captures
  # pass 3: another GPU process (see BUSY_EXE) makes the movie writer's per-frame readback 10x slower; wait for it to exit
  BUSY_EXE="${BUSY_EXE:-}"; w=0   # pass 4: empty by default; set BUSY_EXE=<image name> to wait for that process
  while [ -n "$BUSY_EXE" ] && [ $w -lt ${MOVIE_WAIT:-150} ] && tasklist //FI "IMAGENAME eq $BUSY_EXE" //FO CSV //NH 2>/dev/null | grep -q -i "$BUSY_EXE"; do sleep 3; w=$((w+3)); done
  [ $w -gt 0 ] && echo "movie: waited $w s for $BUSY_EXE"
  t0=$(date +%s)
  timeout 600 "$G" --path . --position $GPOS --resolution 1920x1080 --fixed-fps 60 --write-movie captures/b_$n.avi res://look.tscn -- --movie-run=$n 2>&1 | grep -E "$FILTER" | head -20
  t1=$(date +%s); echo "movie: recorded 20 s in $((t1-t0)) s (about $((2000/(t1-t0+1))) % of real time; under about 15 % means another GPU process was running)"
  ffmpeg -y -loglevel error -i captures/b_$n.avi -c:v libx264 -crf 20 -pix_fmt yuv420p captures/b_$n.mp4 && rm -f captures/b_$n.avi && ls -la captures/b_$n.mp4;;
 play_test) shift
  timeout 180 "$G" --path . --position $GPOS --resolution 960x540 res://look.tscn -- --play-test "$@" 2>&1 | grep -E "$FILTER" | head -60;;
 alt)
  "$0" cap hero --layout=alt --out=alt_hero
  "$0" cap site --layout=alt --out=alt_site;;
 c)
  for c in hero site track crumble; do "$0" cap $c --layout=c --out=c_$c; done
  "$0" play_test --layout=c;;
 d)
  # pass 4: the fourth layout (data/layout_d.json, written from LAYOUT.md with the code frozen): validate + captures + play test
  "$0" validate d
  for c in hero site track crumble; do "$0" cap $c --layout=d --out=d_$c; done
  "$0" play_test --layout=d;;
 altfull)
  for c in hero site track crumble avatar; do "$0" cap $c --layout=alt --out=alt_$c; done
  "$0" play_test --layout=alt;;
 compare)
  # pass 4: pass 3 (captures/pass3_orig) against the current frames: hero, site, track, avatar front; and the concept beside the hero
  O=captures/pass3_orig
  "$0" cap avatar_front --out=avatar_front | grep -v captured
  ffmpeg -y -loglevel error -i $O/b_hero.png -i captures/b_hero.png -i $O/b_site.png -i captures/b_site.png -i $O/b_track.png -i captures/b_track.png -i $O/b_avatar_front.png -i captures/b_avatar_front.png    -filter_complex "[0]scale=960:540[a];[1]scale=960:540[b];[2]scale=960:540[c];[3]scale=960:540[d];[4]scale=960:540[e];[5]scale=960:540[f];[6]scale=960:540[g];[7]scale=960:540[h];[a][b]hstack[r0];[c][d]hstack[r1];[e][f]hstack[r2];[g][h]hstack[r3];[r0][r1][r2][r3]vstack=inputs=4,format=rgb24" captures/b_pass4_compare.png && ls -la captures/b_pass4_compare.png
  ffmpeg -y -loglevel error -i ../ref/B_toon_ink.png -i captures/b_hero.png -filter_complex "[0]scale=-2:720[a];[1]scale=-2:720[b];[a][b]hstack,format=rgb24" captures/b_pass4_ref.png && ls -la captures/b_pass4_ref.png;;
 pass4)
  # pass 4 acceptance: the validator on every layout, everything pass 3 ran, then layout D (validator, captures, play test)
  "$0" validate main alt c d || echo "FAIL validate"
  "$0" pass3
  "$0" d;;
 faces)
  for f in "1,0 happy" "0,0 focus" "1,1 blink"; do set -- $f; "$0" cap face --face=$1 --out=tmp_face_$2 | grep -v captured; done
  ffmpeg -y -loglevel error -i captures/b_tmp_face_happy.png -i captures/b_tmp_face_focus.png -i captures/b_tmp_face_blink.png -filter_complex "[0]crop=1080:1080:420:0,scale=640:640[a];[1]crop=1080:1080:420:0,scale=640:640[b];[2]crop=1080:1080:420:0,scale=640:640[c];[a][b][c]hstack=inputs=3" captures/b_avatar_faces.png && rm -f captures/b_tmp_face_*.png && ls -la captures/b_avatar_faces.png;;
 pass3)
  "$0" all; "$0" altfull; "$0" c; "$0" faces
  "$0" cap avatar_front --out=avatar_front; "$0" cap avatar_back --out=avatar_back; "$0" cap map;;
 all)
  for c in hero site track crumble avatar; do "$0" cap $c; done
  "$0" alt
  "$0" play_test
  "$0" compare
  "$0" cap hero --style=overcast --out=hero_overcast
  "$0" stats
  "$0" movie;;
 *) sed -n '2,10p' "$0";;
esac
