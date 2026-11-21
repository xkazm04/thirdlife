# Day of 21 Nov 2026, lane L6 (crisp-harden): the open items of the night's L1. Headless Godot runs (frames, not wall
# clock), one per script; each prints `HARDEN <case> ok|fail <detail>`.
#   harden.road_edge   every scatter object (trees, rocks, bushes, pad rocks, grass) of the exe's and the wf_feel village,
#                      by its drawn mesh, and every tree/rock/bush trunk of the visitor's space: off every road's surface
#                      by the exact distance to its line; solid ones also off crisp's verge and rails (crisp and classic)
#                      (kernel/world/terrain/harden_day_case.gd)
#   harden.lot_props   every prop of a plain lot (crane, scaffold, timber, pallets, barricades, cones), walked into from 8
#                      sides: he stops at what is drawn, never into it, never held more than 0.45 m before it (same run)
#   harden.rock_tops   every scatter rock with a body: its top over the rock's middle is the drawn top within 0.25 m (same
#                      run; a 1.4 m pillar stood over every rock)
#   harden.kit_tops    every kit part, straight and turned 30 degrees: its collider's top is its mesh's top within 0.12 m
#                      wherever a 0.25 m foot could stand (no ledge in the air, no hole), parts that differ on purpose
#                      named with why (kernel/world/terrain/kit_tops_case.gd)
HARDEN_DAY_RUNS="harden.road_edge,harden.lot_props,harden.rock_tops=harden_day_case harden.kit_tops=kit_tops_case"
GH="${TL_GODOT:-C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe}"
for hrun in $HARDEN_DAY_RUNS; do
  hcases="${hrun%%=*}"; hscript="${hrun#*=}"
  if [ -n "$FILTER" ] && [[ "$hcases" != *"$FILTER"* ]]; then continue; fi
  EH="$(cd "$HERE/.." && pwd)"; command -v cygpath >/dev/null 2>&1 && EH="$(cygpath -m "$EH")"
  # the Godot run's own exit status is read (PIPESTATUS): anything but 0 is a stopped run and every case of it FAILs
  hy_out="$(MSYS_NO_PATHCONV=1 timeout 600 "$GH" --headless --path "$EH" --script "res://kernel/world/terrain/$hscript.gd" 2>&1 | tr -d '\015'; echo "HARDENRC ${PIPESTATUS[0]}")"
  hy_rc="$(echo "$hy_out" | sed -n 's/^HARDENRC //p' | tail -1)"
  for hc in ${hcases//,/ }; do
    hl="$(echo "$hy_out" | grep -m1 "^HARDEN $hc ")"
    why=""; [[ "$hl" == "HARDEN $hc ok"* ]] || why="${hl:-no HARDEN $hc line (the run stopped: $(echo "$hy_out" | grep -m1 'SCRIPT ERROR' | cut -c1-120))}"
    if [ "$hy_rc" != 0 ]; then why="the case run stopped (Godot exit ${hy_rc:-unknown}) ${hl:+after: $hl}"; fi
    verdict "$hc" "$why" "${hl#HARDEN $hc ok }"
  done
done
# harden.site_waits: the site fixtures of blocks 501 and 502 (site/fixtures/no_ring.gd, editor_yaw.gd) wait for the site's
# worker meshes (site/draw.gd `wait_meshes`), not for a number of frames: each finishes inside --quit-after 120. Before,
# editor_yaw counted frames while the worker built (thousands at an idle machine's spin; 502 ran out of its 12000 on a
# busy one and printed neither OK nor an error).
if [ -z "$FILTER" ] || [[ "harden.site_waits" == *"$FILTER"* ]]; then
  sw_engine="$(cd "$HERE/.." && pwd)"
  why=""
  if ! sw_dir="$(mktemp -d "$OUT/site-waits-XXXXXX")"; then why="could not create a directory"; fi
  if [ -z "$why" ] && command -v cygpath >/dev/null 2>&1; then sw_dir="$(cygpath -am "$sw_dir")"; sw_engine="$(cygpath -am "$sw_engine")"; fi
  if [ -z "$why" ]; then
    # the same four job logs block 502 writes (legacy, zero, job, draft)
    node -e '
const fs = require("node:fs");
const [engine, dir] = process.argv.slice(1);
const lines = fs.readFileSync(engine + "/kernel/world/site/fixtures/arrive/job.jsonl", "utf8").split(/\r?\n/).slice(0, 8);
for (const source of ["legacy", "zero", "job", "draft"]) {
  const created = JSON.parse(lines[0]);
  created.sentence += " " + source;
  const lot = {at: [5, -12], radius: 32, yaw_deg: source === "zero" ? 0 : 30};
  if (source === "draft") {
    fs.mkdirSync(dir + "/_editor");
    fs.writeFileSync(dir + "/_editor/test.json", JSON.stringify({schema: "tl.editor-draft/1", request: created.sentence, lot}));
  } else if (source !== "legacy") created.lot = lot;
  fs.mkdirSync(dir + "/" + source);
  fs.writeFileSync(dir + "/" + source + "/job.jsonl", [JSON.stringify(created), ...lines.slice(1), ""].join("\n"));
}' "$sw_engine" "$sw_dir" || why="could not prepare the job logs"
  fi
  if [ -z "$why" ]; then
    MSYS_NO_PATHCONV=1 "$GH" --headless --fixed-fps 60 --quit-after 120 --path "$sw_engine" \
      --script res://kernel/world/site/fixtures/editor_yaw.gd -- "$sw_dir" >"$sw_dir/yaw.log" 2>&1 || why="editor_yaw: Godot exited $?"
    grep -q '^SITE EDITOR YAW OK' "$sw_dir/yaw.log" || why="${why:+$why; }editor_yaw did not finish in 120 frames: $(grep -m1 -E '^(SCRIPT ERROR|ERROR):' "$sw_dir/yaw.log")"
    MSYS_NO_PATHCONV=1 "$GH" --headless --fixed-fps 60 --quit-after 120 --path "$sw_engine" \
      --script res://kernel/world/site/fixtures/no_ring.gd >"$sw_dir/ring.log" 2>&1 || why="${why:+$why; }no_ring: Godot exited $?"
    grep -q '^SITE RAILS OK' "$sw_dir/ring.log" || why="${why:+$why; }no_ring did not finish in 120 frames: $(grep -m1 -E '^(SCRIPT ERROR|ERROR):' "$sw_dir/ring.log")"
  fi
  verdict harden.site_waits "$why" "editor_yaw (7 site builds) and no_ring (build and refit) finish inside 120 frames: worker meshes waited for, not counted in frames"
  [ -n "$sw_dir" ] && rm -rf -- "$sw_dir"
fi
# harden.site_fixtures: every top-level entry of kernel/world/site/fixtures/ (but .uid files and the README) has a row in
# its README.md, and every "Run by" file of a row exists and names the fixture (its name, or the fixtures directory when
# it reads all of them): a fixture nobody runs, or a new one nobody owns, fails here (no README: every one fails).
if [ -z "$FILTER" ] || [[ "harden.site_fixtures" == *"$FILTER"* ]]; then
  sf_engine="$(cd "$HERE/.." && pwd)"; command -v cygpath >/dev/null 2>&1 && sf_engine="$(cygpath -am "$sf_engine")"
  sf_out="$(node -e '
const fs = require("node:fs"), path = require("node:path");
const engine = process.argv[1], dir = engine + "/kernel/world/site/fixtures";
const entries = fs.readdirSync(dir).filter(n => !n.endsWith(".uid") && n !== "README.md").sort();
const readme = fs.existsSync(dir + "/README.md") ? fs.readFileSync(dir + "/README.md", "utf8") : "";
const rows = {};
for (const line of readme.split(/\r?\n/)) {
  const m = line.match(/^\| `([^`]+)` \|[^|]*\| ([^|]*) \|/);
  if (m) rows[m[1].replace(/\/$/, "")] = [...m[2].matchAll(/`([^`]+)`/g)].map(x => x[1]);
}
const bad = [];
for (const n of entries) {
  const stem = n.replace(/\.[a-z]+$/, "");
  if (!rows[n]) { bad.push(n + ": no row in fixtures/README.md"); continue; }
  if (rows[n].length === 0) bad.push(n + ": its row names nothing that runs it");
  for (const f of rows[n]) {
    const p = path.join(engine, f);
    if (!fs.existsSync(p)) { bad.push(n + ": " + f + " does not exist"); continue; }
    const t = fs.readFileSync(p, "utf8");
    if (!(t.includes(stem) || t.includes("site/fixtures") || t.includes("$FX") || t.includes("FIXTURES"))) bad.push(n + ": " + f + " does not name it");
  }
}
for (const r of Object.keys(rows)) if (!entries.includes(r)) bad.push(r + ": a README row for a fixture that is not there");
console.log(bad.length ? "FAIL " + bad.length + " of " + entries.length + ": " + bad.slice(0, 6).join("; ") : "OK " + entries.length + " fixtures, each with its row and the files that run it");
' "$sf_engine" 2>&1)"
  why=""; [[ "$sf_out" == OK* ]] || why="${sf_out:-the check did not run}"
  verdict harden.site_fixtures "$why" "${sf_out#OK }"
fi
