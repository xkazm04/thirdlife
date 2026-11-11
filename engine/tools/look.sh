#!/bin/bash
# Look comparison tool (N1): the engine's own frames beside the concept image.
#   look.sh shots <dir>                        capture the fixed set into <dir>: each seed's two cameras at two frames with
#                                              its bot playing (tl.sh capture), plus the kit lab hero (k.sh cap main hero)
#   look.sh sheet <before dir> <after dir> <out.png>
#                                              one sheet: the concept and the two lab heroes on top, then every seed shot as
#                                              a before | after pair (ffmpeg)
#   look.sh px [frames]                        TLCameras.subject_px of each seed's main actor in its play camera, sampled
#                                              every 30 frames of a bot run (headless): min / median / max per seed
#   look.sh one <pack> <cam> <frame> <out.png> one capture with the seed's bot (pack = paddle | drive | wall)
#   look.sh clip <what> <out.mp4> [frames]     P3: a few seconds of motion written with the engine's movie writer
#                                              (--write-movie, 60 fps, 1280x720) and turned into <out>.mp4 and a strip of 8
#                                              frames <out>_strip.png (ffmpeg). <what> =
#                                                paddle | drive | wall   the seed played by its bot, in its own play camera
#                                                tour                    the village tour (world-view --walk=tour)
#                                                hockey                  the hockey pack of site/ (HOCKEY_PACK=<dir> to override)
#                                                rig:<kind>[:<speed>[:<turn>[:<view>]]]  a rig on a marked floor, tracking camera,
#                                                  kind = walk | run | skate | shoot | pass | idle | work | car | bot | fx (all nine effect presets); speed m/s, turn deg/s,
#                                                  view = side | three | front | high   (engine/rigs/review/review.gd)
#   look.sh slip <speed> [mode]                foot slide of a walking or skating biped at <speed> (headless, prints mean/max m/s)
# Env: TL_GODOT (Godot console exe), RES (1920x1080), CLIP_RES (1280x720), GPOS (window position, 0,1440).
HERE="$(cd "$(dirname "$0")" && pwd)"
TL="$HERE/tl.sh"
K="$HERE/k.sh"
ENGINE="$(cd "$HERE/.." && pwd)"
SEEDS="$ENGINE/seeds"
CONCEPT="$ENGINE/../spike/lab/ref/B_toon_ink.png"
RES="${RES:-1920x1080}"
w() { if command -v cygpath >/dev/null 2>&1; then cygpath -m "$1"; else echo "$1"; fi; }

# pack : bot : play camera : captures as cam:frame ...
PACKS=(
  "seed_paddle:tests/bot_win.gd:court:court:400 court:2400 baseline:520 baseline:2000"
  "seed_drive:tests/bot_laps.gd:chase:chase:110 chase:1560 overview:420 overview:1500"
  "seed_wall:tests/bot_knock.gd:player:player:200 player:700 yard:330 yard:900"
)
# the order of the tiles on the sheet (file stems)
STEMS=(paddle_court_f400 paddle_court_f2400 paddle_baseline_f520 paddle_baseline_f2000
       drive_chase_f110 drive_chase_f1560 drive_overview_f420 drive_overview_f1500
       wall_player_f200 wall_player_f700 wall_yard_f330 wall_yard_f900)

bot_of() { for row in "${PACKS[@]}"; do [ "${row%%:*}" = "seed_$1" ] && { rest="${row#*:}"; echo "${rest%%:*}"; }; done; }

case "$1" in
 shots)
  OUT="$2"; [ -z "$OUT" ] && { echo "usage: look.sh shots <dir>"; exit 2; }
  mkdir -p "$OUT"; OUT="$(w "$(cd "$OUT" && pwd)")"
  fail=0
  for row in "${PACKS[@]}"; do
    pack="${row%%:*}"; rest="${row#*:}"; bot="${rest%%:*}"; rest="${rest#*:}"; shots="${rest#*:}"
    for shot in $shots; do
      cam="${shot%%:*}"; frame="${shot##*:}"
      png="$OUT/${pack#seed_}_${cam}_f${frame}.png"
      rm -f "$png"
      TL_QUIET=1 bash "$TL" capture "--pack=$SEEDS/$pack" "--cam=$cam" "--frame=$frame" "--test=$bot" "--res=$RES" "--out=$png" >/dev/null
      if [ -f "$png" ]; then echo "shot $png"; else echo "FAIL $png"; fail=1; fi
    done
  done
  ( RES="$RES" bash "$K" cap main hero --out=tmp_look_hero | grep -E "ERROR|captured" | head -5 )
  if [ -f "$ENGINE/kits_lab/captures/tmp_look_hero.png" ]; then
    mv -f "$ENGINE/kits_lab/captures/tmp_look_hero.png" "$OUT/lab_main_hero.png"; echo "shot $OUT/lab_main_hero.png"
  else echo "FAIL $OUT/lab_main_hero.png"; fail=1; fi
  exit $fail;;

 one)
  pack="$2"; cam="$3"; frame="$4"; out="$5"
  [ -z "$out" ] && { echo "usage: look.sh one <paddle|drive|wall> <cam> <frame> <out.png>"; exit 2; }
  mkdir -p "$(dirname "$out")"; out="$(w "$(cd "$(dirname "$out")" && pwd)")/$(basename "$out")"
  TL_QUIET=1 bash "$TL" capture "--pack=$SEEDS/seed_$pack" "--cam=$cam" "--frame=$frame" "--test=$(bot_of "$pack")" "--res=$RES" "--out=$out" \
    | grep -o '"id":"capture.written","ok":[a-z]*';;

 sheet)
  B="$2"; A="$3"; O="$4"
  [ -z "$O" ] && { echo "usage: look.sh sheet <before dir> <after dir> <out.png>"; exit 2; }
  B="$(w "$(cd "$B" && pwd)")"; A="$(w "$(cd "$A" && pwd)")"
  mkdir -p "$(dirname "$O")"; O="$(w "$(cd "$(dirname "$O")" && pwd)")/$(basename "$O")"
  # a tile: scaled, with a 6 px band on top (red = before, green = after, white = concept)
  inputs=(-i "$(w "$CONCEPT")" -i "$B/lab_main_hero.png" -i "$A/lab_main_hero.png")
  fc="[0]scale=852:480,drawbox=0:0:852:6:white:fill[t0];[1]scale=852:480,drawbox=0:0:852:6:red:fill[t1];[2]scale=852:480,drawbox=0:0:852:6:lime:fill,pad=856:480[t2];[t0][t1][t2]hstack=3[top]"
  n=3; rows=""; r=0
  for ((i = 0; i < ${#STEMS[@]}; i += 2)); do
    s1="${STEMS[$i]}"; s2="${STEMS[$((i + 1))]}"
    inputs+=(-i "$B/$s1.png" -i "$A/$s1.png" -i "$B/$s2.png" -i "$A/$s2.png")
    fc="$fc;[$n]scale=640:360,drawbox=0:0:640:6:red:fill[a$r];[$((n + 1))]scale=640:360,drawbox=0:0:640:6:lime:fill[b$r];[$((n + 2))]scale=640:360,drawbox=0:0:640:6:red:fill[c$r];[$((n + 3))]scale=640:360,drawbox=0:0:640:6:lime:fill[d$r];[a$r][b$r][c$r][d$r]hstack=4[row$r]"
    rows="$rows[row$r]"; n=$((n + 4)); r=$((r + 1))
  done
  fc="$fc;[top]$rows vstack=$((r + 1)),format=rgb24"
  ffmpeg -y -loglevel error "${inputs[@]}" -filter_complex "$fc" "$O" && ls -la "$O";;

 clip)
  what="$2"; out="$3"; nfr="${4:-}"
  [ -z "$out" ] && { echo "usage: look.sh clip <paddle|drive|wall|tour|hockey|rig:...> <out.mp4> [frames]"; exit 2; }
  mkdir -p "$(dirname "$out")"; out="$(w "$(cd "$(dirname "$out")" && pwd)")/$(basename "$out")"
  base="${out%.mp4}"; avi="$base.avi"; rm -f "$avi"
  G="${TL_GODOT:-C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe}"; G="$(w "$G")"
  CR="${CLIP_RES:-1280x720}"; GP="${GPOS:-0,1440}"; E="$(w "$ENGINE")"
  common=(--position "$GP" --resolution "$CR" --rendering-driver d3d12 --fixed-fps 60 --write-movie "$avi" --path "$E")
  case "$what" in
   paddle|drive|wall)
    nfr="${nfr:-300}"
    MSYS_NO_PATHCONV=1 MSYS2_ARG_CONV_EXCL='*' "$G" "${common[@]}" --quit-after "$nfr" res://kernel/host/host.tscn -- worker --mode=bot "--pack=$(w "$SEEDS")/seed_$what" "--test=$(bot_of "$what")" "--frames=$nfr" "--report=$(w "${TMPDIR:-${TEMP:-/tmp}}")/look_clip_$$.json" >/dev/null 2>&1;;
   tour)
    nfr="${nfr:-600}"; tdir="$(w "${TMPDIR:-${TEMP:-/tmp}}")/look_tour_$$"; mkdir -p "$tdir"
    MSYS_NO_PATHCONV=1 MSYS2_ARG_CONV_EXCL='*' "$G" "${common[@]}" --quit-after "$nfr" res://kernel/host/host.tscn -- world-view "--walk=$(w "$ENGINE/kernel/world/walks/tour.json")" "--out-dir=$tdir" >/dev/null 2>&1
    rm -rf "$tdir";;
   hockey)
    nfr="${nfr:-480}"; hp="${HOCKEY_PACK:-$(w "$ENGINE/../../../../site/ice-hockey-three-against-20261111-1/promoted/game.ice_hockey_three_against@0.1.1")}"
    [ -d "$hp" ] || hp="C:/Users/kazda/kiro/third-life/site/ice-hockey-three-against-20261111-1/promoted/game.ice_hockey_three_against@0.1.1"
    MSYS_NO_PATHCONV=1 MSYS2_ARG_CONV_EXCL='*' "$G" "${common[@]}" --quit-after "$nfr" res://kernel/host/host.tscn -- world-view "--packs=$hp" --stage=0 --cam=arena --radius=0 --frame=$((nfr + 600)) "--out=$(w "${TMPDIR:-${TEMP:-/tmp}}")/look_clip_$$.png" >/dev/null 2>&1;;
   rig:*)
    nfr="${nfr:-300}"; IFS=: read -r _ kind rspeed rturn rview <<< "$what"
    case "$kind" in
     walk) ra=(--what=biped --mode=walk --speed="${rspeed:-1.4}");;
     idle) ra=(--what=biped --mode=walk --speed=0.0);;
     work) ra=(--what=biped --mode=walk --speed=0.0 --prop=hammer --clip=work --clip-at=20);;
     run) ra=(--what=biped --mode=walk --speed="${rspeed:-4.2}");;
     skate) ra=(--what=biped --mode=skate --speed="${rspeed:-5}");;
     shoot|pass) ra=(--what=biped --mode=skate --speed="${rspeed:-4}" --clip="$kind" --clip-at=90);;
     car) ra=(--what=car --speed="${rspeed:-14}");;
     bot) ra=(--what=bot --speed="${rspeed:-1.2}");;
     fx) ra=(--what=fx);;
     *) echo "unknown rig kind $kind"; exit 2;;
    esac
    ra+=(--turn="${rturn:-0}" --view="${rview:-side}" --frames="$nfr")
    MSYS_NO_PATHCONV=1 MSYS2_ARG_CONV_EXCL='*' "$G" "${common[@]}" --quit-after "$nfr" res://rigs/review/review.tscn -- "${ra[@]}" >/dev/null 2>&1;;
   *) echo "look.sh clip: unknown <what> '$what'"; exit 2;;
  esac
  if [ ! -s "$avi" ]; then echo "FAIL clip $out (no movie written)"; exit 1; fi
  ffmpeg -y -loglevel error -i "$avi" -c:v libx264 -pix_fmt yuv420p -crf 20 -r 60 "$out" || exit 1
  n="$(ffprobe -v error -count_frames -select_streams v:0 -show_entries stream=nb_read_frames -of csv=p=0 "$avi" 2>/dev/null)"; n="${n:-300}"
  # 8 frames, evenly spaced, in two rows of four
  step=$(( n / 8 > 0 ? n / 8 : 1 ))
  ffmpeg -y -loglevel error -i "$avi" -vf "select=eq(mod(n\,$step)\,0),scale=640:360,tile=4x2" -frames:v 1 -update 1 "${base}_strip.png"
  rm -f "$avi"; echo "clip $out ($n frames) strip ${base}_strip.png";;

 slip)
  G="${TL_GODOT:-C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe}"; G="$(w "$G")"
  MSYS_NO_PATHCONV=1 MSYS2_ARG_CONV_EXCL='*' "$G" --headless --fixed-fps 60 --path "$(w "$ENGINE")" res://rigs/review/review.tscn --quit-after 420 -- --what=biped "--mode=${3:-walk}" "--speed=$2" --frames=400 --slip=1 ${SLIP_K:+--k=$SLIP_K} ${SLIP_A:+--a=$SLIP_A} 2>&1 | grep -a "\[review\]\|SCRIPT ERROR";;

 px)
  frames="${2:-1500}"
  for row in "${PACKS[@]}"; do
    pack="${row%%:*}"; rest="${row#*:}"; bot="${rest%%:*}"; rest="${rest#*:}"; cam="${rest%%:*}"
    TL_LOOK_PX=1 bash "$TL" bot "--pack=$SEEDS/$pack" "--test=$bot" "--frames=$frames" 2>/dev/null | grep -a -o '\[look\] px.*' \
      | awk -v pack="$pack" -v cam="$cam" '$3 == "view=" cam { split($5, kv, "="); v[n++] = kv[2] + 0; split($6, kw, "="); if (kw[2] + 0 > wmax) wmax = kw[2] + 0 }
          END { if (n == 0) { print pack ": no [look] px lines for view " cam; exit }
                for (i = 0; i < n; i++) for (j = i + 1; j < n; j++) if (v[j] < v[i]) { t = v[i]; v[i] = v[j]; v[j] = t }
                printf "%s view=%s samples=%d subject_px min=%.3f median=%.3f max=%.3f (width max=%.3f of frame height)\n", pack, cam, n, v[0], v[int(n / 2)], v[n - 1], wmax }'
  done;;

 *) sed -n '2,11p' "$0"; exit 2;;
esac
