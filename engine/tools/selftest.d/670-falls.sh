# L3 falls (21 Nov 2026): the hit lab (kernel/examples/ex_hit_lab) and the shared spec of TLHit, the same in every arm.
#   falls.lab_lint / falls.lab_bot   the lab lints clean and its scripted run completes (9 lab hits, the check, 4 downs, 4 get-ups)
#   falls.lab_spec                   the spec, read from the bot's per-hit numbers (head travel from the frame before the hit):
#                                    every big hit lies AWAY from the blow (lie_away >= 0.4 m), every tap flinches away (>= 0.04 m,
#                                    more away than toward), every solid hit flinches further than the tap from the same side
#   falls.lab_invariants             the lab twice gives the same state hash (it holds a digest of the victims' sockets every frame)
fl_on() { [ -z "$FILTER" ] || [[ "$1" == *"$FILTER"* ]]; }
fl_pack="$EX/ex_hit_lab"
check falls.lab_lint 0 lint "--pack=$fl_pack" -- '"id":"lint.fence","ok":true' '"bypasses":\[\]'
check falls.lab_bot 0 bot "--pack=$fl_pack" --frames=900 -- '"id":"bot.ok","ok":true' '"id":"bot.completed","ok":true'
if fl_on falls.lab_spec; then
  fl_rep="$(report_of falls.lab_bot)"
  command -v cygpath >/dev/null 2>&1 && fl_rep="$(cygpath -m "$fl_rep")"
  fl_why="$(node -e '
    const fs = require("fs"); let r; try { r = JSON.parse(fs.readFileSync(process.argv[1], "utf8")); } catch (e) { console.log("no bot report (run falls.lab_bot)"); process.exit(0); }
    const hits = ((r.bot || {}).result || {}).hits || []; const bad = [];
    if (hits.length !== 10) bad.push(`${hits.length} hits, expected 10`);
    const by = {}; for (const h of hits) by[`${h.side}/${h.strength}`] = h;
    for (const side of ["front", "side", "behind"]) {
      const tap = by[`${side}/0.3`], solid = by[`${side}/0.7`], big = by[`${side}/1.2`];
      if (!tap || !solid || !big) { bad.push(`${side}: a hit is missing`); continue; }
      if (big.lie_away < 0.4) bad.push(`${side} 1.2 lies ${big.lie_away} m away from the blow (< 0.4)`);
      if (tap.away_max < 0.04 || tap.away_max <= tap.toward_max) bad.push(`${side} 0.3 flinch away ${tap.away_max} toward ${tap.toward_max}`);
      if (solid.away_max <= tap.away_max) bad.push(`${side} 0.7 flinch ${solid.away_max} not more than 0.3 ${tap.away_max}`);
    }
    const ck = by["check/1.2"]; if (ck && ck.lie_away < 0.3) bad.push(`check lies ${ck.lie_away} m away from the blow (< 0.3)`);
    console.log(bad.join("; "));' "$fl_rep")"
  verdict falls.lab_spec "$fl_why" "big hits fall away from the blow, flinches away and scaled by strength"
fi
check falls.lab_invariants 0 invariants "--pack=$fl_pack" --frames=900 --bot-frames=900 -- '"id":"invariants.bot_deterministic","ok":true'
