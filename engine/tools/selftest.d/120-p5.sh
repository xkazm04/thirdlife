# Check the world hashes after a pack reload and worker-queue preparation.
# Exercise the construction site's job log, lot transitions and collision geometry.

# ---------------------------------------------------------------- P5: loading is not simulation
# One plot's pack is replaced by a freshly loaded copy of the same directory inside a running world, after a value in
# its data/ changed (the walk's `edits` copies a file at a world tick: a scripted "the designer saved a tuned value";
# its `reload` event follows). The reloaded game is the CHANGED pack alone for its own ticks, it is not the unchanged
# one, and the two other games hash as in a run that nobody disturbed.
if [ -z "$FILTER" ] || [[ "world.reload" == *"$FILTER"* ]]; then
  WR="$OUT/world_reload"; rm -rf "$WR"; mkdir -p "$WR"
  command -v cygpath >/dev/null 2>&1 && WR="$(cygpath -m "$WR")"
  cp -r "$EX/ex_slide" "$WR/slide"
  sed 's/"start_speed": *[0-9.]*/"start_speed": 4.5/' "$EX/ex_slide/data/slide.json" > "$WR/tuned.json"
  walk_of() {   # walk_of <file> <events and edits, or nothing>
    printf '{"schema":"tl.walk/1","name":"reload","ticks":600,"mode":"smoke","plots":[{"id":"a","pack":"%s","origin":[0,0,0],"seed":1},{"id":"b","pack":"pack_min","origin":[60,0,0],"seed":1},{"id":"c","pack":"ex_wall","origin":[-60,0,0],"seed":1}],"player":[[0,[0,0,0]]]%s}\n' "$WR/slide" "$2" > "$1"
  }
  walk_of "$WR/quiet.json" ""
  walk_of "$WR/reload.json" ",\"events\":[{\"t\":300,\"e\":\"reload\",\"plot\":\"a\"}],\"edits\":[[299,\"$WR/slide/data/slide.json\",\"$WR/tuned.json\"]]"
  hp() { grep '"kind":"pack"' | grep "\"plot\":\"$1\"" | sed -E 's/.*"frames":([0-9]+).*"state_hash":"([0-9a-f]{16}).*/\1 \2/'; }
  q="$(TL_JSON=1 bash "$HERE/world.sh" walk "$WR/quiet.json" 2>&1)"
  r="$(TL_JSON=1 bash "$HERE/world.sh" walk "$WR/reload.json" "--log=$WR/log.json" 2>&1)"
  rp="$(TL_JSON=1 bash "$HERE/world.sh" replay "$WR/log.json" 2>&1)"
  af="$(echo "$r" | hp a | cut -d' ' -f1)"; ah="$(echo "$r" | hp a | cut -d' ' -f2)"
  hx() { grep '"kind":"pack"' | sed -E 's/.*"state_hash":"([0-9a-f]{16}).*/\1/' | tr '\n' ' '; }
  tuned="$(bash "$HERE/world.sh" run "--packs=$WR/slide" --frames="${af:-0}" | hx)"
  plain="$(bash "$HERE/world.sh" run "--packs=$EX/ex_slide" --frames="${af:-0}" | hx)"
  why=""
  echo "$r" | grep -q '"e":"reload","plot":"a"' || why="no reload event"
  echo "$r" | grep -q '"t":300,"e":"built","plot":"a"' || why="${why:+$why; }the reloaded pack did not arrive at tick 300"
  grep -q '4.5' "$WR/slide/data/slide.json" || why="${why:+$why; }the data file was not changed at tick 299"
  [ -n "$ah" ] && [ "$ah " = "$tuned" ] || why="${why:+$why; }the reloaded game [$af ticks $ah] is not the changed pack alone [$tuned]"
  [ "$tuned" != "$plain" ] || why="${why:+$why; }the changed value has no effect on the hash: the case proves nothing"
  [ -n "$(echo "$q" | hp b)" ] && [ "$(echo "$q" | hp b)" = "$(echo "$r" | hp b)" ] && [ "$(echo "$q" | hp c)" = "$(echo "$r" | hp c)" ] || why="${why:+$why; }the other games differ from the undisturbed run: b [$(echo "$q" | hp b)] [$(echo "$r" | hp b)], c [$(echo "$q" | hp c)] [$(echo "$r" | hp c)]"
  [ "$(echo "$r" | hp a)" = "$(echo "$rp" | hp a)" ] && [ "$(echo "$r" | hp b)" = "$(echo "$rp" | hp b)" ] || why="${why:+$why; }the log does not replay to the same"
  verdict world.reload "$why" "ex_slide reloaded at tick 300 with start_speed 4.5: $af ticks, $ah = the changed pack alone, not $plain; pack_min and ex_wall as undisturbed ($(echo "$r" | hp b | cut -d' ' -f2) $(echo "$r" | hp c | cut -d' ' -f2)); the log replays"
fi
# S (engine-world-next): the construction site (kernel/world/site.gd). A lot with a `job` shows that job's own log;
# the replay at a fixed rate is the same on two runs; a failed job says so; a lot whose log is missing stays a plain
# lot with a warning; a live site picks up lines appended while the world runs (the walk's `edits` instrument copies
# the longer log in at tick 100); the promoted game arrives on the lot through the build queue and hashes in the
# world as it does alone (and the log replays). Fixtures: kernel/world/site/fixtures/.
if [ -z "$FILTER" ] || [[ "site." == *"$FILTER"* ]] || [[ "$FILTER" == site.* ]]; then
  GS="${TL_GODOT:-C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe}"
  ES="$(cd "$HERE/.." && pwd)"; command -v cygpath >/dev/null 2>&1 && ES="$(cygpath -m "$ES")"
  SD="$OUT/site"; rm -rf "$SD"; mkdir -p "$SD"; command -v cygpath >/dev/null 2>&1 && SD="$(cygpath -m "$SD")"
  site_run() {   # site_run <walk file> [options]: the [site] report line and the exit code line of a headless world
    MSYS_NO_PATHCONV=1 "$GS" --headless --fixed-fps 60 --path "$ES" res://kernel/host/host.tscn -- world "--walk=$1" "${@:2}" 2>&1 | tr -d '\015' | grep -E '^\[site\]|^\[tl\] world done|SCRIPT ERROR'
    echo "exit ${PIPESTATUS[0]}"
  }
  lot_of() { grep '^\[site\] {' | grep -o "{\"lot\":$1,[^]]*][^}]*}[^}]*}" | sed -E 's/"read_ms":[0-9.]+//'; }
  FX="$ES/kernel/world/site/fixtures"
  r1="$(site_run "$FX/site_arrive.json" --ticks=300)"
  r2="$(site_run "$FX/site_arrive.json" --ticks=300)"
  if [ -z "$FILTER" ] || [[ "site.replay_same" == *"$FILTER"* ]]; then
    a="$(echo "$r1" | lot_of 0)"; b="$(echo "$r2" | lot_of 0)"; why=""
    [ -n "$a" ] || why="no [site] report for lot 0"
    [ "$a" = "$b" ] || why="${why:+$why; }two runs differ: [$a] [$b]"
    echo "$a" | grep -q '"events":15,' || why="${why:+$why; }not 15 events at tick 300 with one event per 20 ticks: $a"
    echo "$a" | grep -q '"stage":"building"' || why="${why:+$why; }not the building stage"
    echo "$r1" | grep -q '^exit 0' || why="${why:+$why; }the world did not end with exit 0"
    verdict site.replay_same "$why" "$(echo "$a" | grep -oE '"stage":"[a-z]+","title":"[^"]*","built":[0-9]+,"total":[0-9]+' ) at tick 300, twice"
  fi
  if [ -z "$FILTER" ] || [[ "site.failed" == *"$FILTER"* ]]; then
    a="$(echo "$r1" | lot_of 1)"; why=""
    echo "$a" | grep -q '"stage":"failed"' || why="the failed job is not shown failed: $a"
    echo "$a" | grep -q '"tower_core:failed"' || why="${why:+$why; }its failed package is not shown failed"
    echo "$a" | grep -q '"tower_look:blocked"' || why="${why:+$why; }its blocked package is not shown blocked"
    verdict site.failed "$why" "$(echo "$a" | grep -oE '"stage":"[a-z]+"|"packages":\[[^]]*\]' | tr '\n' ' ')"
  fi
  if [ -z "$FILTER" ] || [[ "site.missing_log" == *"$FILTER"* ]]; then
    printf '{"schema":"tl.walk/1","name":"site_missing","visitor":true,"ticks":120,"mode":"bot","plots":[{"id":"a","pack":"pack_min","origin":[0,0,0],"seed":1}],"landscape":{"lots":[{"at":[60,0],"radius":16,"job":"%s/no_such_job"}]},"player":[[0,[0,0,30]]]}\n' "$SD" > "$SD/missing.json"
    m="$(site_run "$SD/missing.json")"; why=""
    echo "$m" | grep -q '^\[site\] warning: lot 0: no job log' || why="no warning for the missing log"
    echo "$m" | grep -q '^exit 0' || why="${why:+$why; }the world did not end with exit 0: $(echo "$m" | tail -2 | tr '\n' ' ')"
    echo "$m" | grep -q '"lot":0' && why="${why:+$why; }a site was made for a lot without a log"
    verdict site.missing_log "$why" "$(echo "$m" | grep -m1 '^\[site\] warning' | cut -c1-90)...; the lot stays plain, the world runs"
  fi
  if [ -z "$FILTER" ] || [[ "site.live" == *"$FILTER"* ]]; then
    cp -r "$FX/arrive" "$SD/live"
    cp "$SD/live/job.jsonl" "$SD/live_full.jsonl"
    head -n 6 "$FX/arrive/job.jsonl" > "$SD/live/job.jsonl"
    printf '{"schema":"tl.walk/1","name":"site_live","visitor":true,"ticks":400,"mode":"bot","plots":[{"id":"a","pack":"pack_min","origin":[-60,0,0],"seed":1}],"landscape":{"lots":[{"at":[40,0],"radius":22,"h":0,"job":"%s/live"}]},"player":[[0,[40,0,30]]],"edits":[[100,"%s/live/job.jsonl","%s/live_full.jsonl"]]}\n' "$SD" "$SD" "$SD" > "$SD/live.json"
    l="$(site_run "$SD/live.json")"; a="$(echo "$l" | lot_of 0)"; why=""
    echo "$a" | grep -q '"mode":"live"' || why="the site is not live: $a"
    echo "$a" | grep -q '"events":21,' || why="${why:+$why; }the appended lines were not read (21 events wanted): $a"
    echo "$a" | grep -q '"stage_ticks":{"bays":0,"promoted":120}' || why="${why:+$why; }not 6 events at the start and all of them at tick 120 (the first look after the copy at 100): $a"
    echo "$a" | grep -q '"arrived":"example.bounce@0.1.0","arrived_at":120' || why="${why:+$why; }the promoted game did not arrive at tick 120"
    echo "$l" | grep -q '^exit 0' || why="${why:+$why; }the world did not end with exit 0"
    verdict site.live "$why" "6 events, the log grew to 21 at tick 100, read at tick 120, the game arrived; $(echo "$l" | grep -oE '"reads":[0-9]+,"read_ms":[0-9.]+' | head -1)"
  fi
  # S4: a live promotion refits the lot. A job of 6 lines on a lot of radius 30 grows to its promotion at tick 100
  # (read at 120); the game (a copy of ex_bounce, no footprint declared) is built and measured: 25.0 m from the
  # plot's centre, so the lot becomes 25 m (`radius_before` 30, `radius` 25 in the site's report line).
  if [ -z "$FILTER" ] || [[ "site.refit" == *"$FILTER"* ]]; then
    rm -rf "$SD/refit"; cp -r "$FX/arrive" "$SD/refit"; cp "$SD/refit/job.jsonl" "$SD/refit_full.jsonl"
    head -n 6 "$SD/refit_full.jsonl" > "$SD/refit/job.jsonl"
    printf '{"schema":"tl.walk/1","name":"site_refit","visitor":true,"ticks":400,"mode":"bot","plots":[{"id":"a","pack":"pack_min","origin":[-60,0,0],"seed":1}],"landscape":{"lots":[{"at":[40,0],"radius":30,"h":0,"job":"%s/refit"}]},"player":[[0,[40,0,40]]],"edits":[[100,"%s/refit/job.jsonl","%s/refit_full.jsonl"]]}\n' "$SD" "$SD" "$SD" > "$SD/refit.json"
    rm -rf "$SD/refit_cache"
    rf="$(TL_CACHE_DIR="$SD/refit_cache" site_run "$SD/refit.json")"; a="$(echo "$rf" | lot_of 0)"; why=""
    echo "$a" | grep -q '"arrived":"example.bounce@0.1.0","arrived_at":120' || why="the promoted game did not arrive at tick 120: $a"
    echo "$a" | grep -q '"radius":25.0,' || why="${why:+$why; }the lot was not refitted to 25 m: $(echo "$a" | grep -o '"radius":[0-9.]*')"
    echo "$a" | grep -q '"radius_before":30.0' || why="${why:+$why; }no radius before (30 wanted)"
    echo "$a" | grep -q '"measured_m":25.0' || why="${why:+$why; }the game was not measured at 25.0 m: $(echo "$a" | grep -o '"measured_m":[0-9.]*')"
    echo "$a" | grep -q '"fit":"walk radius: nothing promoted yet"' && why="${why:+$why; }the fit still says nothing was promoted"
    echo "$rf" | grep -q '^exit 0' || why="${why:+$why; }the world did not end with exit 0"
    verdict site.refit "$why" "lot 30 m -> $(echo "$a" | grep -o '"radius":[0-9.]*' | cut -d: -f2) m after the live arrival at tick 120; $(echo "$a" | grep -oE '"measured_m":[0-9.]+|"measure_ms":[0-9.]+' | tr '\n' ' ')"
  fi
  # S5: one ring per site. The extent measured in site.refit is kept in the world's cache (site_extent.json, by the
  # promoted pack's content); the next world on the same cache starts the lot (its pad, bank and ring) at 25 m.
  if [ -z "$FILTER" ] || [[ "site.ring" == *"$FILTER"* ]]; then
    why=""
    [ -s "$SD/refit_cache/site_extent.json" ] || why="site.refit left no site_extent.json in its cache (run site.refit first)"
    rg="$(TL_CACHE_DIR="$SD/refit_cache" site_run "$SD/refit.json")"; a="$(echo "$rg" | lot_of 0)"
    echo "$a" | grep -q '"radius":25.0,' || why="${why:+$why; }the second world did not start the lot at 25 m: $(echo "$a" | grep -o '"radius":[0-9.]*')"
    echo "$a" | grep -q '"radius_before":30' && why="${why:+$why; }the lot started at 30 m and was refitted again (it should start at its size)"
    echo "$a" | grep -q 'measured 25.0 m before (cache' || why="${why:+$why; }the fit does not name the cache: $(echo "$a" | grep -o '"fit":"[^"]*"')"
    echo "$rg" | grep -q '^exit 0' || why="${why:+$why; }the world did not end with exit 0"
    verdict site.ring "$why" "second world on the same cache: $(echo "$a" | grep -oE '"radius":[0-9.]+|"fit":"[^"]*"' | tr '\n' ' ')"
  fi
  if [ -z "$FILTER" ] || [[ "site.arrival" == *"$FILTER"* ]]; then
    out="$(bash "$HERE/world.sh" tour "$FX/site_arrive.json" --headless 2>&1)"
    why=""; echo "$out" | grep -q '^PASS world.tour' || why="$(echo "$out" | grep -E 'DIFFERENT|NO HASH|FAIL|rror' | head -3 | tr '\n' ' ')"
    echo "$out" | grep -Eq '^site_0 \| example\.bounce \| [1-9][0-9]* \| .* \| same$' || why="${why:+$why; }the arrived game has no row 'same' in the proof"
    echo "$out" | grep -q 'tick 380   e:built  plot:site_0' || why="${why:+$why; }the game did not arrive at tick 380"
    verdict site.arrival "$why" "the promoted game arrives at tick 380 and hashes as alone and as the replay: $(echo "$out" | grep '^site_0 |' | awk -F' [|] ' '{printf "%s ticks %s", $3, $5}')"
  fi
  # A change that was not made (JOB.md 2026-11-17, foreman/src/unmade.ts): pack/ goes back to the last promotion and
  # `merge` events with `files: []` and `removed` follow just before the job's state. A package whose files all go
  # (cups, added by the change) is not built any more; core keeps the files of the promotion; the game stays.
  if [ -z "$FILTER" ] || [[ "site.unmade" == *"$FILTER"* ]]; then
    printf '{"schema":"tl.walk/1","name":"site_unmade","visitor":true,"ticks":200,"mode":"bot","plots":[{"id":"a","pack":"pack_min","origin":[-60,0,0],"seed":1}],"landscape":{"lots":[{"at":[40,0],"radius":16,"h":0,"job":"%s","replay":{"ticks_per_event":5}}]},"player":[[0,[40,0,30]]]}\n' "$FX/unmade" > "$SD/unmade.json"
    u="$(site_run "$SD/unmade.json")"; a="$(echo "$u" | lot_of 0)"; why=""
    echo "$a" | grep -q '"events":33,"events_in_file":33,' || why="the log was not read to its end (33 events): $a"
    echo "$a" | grep -q '"built":1,"total":2' || why="${why:+$why; }not 1 of 2 built after the restore: $a"
    echo "$a" | grep -q '"core:promoted+merged","cups:failed"\]' || why="${why:+$why; }core is not built or cups is shown built: $a"
    echo "$a" | grep -q '"stage":"promoted"' || why="${why:+$why; }the promoted game does not stay"
    echo "$a" | grep -q '"log_error"' && why="${why:+$why; }the restore's merge events broke the reading"
    echo "$u" | grep -q '^exit 0' || why="${why:+$why; }the world did not end with exit 0"
    verdict site.unmade "$why" "after the restore: $(echo "$a" | grep -oE '"built":[0-9]+,"total":[0-9]+|"packages":\[[^]]*\]' | tr '\n' ' ')"
  fi
  # S2, S3: the exe's village follows a job that is running (`-- check --site-job=<abs dir>`, engine/boot/boot.gd).
  # The job starts with 3 lines and grows by world ticks, not by the clock: `--edits` (a test instrument: the walk's
  # `edits`, kernel/world/jobs.gd) copies a longer prefix of the fixture's log over the job's job.jsonl at ticks 100,
  # 200, 300 and 400. The live site looks at the file every 60 ticks, so it must see bays at 0, building at 240 (the
  # first merge) and the promotion at 420, and the game arrives then: the same ticks on three runs.
  if [ -z "$FILTER" ] || [[ "site.follow_exe" == *"$FILTER"* ]]; then
    fruns=""; why=""
    for run in 1 2 3; do
      rm -rf "$SD/follow"; cp -r "$FX/arrive" "$SD/follow"; cp "$SD/follow/job.jsonl" "$SD/follow_21.jsonl"
      for n in 3 6 11 16; do head -n $n "$SD/follow_21.jsonl" > "$SD/follow_$n.jsonl"; done
      cp "$SD/follow_3.jsonl" "$SD/follow/job.jsonl"
      printf '[[100,"%s/follow/job.jsonl","%s/follow_6.jsonl"],[200,"%s/follow/job.jsonl","%s/follow_11.jsonl"],[300,"%s/follow/job.jsonl","%s/follow_16.jsonl"],[400,"%s/follow/job.jsonl","%s/follow_21.jsonl"]]\n' "$SD" "$SD" "$SD" "$SD" "$SD" "$SD" "$SD" "$SD" > "$SD/follow_edits.json"
      f="$(MSYS_NO_PATHCONV=1 "$GS" --headless --fixed-fps 60 --path "$ES" res://boot/boot.tscn -- check "--out=$SD/fcheck.jsonl" "--site-job=$SD/follow" "--edits=$SD/follow_edits.json" --ticks=600 2>&1 | tr -d '\015' | grep -E '^\[site\]|^\[boot\]|SCRIPT ERROR')"
      a="$(echo "$f" | lot_of 0)"
      echo "$f" | grep -q '^\[boot\] lot 0 follows the job .*follow live' || why="${why:+$why; }run $run: the check did not take --site-job"
      echo "$a" | grep -q '"mode":"live"' || why="${why:+$why; }run $run: the site is not live"
      echo "$a" | grep -q '"events":21,' || why="${why:+$why; }run $run: not all 21 lines read: $a"
      echo "$a" | grep -q '"stage_ticks":{"bays":0,"building":240,"promoted":420}' || why="${why:+$why; }run $run: stage ticks $(echo "$a" | grep -o '"stage_ticks":{[^}]*}'), wanted bays 0, building 240, promoted 420"
      echo "$a" | grep -q '"arrived":"example.bounce@0.1.0","arrived_at":420' || why="${why:+$why; }run $run: the game did not arrive at tick 420"
      grep -q '"plot":"site_0"' "$SD/fcheck.jsonl" 2>/dev/null || why="${why:+$why; }run $run: no line for the site's plot"
      fruns="$fruns$(echo "$a" | grep -o '"stage_ticks":{[^}]*}' | sed 's/"stage_ticks"://'); "
    done
    verdict site.follow_exe "$why" "three runs, the log grown by ticks 100 to 400: $fruns"
  fi
  # S2: the scaffold is solid (a window: the visitor's space exists only with the landscape). Probes at world ticks
  # (walk `visitor_probe` entries with `t`): while the site builds, the gate lets the visitor in and the middle bay
  # stops him (`stopped_by` site 0); after the game arrived (tick 380) the same walk is not stopped by the site.
  if [ -z "$FILTER" ] || [[ "site.solid" == *"$FILTER"* ]]; then
    so="$(bash "$HERE/world.sh" tour "$FX/site_solid.json" "--out-dir=$SD/solid" --pictures-only 2>&1)"
    pr() { echo "$so" | grep "name:$1 " | grep -oE 'ok:[a-z]+|stopped_by:[a-z0-9 ]+  ticks|end:\[[^]]*\]' | sed 's/  ticks//' | tr '\n' ' '; }
    why=""
    echo "$so" | grep -q 'name:site_gate_while_building .*ok:true' || why="the gate did not let him in while the site builds: $(pr site_gate_while_building)"
    echo "$so" | grep -q 'name:site_bay_while_building .*ok:true.*stopped_by:site 0 ' || why="${why:+$why; }the bay did not stop him while the site builds: $(pr site_bay_while_building)"
    echo "$so" | grep -q 'name:site_bay_after_arrival .*ok:true.*stopped_by:none' || why="${why:+$why; }the bay's collider was still there after the arrival: $(pr site_bay_after_arrival)"
    echo "$so" | grep -q 'e:built  plot:site_0' || why="${why:+$why; }the game did not arrive"
    echo "$so" | grep -q '^DONE world.tour' || why="${why:+$why; }the window run failed: $(echo "$so" | grep -E 'FAIL|ERROR' | head -2 | tr '\n' ' ')"
    verdict site.solid "$why" "gate: $(pr site_gate_while_building); bay while building: $(pr site_bay_while_building); after arrival: $(pr site_bay_after_arrival)"
  fi
fi
# The build queue with its worker thread, without a window (walks/queue.json: `load.mode` wait): three seeds are
# prepared on the worker (scripts, layouts built ahead by the kit), one per tick, waited for. Every pack hashes as
# it does alone for the same number of its own ticks, and the log (with its `built` events) replays to the same.
if [ -z "$FILTER" ] || [[ "world.queue" == *"$FILTER"* ]]; then
  out="$(bash "$HERE/world.sh" proof queue 2>&1)"
  why=""; echo "$out" | grep -q '^PASS world.proof' || why="$(echo "$out" | grep -E 'DIFFERENT|NO HASH|FAIL|rror' | head -3 | tr '\n' ' ')"
  [ "$(echo "$out" | grep -c 'e:built')" = 3 ] || why="${why:+$why; }expected 3 built events, got $(echo "$out" | grep -c 'e:built')"
  verdict world.queue "$why" "3 seeds built by the worker, arrived at ticks $(echo "$out" | grep 'e:built' | sed -E 's/^tick ([0-9]+).*plot:([a-z]+).*/\2 \1/' | tr '\n' ' '); walk = alone = replay"
fi

