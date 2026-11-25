# A game's own commentary line with no voice is said as text only, never an error (lane H2b, 25 Nov). G1's Arsenal threw
# "rink audio: no voice for commentary line ..." in every window, in every version, while every headless check passed (the
# booth speaks only on a drawn frame).
#   rink.voice_none         cores/rink/audio/review/voice_none_case.gd, headless: a voiced line, a line with no voice, the voiced
#                           one again: "voice", "voice_none", "voice" rows, and no ERROR printed
#   rink.voice_none_window  a copy of engine/templates/rink_game whose skin brings its own commentary bank (no line of it voiced),
#                           captured IN A WINDOW at frame 600 with the HUD on (the faceoff's line is said at about frame 90):
#                           the capture passes (no script error); the still is $OUT/rink_voice_none/still.png
if [ -z "$FILTER" ] || [[ "rink.voice_none" == *"$FILTER"* ]]; then
  why=""; note=""
  vn_g="${TL_GODOT:-C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe}"
  vn_e="$(cd "$HERE/.." && pwd)"; command -v cygpath >/dev/null 2>&1 && vn_e="$(cygpath -am "$vn_e")"
  vn_out="$(MSYS_NO_PATHCONV=1 timeout 300 "$vn_g" --headless --path "$vn_e" --script res://cores/rink/audio/review/voice_none_case.gd 2>&1 | tr -d '\015')"
  vn_l="$(echo "$vn_out" | grep -m1 '^VOICENONE')"
  [[ "$vn_l" == "VOICENONE ok=true"* ]] || why="${vn_l:-no VOICENONE line (the run stopped)}"
  vn_err="$(echo "$vn_out" | grep -m1 'ERROR')"
  [ -z "$vn_err" ] || why="${why:+$why; }an error was printed: $vn_err"
  note="$(echo "$vn_l" | cut -c19-200)"
  verdict rink.voice_none "$why" "$note"
fi

vn_t="$HERE/../templates/rink_game"
vn_o="$OUT/rink_voice_none"
if [ -z "$FILTER" ] || [[ "rink.voice_none_window" == *"$FILTER"* ]]; then
  rm -rf "$vn_o"; mkdir -p "$vn_o"; cp -r "$vn_t" "$vn_o/pack"; find "$vn_o/pack" -name "*.uid" -delete
  vn_n="$vn_o/pack"; vn_still="$vn_o/still.png"
  if command -v cygpath >/dev/null 2>&1; then vn_n="$(cygpath -m "$vn_n")"; vn_still="$(cygpath -m "$vn_still")"; fi
  node -e '
const fs = require("fs"), d = process.argv[1] + "/data/";
const lines = [];
for (const [i, t] of ["The pond is open.", "Here we go on the pond.", "Puck down, skates out."].entries()) lines.push(["pond.faceoff.drop.0" + (i + 1), "faceoff", "drop", "any", 2, 480, t, 90]);
for (const [i, t] of ["In! What a finish on the pond.", "It is in. The pond roars."].entries()) lines.push(["pond.goal.any.0" + (i + 1), "goal", "", "any", 5, 120, t, 120]);
fs.writeFileSync(d + "pond_commentary.json", JSON.stringify({ note: "a game of its own words: no line of it has a voice", lines }, null, 1));
const s = JSON.parse(fs.readFileSync(d + "skin.json", "utf8")); s.commentary = "pond_commentary.json";
fs.writeFileSync(d + "skin.json", JSON.stringify(s, null, 2));
' "$vn_n"
fi
check rink.voice_none_window 0 capture "--pack=$vn_o/pack" --cam=follow --frame=600 --res=1280x720 --hud=on --test=tests/bot_match_hand.gd "--out=$vn_still" -- '"ok":true,"outcome":"passed"'
