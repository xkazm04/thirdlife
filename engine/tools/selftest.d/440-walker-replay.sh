# Lane walker round 2 (night of 19 Nov 2026), two determinism defects of hunt2 (lanes/hunt2/findings.md):
# world.site_warm_cache (B2): the same site walk run cold and then on the warm site cache gives the same game ticks and
# state hash (the scheduler footprint came back from the cached display radius). runner.input_backslash (B4): a replay
# from a Windows path finds the game's stage recording (engine/kernel/runner/walker_replay_case.gd). Headless.

if [ -z "$FILTER" ] || [[ "world.site_warm_cache" == *"$FILTER"* ]]; then
  GG="${TL_GODOT:-C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe}"
  EG="$(cd "$HERE/.." && pwd)"; command -v cygpath >/dev/null 2>&1 && EG="$(cygpath -m "$EG")"
  wr_dir="$OUT/walker_site_cache"; rm -rf "$wr_dir"; mkdir -p "$wr_dir"
  wr_dirm="$wr_dir"; command -v cygpath >/dev/null 2>&1 && wr_dirm="$(cygpath -m "$wr_dir")"
  # the hunt2 B2 walk: the shipped arrival fixture, the lot enlarged to 45 m, the visitor crossing the tier edge
  node -e '
    const fs = require("fs");
    const w = JSON.parse(fs.readFileSync(process.argv[1], "utf8"));
    Object.assign(w.landscape.lots[0], {radius: 45, replay: {ticks_per_event: 1}});
    Object.assign(w, {ticks: 240, player: [[0, [40, 0, 4]], [40, [40, 0, 4]], [45, [105, 0, 0]], [240, [105, 0, 0]]], events: []});
    w.tiers.dwell_ticks = 1;
    fs.writeFileSync(process.argv[2], JSON.stringify(w));
  ' "$EG/kernel/world/site/fixtures/site_arrive.json" "$wr_dirm/walk.json"
  wr_res=()
  for wr_run in cold warm; do
    wr_out="$(MSYS_NO_PATHCONV=1 TL_CACHE_DIR="$wr_dirm" APPDATA="$wr_dirm" timeout 180 "$GG" --headless --fixed-fps 60 --path "$EG" \
      --log-file "$wr_dirm/godot_$wr_run.log" res://kernel/host/host.tscn -- world --child=true --load=step "--walk=$wr_dirm/walk.json" 2>&1 | tr -d '\015')"
    wr_res+=("$(echo "$wr_out" | node -e '
      let s = ""; process.stdin.on("data", d => s += d).on("end", () => {
        const lines = s.split("\n");
        const p = lines.filter(l => l.startsWith("{")).map(l => { try { return JSON.parse(l); } catch (e) { return {}; } })
          .find(r => r.kind === "pack" && r.plot === "site_0");
        const st = lines.find(l => l.startsWith("[site] {"));
        const site = st ? JSON.parse(st.slice(7)).sites[0] : null;
        const err = lines.some(l => l.startsWith("SCRIPT ERROR"));
        if (!p || !site || err) { console.log("none"); return; }
        console.log(`${p.frames} ${p.state_hash} events=${site.events} arrived=${site.arrived_at} radius=${site.radius_before}`);
      });')")
  done
  why=""
  if [ "${wr_res[0]}" = "none" ] || [ "${wr_res[1]}" = "none" ] || [ -z "${wr_res[1]}" ]; then why="a run did not finish with a site_0 pack line (cold: ${wr_res[0]}; warm: ${wr_res[1]})"
  elif [[ "${wr_res[0]}" != *"events=21 arrived=19"* ]] || [[ "${wr_res[1]}" != *"events=21 arrived=19"* ]]; then why="the site did not arrive as the fixture says (cold: ${wr_res[0]}; warm: ${wr_res[1]})"
  elif [ ! -f "$wr_dir/site_extent.json" ]; then why="the cold run wrote no site cache (site_extent.json): the warm run proved nothing"
  elif [ "$(echo "${wr_res[0]}" | cut -d' ' -f1-2)" != "$(echo "${wr_res[1]}" | cut -d' ' -f1-2)" ]; then why="cold and warm differ: cold ${wr_res[0]}; warm ${wr_res[1]}"; fi
  verdict world.site_warm_cache "$why" "cold = warm: ${wr_res[1]}"
fi

if [ -z "$FILTER" ] || [[ "runner.input_backslash" == *"$FILTER"* ]]; then
  GG="${TL_GODOT:-C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe}"
  EG="$(cd "$HERE/.." && pwd)"; command -v cygpath >/dev/null 2>&1 && EG="$(cygpath -m "$EG")"
  ri_dir="$OUT/walker_replay"; mkdir -p "$ri_dir"; command -v cygpath >/dev/null 2>&1 && ri_dir="$(cygpath -m "$ri_dir")"
  ri_out="$(MSYS_NO_PATHCONV=1 TL_REPLAYCASE_DIR="$ri_dir" timeout 180 "$GG" --headless --fixed-fps 60 --path "$EG" \
    --script res://kernel/runner/walker_replay_case.gd 2>&1 | tr -d '\015' | grep -a '^REPLAYCASE\|SCRIPT ERROR')"
  ri_line="$(echo "$ri_out" | grep -a '^REPLAYCASE input_path ' | head -1)"
  why=""
  if [ -z "$ri_line" ]; then why="no REPLAYCASE line (${ri_out:0:120})"
  elif [[ "$ri_line" != "REPLAYCASE input_path ok "* ]]; then why="${ri_line#REPLAYCASE }"
  elif echo "$ri_out" | grep -aq 'SCRIPT ERROR'; then why="script error: $(echo "$ri_out" | grep -a 'SCRIPT ERROR' | head -1)"; fi
  verdict runner.input_backslash "$why" "${ri_line#REPLAYCASE input_path ok }"
fi
