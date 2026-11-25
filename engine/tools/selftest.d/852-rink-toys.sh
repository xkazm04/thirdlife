# The rink game base draws what a user's cartridge puts on the rink and names the teams as the person sees them (lane E1b,
# 25 Nov; E5's real jobs: job 2's slow and fast patches and corner bumpers played on plain ice, job 1's "It's in, for blue!"
# when red scored, job 2's "glare foxes" in lower case).
#   rink.toys          a copy of engine/templates/rink_game whose cartridge has every zone kind (rect and circle, one not
#                      visible) and every obstacle kind: tests/bot_toys.gd plays 2,400 frames and finds every visible zone
#                      painted and every obstacle standing (scripts/rink_toys.gd's counts against the cartridge)
#   rink.team_words    the same copy dressed as a pirate game (teal Sharks against gold Gulls, plural names): bot_skin reads
#                      "Sharks shoot!" / "Clean win for the Gulls." and its pure cases (colour words, casing, verbs) pass
#   rink.top_view      main.gd's "top" camera fits the rink and cuts away everything over 4 m (the hall's trusses and roof)
rk_t="$HERE/../templates/rink_game"
rk_o="$OUT/rink_toys"
if [ -z "$FILTER" ] || [[ "rink.toys" == *"$FILTER"* ]] || [[ "rink.team_words" == *"$FILTER"* ]]; then
  rm -rf "$rk_o"; mkdir -p "$rk_o"; cp -r "$rk_t" "$rk_o/pack"; find "$rk_o/pack" -name "*.uid" -delete
  rk_n="$rk_o/pack"
  if command -v cygpath >/dev/null 2>&1; then rk_n="$(cygpath -m "$rk_n")"; fi
  node -e '
const fs = require("fs"), d = process.argv[1] + "/data/";
const c = JSON.parse(fs.readFileSync(d + "hockey.regular.cartridge.json", "utf8"));
c.id = "toys"; c.title = "Toys";
c.game.teams[0].colour_hex = "#0FB5AE"; c.game.teams[1].colour_hex = "#F2B51D";
c.game.rink.zones = [
  {id: "fast-n", shape: "rect", x: 0, z: 14.5, w: 60, d: 7, kind: "fast_ice", strength: 0.8},
  {id: "slow-ne", shape: "rect", x: 18, z: 6.5, w: 28, d: 7, kind: "slow_ice", strength: 0.9},
  {id: "slow-sw", shape: "circle", x: -18, z: -6.5, r: 5, kind: "slow_ice"},
  {id: "quiet", shape: "rect", x: 30, z: -12, w: 10, d: 8, kind: "no_shoot", strength: 1},
  {id: "boosts", shape: "circle", x: 0, z: -14, r: 4, kind: "boost_only"},
  {id: "spring", shape: "circle", x: -30, z: 12, r: 3, kind: "bumper", strength: 0.7},
  {id: "hidden", shape: "rect", x: 0, z: 0, w: 70, d: 14, kind: "boost_only", visible: false}];
c.game.rink.obstacles = [
  {kind: "bumper", x: 39, z: 15, size: 4}, {kind: "bumper", x: -39, z: -15, size: 4},
  {kind: "pillar", x: -10, z: 18, size: 1.5}, {kind: "box", x: 10, z: -18, size: 1.5},
  {kind: "goal_shield", x: 37, z: 0, size: 2}, {kind: "goal_shield", x: -37, z: 0, size: 2}, {kind: "bumper", x: 39, z: -15, size: 3}];
fs.writeFileSync(d + "toys.cartridge.json", JSON.stringify(c, null, 2));
const m = JSON.parse(fs.readFileSync(d + "match.json", "utf8")); m.cartridge = "toys.cartridge.json"; m.difficulty = "rookie";
fs.writeFileSync(d + "match.json", JSON.stringify(m, null, 2));
const s = JSON.parse(fs.readFileSync(d + "skin.json", "utf8")); s.title = "PIRATE HOCKEY"; s.team_names = ["Sharks", "Gulls"];
fs.writeFileSync(d + "skin.json", JSON.stringify(s, null, 2));
' "$rk_n"
fi
check rink.toys 0 bot "--pack=$rk_o/pack" --test=tests/bot_toys.gd -- '"id":"bot.completed","ok":true' '"id":"bot.ok","ok":true' 'zones 6 of 6, obstacles 7 of 7'
check rink.team_words 0 bot "--pack=$rk_o/pack" --test=tests/bot_skin.gd -- '"id":"bot.ok","ok":true' 'title PIRATE HOCKEY' "'Sharks shoot!' / 'Clean win for the Gulls.'"
if [ -z "$FILTER" ] || [[ "rink.top_view" == *"$FILTER"* ]]; then
  why=""
  for p in "$rk_t" "$HERE/../packs/hokej"; do
    grep -q 'top_cam.near = maxf(0.05, h - TOP_CUT_M)' "$p/scripts/main.gd" || why="${why:+$why; }$p: the top camera does not cut at TOP_CUT_M"
    grep -q '^const TOP_CUT_M: float = 4.0' "$p/scripts/main.gd" || why="${why:+$why; }$p: TOP_CUT_M is not 4 m"
  done
  verdict rink.top_view "$why" "the top view fits the rink, nothing over 4 m drawn"
fi
