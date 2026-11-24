# Rink core (engine/cores/rink, lane K1 of the hockey port): thirdjam's own C++ compiled into a GDExtension.
#   rink.smoke       RinkCore loads headless; thirdjam's regular 5 v 5 (HEAD) by bots only for 3,600 frames, twice: same hash
#   rink.trace_head  thirdjam's tournament commandlet inside Godot (HEAD): seed 1 pro playerbot equals proof/head.*.txt line for line
#   rink.trace_t5    the t5 tree natively (rinkcli): equals the Unreal build's own lines for the same flags (proof/ue-t5.*.txt)
# A missing build is a FAIL that names the command (engine/tools/rink.sh build); it is never skipped as a pass.
rink_cases="rink.smoke rink.trace_head rink.trace_t5"
if [ -z "$FILTER" ] || [[ "$rink_cases" == *"$FILTER"* ]]; then
  rink_g="${TL_GODOT:-C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe}"
  rink_engine="$(cd "$HERE/.." && pwd)"
  rink_root="$(cd "$HERE/../.." && pwd)"
  command -v cygpath >/dev/null 2>&1 && rink_engine="$(cygpath -am "$rink_engine")"
  rink_dll="$HERE/../cores/rink/bin/rink_core.windows.template_debug.x86_64.dll"
  rink_proof="$HERE/../cores/rink/proof"
  if [ -z "$FILTER" ] || [[ "rink.smoke" == *"$FILTER"* ]]; then
    why=""; note=""
    if [ ! -f "$rink_dll" ]; then
      why="the extension is not built (run: bash engine/tools/rink.sh build)"
    else
      rink_out="$(MSYS_NO_PATHCONV=1 timeout 300 "$rink_g" --headless --path "$rink_engine" --script res://cores/rink/tools/rink_smoke.gd 2>&1 | tr -d '\015'; echo "RINKRC ${PIPESTATUS[0]}")"
      rink_rc="$(echo "$rink_out" | sed -n 's/^RINKRC //p' | tail -1)"
      rink_l="$(echo "$rink_out" | grep -m1 '^PASS  rink smoke\|^FAIL  rink smoke')"
      [[ "$rink_l" == "PASS  rink smoke"* ]] || why="${rink_l:-no smoke line (Godot exit ${rink_rc:-unknown})}"
      note="$(echo "$rink_out" | grep -m1 '^RINKSMOKE' | cut -c11-)"
    fi
    verdict rink.smoke "$why" "$note"
  fi
  if [ -z "$FILTER" ] || [[ "rink.trace_head" == *"$FILTER"* ]]; then
    why=""; note=""
    if [ ! -f "$rink_dll" ]; then
      why="the extension is not built (run: bash engine/tools/rink.sh build)"
    else
      mkdir -p "$OUT/rink"
      rink_c="$rink_engine/cores/rink/native/content"
      MSYS_NO_PATHCONV=1 timeout 300 "$rink_g" --headless --path "$rink_engine" --script res://cores/rink/tools/rink_trace.gd -- "--content=$rink_c" \
        -cartridge=hockey.regular -seeds=1-1 -mode=playerbot -difficulty=pro -trace=600 2>/dev/null | tr -d '\015' \
        | grep '^RINKLOG LogJamAI: Display: ' | sed 's/^RINKLOG LogJamAI: Display: //' > "$OUT/rink/head.txt"
      rink_n="$(wc -l < "$OUT/rink/head.txt")"; rink_w="$(wc -l < "$rink_proof/head.seed1.pro.playerbot.trace600.txt")"
      if [ "$rink_n" -eq 0 ]; then why="no trace lines (a stopped run)"
      elif ! cmp -s "$OUT/rink/head.txt" "$rink_proof/head.seed1.pro.playerbot.trace600.txt"; then
        why="$rink_n lines vs $rink_w; first difference at line $(cmp "$OUT/rink/head.txt" "$rink_proof/head.seed1.pro.playerbot.trace600.txt" 2>&1 | sed -n 's/.*line \([0-9]*\).*/\1/p')"
      else note="$rink_n of $rink_w lines equal"; fi
    fi
    verdict rink.trace_head "$why" "$note"
  fi
  if [ -z "$FILTER" ] || [[ "rink.trace_t5" == *"$FILTER"* ]]; then
    why=""; note=""
    rink_cli="$HERE/../cores/rink/bin/rinkcli-thirdjam-t5.exe"
    if [ ! -f "$rink_cli" ]; then
      why="the t5 CLI is not built (run: bash engine/tools/rink.sh build thirdjam-t5)"
    else
      mkdir -p "$OUT/rink"
      timeout 300 bash "$HERE/rink.sh" trace thirdjam-t5 -cartridge=hockey.regular -seeds=1-1 -mode=playerbot -difficulty=pro -trace=600 > "$OUT/rink/t5.txt" 2>/dev/null
      rink_n="$(wc -l < "$OUT/rink/t5.txt")"; rink_w="$(wc -l < "$rink_proof/ue-t5.seed1.pro.playerbot.trace600.txt")"
      if [ "$rink_n" -eq 0 ]; then why="no trace lines (a stopped run)"
      elif ! cmp -s "$OUT/rink/t5.txt" "$rink_proof/ue-t5.seed1.pro.playerbot.trace600.txt"; then why="$rink_n lines vs the Unreal build's $rink_w: they differ"
      else note="$rink_n of $rink_w lines equal to the Unreal build's"; fi
    fi
    verdict rink.trace_t5 "$why" "$note"
  fi
fi

# Round 3 (the kernel entry, ctx.cores.open, kernel API 1.17): the probe pack engine/cores/rink/test_pack drives the core
# through the runner; its _pack_state is ctx.cores.state() (the core's hash, frame, score), so the runner's hash covers it.
#   rink.entry_twice   the probe's fixed bot hand, seed 3, two runs: both pass and end on the same state hash
#   rink.entry_replay  the first run's input record replayed (no bot, no device): the same state hash
#   rink.window        the same hand as raw key events in a real window (50 s): the window's own input record, replayed
#                      headless, gives the core hashes the window printed at every 600th frame (the core in a window
#                      equals the core headless for the same input samples)
rink2_cases="rink.entry_twice rink.entry_replay rink.window"
if [ -z "$FILTER" ] || [[ "$rink2_cases" == *"$FILTER"* ]]; then
  rink_pack="$HERE/../cores/rink/test_pack"
  mkdir -p "$OUT/rink"
  rink_o="$OUT/rink"; command -v cygpath >/dev/null 2>&1 && rink_o="$(cygpath -am "$OUT/rink")"
  rink_hash() { sed -n 's/.*"state_hash":"\([0-9a-f]*\)".*/\1/p' | head -1; }
  rink_dll="$HERE/../cores/rink/bin/rink_core.windows.template_debug.x86_64.dll"
  if [ -z "$FILTER" ] || [[ "rink.entry_twice rink.entry_replay" == *"$FILTER"* ]]; then
    why=""; note=""
    if [ ! -f "$rink_dll" ]; then why="the extension is not built (run: bash engine/tools/rink.sh build)"; else
      r1="$(TL_QUIET=1 timeout 300 bash "$TL" bot "--pack=$rink_pack" --seed=3 --frames=3600 "--record=$rink_o/rec1.json" 2>/dev/null)"; c1=$?
      r2="$(TL_QUIET=1 timeout 300 bash "$TL" bot "--pack=$rink_pack" --seed=3 --frames=3600 2>/dev/null)"; c2=$?
      h1="$(echo "$r1" | rink_hash)"; h2="$(echo "$r2" | rink_hash)"
      if [ "$c1" != 0 ] || [ "$c2" != 0 ]; then why="bot exit $c1 / $c2: $(echo "$r1" | grep -o '"errors":\[[^]]*' | cut -c1-160)"
      elif [ -z "$h1" ] || [ "$h1" != "$h2" ]; then why="state hash ${h1:-none} vs ${h2:-none}"
      else note="$h1 twice"; fi
    fi
    verdict rink.entry_twice "$why" "$note"
    why=""; note=""
    if [ ! -f "$rink_dll" ]; then why="the extension is not built (run: bash engine/tools/rink.sh build)"
    elif [ ! -f "$OUT/rink/rec1.json" ]; then why="no input record from rink.entry_twice"
    else
      r3="$(TL_QUIET=1 timeout 300 bash "$TL" replay "--pack=$rink_pack" "--input=$rink_o/rec1.json" 2>/dev/null)"; c3=$?
      h3="$(echo "$r3" | rink_hash)"
      if [ "$c3" != 0 ]; then why="replay exit $c3"; elif [ "$h3" != "$h1" ]; then why="replay ${h3:-none} vs bot ${h1:-none}"; else note="$h3 = the bot run's"; fi
    fi
    verdict rink.entry_replay "$why" "$note"
  fi
  if [ -z "$FILTER" ] || [[ "rink.window" == *"$FILTER"* ]]; then
    why=""; note=""
    if [ ! -f "$rink_dll" ]; then why="the extension is not built (run: bash engine/tools/rink.sh build)"; else
      rink_dev="$HERE/../cores/rink/test_pack/data/hand.devices.json"; command -v cygpath >/dev/null 2>&1 && rink_dev="$(cygpath -am "$rink_dev")"
      timeout 300 bash "$TL" play "--pack=$rink_pack" --seed=3 --frames=3001 "--devices=$rink_dev" "--record=$rink_o/win.json" > "$OUT/rink/win.log" 2>&1; cw=$?
      TL_QUIET= timeout 300 bash "$TL" replay "--pack=$rink_pack" "--input=$rink_o/win.json" > "$OUT/rink/winreplay.log" 2>&1
      grep -o 'RINKPROBE frame=[0-9]* core=[0-9a-f]*' "$OUT/rink/win.log" > "$OUT/rink/win.lines"
      grep -o 'RINKPROBE frame=[0-9]* core=[0-9a-f]*' "$OUT/rink/winreplay.log" > "$OUT/rink/winreplay.lines"
      nw="$(wc -l < "$OUT/rink/win.lines")"
      if [ "$cw" != 0 ] || [ "$nw" -lt 5 ]; then why="the window run stopped (exit $cw, $nw of 5 checkpoints)"
      elif ! cmp -s "$OUT/rink/win.lines" "$OUT/rink/winreplay.lines"; then why="window vs its replay: $(diff "$OUT/rink/win.lines" "$OUT/rink/winreplay.lines" | head -2 | tr '\n' ' ')"
      else note="$nw of $nw checkpoints equal (window = headless replay of its input)"; fi
    fi
    verdict rink.window "$why" "$note"
  fi
fi

# Round 3 item 4: the person's input path. human mode "raw" (thirdjam's game-mode rules in the core's glue, GAMEMODE.md):
#   rink.rawhand   one scripted raw device stream (two-role buttons, holds, sprint, poke, spin, ability, signals, camera yaw,
#                  cursor aim) fed twice: the same FJamInput every frame and the same hash; every verb reaches the sim; and the
#                  gym (set_bot_mode parked): the human skates, parked wingers and backs do not move
if [ -z "$FILTER" ] || [[ "rink.rawhand" == *"$FILTER"* ]]; then
  why=""; note=""
  if [ ! -f "$HERE/../cores/rink/bin/rink_core.windows.template_debug.x86_64.dll" ]; then why="the extension is not built (run: bash engine/tools/rink.sh build)"; else
    rh_g="${TL_GODOT:-C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe}"
    rh_e="$(cd "$HERE/.." && pwd)"; command -v cygpath >/dev/null 2>&1 && rh_e="$(cygpath -am "$rh_e")"
    rh_out="$(MSYS_NO_PATHCONV=1 timeout 300 "$rh_g" --headless --path "$rh_e" --script res://cores/rink/tools/rink_rawhand.gd 2>&1 | tr -d '\015')"
    rh_l="$(echo "$rh_out" | grep -m1 '^PASS  rink rawhand\|^FAIL  rink rawhand')"
    [[ "$rh_l" == "PASS  rink rawhand"* ]] || why="${rh_l:-no rawhand line (the run stopped)}"
    note="$(echo "$rh_out" | grep -m1 '^RAWHAND run1' | cut -c14-130)"
  fi
  verdict rink.rawhand "$why" "$note"
fi

#   rink.rawtrace  the recorded raw stream proof/rawhand.seed5.600.stream.json through human mode "raw" (rink_rawtrace.gd)
#                  equals proof/rawhand.seed5.600.trace.txt line for line (frame, hash, score, carrier, the human's FJamInput)
if [ -z "$FILTER" ] || [[ "rink.rawtrace" == *"$FILTER"* ]]; then
  why=""; note=""
  if [ ! -f "$HERE/../cores/rink/bin/rink_core.windows.template_debug.x86_64.dll" ]; then why="the extension is not built (run: bash engine/tools/rink.sh build)"; else
    rt_g="${TL_GODOT:-C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe}"
    rt_e="$(cd "$HERE/.." && pwd)"; rt_p="$rt_e/cores/rink/proof"; rt_o="$OUT/rink"; mkdir -p "$rt_o"
    command -v cygpath >/dev/null 2>&1 && { rt_e="$(cygpath -am "$rt_e")"; rt_p="$(cygpath -am "$rt_p")"; rt_o="$(cygpath -am "$rt_o")"; }
    MSYS_NO_PATHCONV=1 timeout 300 "$rt_g" --headless --path "$rt_e" --script res://cores/rink/tools/rink_rawtrace.gd -- "--stream=$rt_p/rawhand.seed5.600.stream.json" \
      "--out=$rt_o/rawtrace.txt" --seed=5 >/dev/null 2>&1
    rt_n="$(wc -l < "$OUT/rink/rawtrace.txt" 2>/dev/null || echo 0)"
    if [ "$rt_n" -eq 0 ]; then why="no trace lines (a stopped run)"
    elif ! cmp -s "$OUT/rink/rawtrace.txt" "$HERE/../cores/rink/proof/rawhand.seed5.600.trace.txt"; then why="differs from the recorded trace at line $(cmp "$OUT/rink/rawtrace.txt" "$HERE/../cores/rink/proof/rawhand.seed5.600.trace.txt" 2>&1 | sed -n 's/.*line \([0-9]*\).*/\1/p')"
    else note="$rt_n of $rt_n lines equal"; fi
  fi
  verdict rink.rawtrace "$why" "$note"
fi

# Round 4 item 4: thirdjam's playtester seated in the core (human mode "playtester:regular:sprint", native/glue/rink_playtester.cpp)
#   rink.playtester_seat  seed 1, pro: the seat's match ends on the same state hash as thirdjam's own tournament playtester
#                         (-player=regular -playersprint, run natively by rinkcli); the raw-key hand's first parting is noted
if [ -z "$FILTER" ] || [[ "rink.playtester_seat" == *"$FILTER"* ]]; then
  why=""; note=""
  if [ ! -f "$HERE/../cores/rink/bin/rink_core.windows.template_debug.x86_64.dll" ] || [ ! -f "$HERE/../cores/rink/bin/rinkcli-thirdjam.exe" ]; then
    why="the core or its CLI is not built (run: bash engine/tools/rink.sh build)"
  else
    ps_want="$(timeout 300 bash "$HERE/rink.sh" trace thirdjam -cartridge=hockey.regular -seeds=1-1 -difficulty=pro -player=regular -playersprint -trace=0 2>/dev/null | sed -n 's/.*"hash":"\([0-9a-f]*\)".*/\1/p' | head -1)"
    ps_g="${TL_GODOT:-C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe}"
    ps_e="$(cd "$HERE/.." && pwd)"; command -v cygpath >/dev/null 2>&1 && ps_e="$(cygpath -am "$ps_e")"
    ps_out="$(MSYS_NO_PATHCONV=1 timeout 600 "$ps_g" --headless --path "$ps_e" --script res://cores/rink/tools/rink_keyshand.gd -- --kind=regular --sprint --seed=1 "--want=$ps_want" 2>&1 | tr -d '\015')"
    ps_l="$(echo "$ps_out" | grep -m1 '^PASS  rink keyshand\|^FAIL  rink keyshand')"
    if [ -z "$ps_want" ]; then why="no reference hash from the tournament (a stopped run)"
    elif [[ "$ps_l" != "PASS  rink keyshand"* ]]; then why="${ps_l:-no keyshand line (the run stopped)}"
    else note="seat = thirdjam's playtester ($ps_want); $(echo "$ps_out" | grep -m1 '^KEYSHAND keys' | cut -c19-110)"; fi
  fi
  verdict rink.playtester_seat "$why" "$note"
fi

# Round 5: the snapshot's Controls fields for the HUD (K5): ButtonsWithPuck equals thirdjam's two-role rule (InputMapping.cpp:432-442)
# recomputed from the snapshot on every frame of a whole match (thirdjam's playtester, seed 1), and every other field keeps its rule
# (tools/rink_controls.gd).
if [ -z "$FILTER" ] || [[ "rink.controls" == *"$FILTER"* ]]; then
  why=""; note=""
  if [ ! -f "$HERE/../cores/rink/bin/rink_core.windows.template_debug.x86_64.dll" ]; then why="the extension is not built (run: bash engine/tools/rink.sh build)"; else
    rc_g="${TL_GODOT:-C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe}"
    rc_e="$(cd "$HERE/.." && pwd)"; command -v cygpath >/dev/null 2>&1 && rc_e="$(cygpath -am "$rc_e")"
    rc_out="$(MSYS_NO_PATHCONV=1 timeout 600 "$rc_g" --headless --path "$rc_e" --script res://cores/rink/tools/rink_controls.gd -- --seed=1 2>&1 | tr -d '\015')"
    rc_l="$(echo "$rc_out" | grep -m1 '^PASS  rink controls\|^FAIL  rink controls')"
    [[ "$rc_l" == "PASS  rink controls"* ]] || why="${rc_l:-no controls line (the run stopped)}"
    note="$(echo "$rc_l" | cut -c21-200)"
  fi
  verdict rink.controls "$why" "$note"
fi

# Round 5: the thirdlife core (thirdjam + native/patches-thirdlife, lane K8) selected by cartridge (tools/rink_variant.gd): with its
# switches off it plays hockey.regular hash for hash on every frame of a match; the plain core refuses rules; TLCores.open opens
# RinkCoreThirdlife for a cartridge with a <name>.rules.json sidecar and RinkCore without. A tree without the patches checks that the
# plain core refuses a rule and nothing registers the variant.
if [ -z "$FILTER" ] || [[ "rink.variant" == *"$FILTER"* ]]; then
  why=""; note=""
  rv_patches="$(ls "$HERE/../cores/rink/native/patches-thirdlife"/*.patch 2>/dev/null | head -1)"
  if [ ! -f "$HERE/../cores/rink/bin/rink_core.windows.template_debug.x86_64.dll" ]; then why="the extension is not built (run: bash engine/tools/rink.sh build)"
  elif [ -n "$rv_patches" ] && [ ! -f "$HERE/../cores/rink/bin/rink_core_thirdlife.windows.template_debug.x86_64.dll" ]; then why="native/patches-thirdlife is here but the thirdlife core is not built (bash engine/tools/rink.sh build thirdlife)"
  else
    rc_g="${TL_GODOT:-C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe}"
    rc_e="$(cd "$HERE/.." && pwd)"; command -v cygpath >/dev/null 2>&1 && rc_e="$(cygpath -am "$rc_e")"
    rv_arg="--seed=1"; [ -n "$rv_patches" ] || rv_arg="--plain-only"
    rc_out="$(MSYS_NO_PATHCONV=1 timeout 900 "$rc_g" --headless --path "$rc_e" --script res://cores/rink/tools/rink_variant.gd -- $rv_arg 2>&1 | tr -d '\015')"
    rc_l="$(echo "$rc_out" | grep -m1 '^PASS  rink variant\|^FAIL  rink variant\|^NOT RUN  rink variant')"
    [[ "$rc_l" == "PASS  rink variant"* ]] || why="${rc_l:-no variant line (the run stopped)}"
    note="$(echo "$rc_l" | cut -c20-220)"
  fi
  verdict rink.variant "$why" "$note"
fi

# Round 6 (K3): the playtester's advice (set_advisor / advise, tools/rink_advice.gd): with the playtester seated and an advisor of the
# same spec, the advice asked before each step equals what the seat then sent, on every frame of a whole match (seed 1, regular +
# sprint), asked twice = once, and the seated match keeps thirdjam's playtester hash (973d6c043707b703: the advisor disturbs nothing).
if [ -z "$FILTER" ] || [[ "rink.advice" == *"$FILTER"* ]]; then
  why=""; note=""
  if [ ! -f "$HERE/../cores/rink/bin/rink_core.windows.template_debug.x86_64.dll" ]; then why="the extension is not built (run: bash engine/tools/rink.sh build)"; else
    rc_g="${TL_GODOT:-C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe}"
    rc_e="$(cd "$HERE/.." && pwd)"; command -v cygpath >/dev/null 2>&1 && rc_e="$(cygpath -am "$rc_e")"
    rc_out="$(MSYS_NO_PATHCONV=1 timeout 900 "$rc_g" --headless --path "$rc_e" --script res://cores/rink/tools/rink_advice.gd -- --seed=1 2>&1 | tr -d '\015')"
    rc_l="$(echo "$rc_out" | grep -m1 '^PASS  rink advice\|^FAIL  rink advice')"
    [[ "$rc_l" == "PASS  rink advice"* ]] || why="${rc_l:-no advice line (the run stopped)}"
    [[ "$rc_l" == *"hash 973d6c043707b703"* ]] || [ -n "$why" ] || why="the seated match no longer ends on the hash of thirdjam playtester 973d6c043707b703: $rc_l"
    note="$(echo "$rc_l" | cut -c19-200)"
  fi
  verdict rink.advice "$why" "$note"
fi

# Lane E2 (the cartridge): the schema in our tree equals thirdjam's embedded copy (schema/extract.py --check), CARTRIDGE.md's generated
# parts are current (schema/catalog.py --check), and the measured check plays hockey.regular to the end at three levels with no
# warning (rink.sh check-cartridge, 3 seeds a level, no planning hand: a few seconds).
if [ -z "$FILTER" ] || [[ "rink.cartridge" == *"$FILTER"* ]]; then
  why=""; note=""
  rk_r="$(cd "$HERE/.." && pwd)/cores/rink"
  rk_a="$(python -I "$rk_r/schema/extract.py" --check 2>&1 | tail -1)"
  rk_b="$(python -I "$rk_r/schema/catalog.py" --check 2>&1 | tail -1)"
  rk_c="$(timeout 600 bash "$HERE/rink.sh" check-cartridge "$rk_r/native/content/Cartridges/hockey.regular.cartridge.json" --seeds 3 --plan-seeds 0 2>&1 | tr -d '\015')"
  rk_l="$(echo "$rk_c" | grep -m1 '^PASS  rink check-cartridge\|^FAIL  rink check-cartridge\|^NOT RUN  rink check-cartridge')"
  [[ "$rk_a" == PASS* ]] || why="$rk_a"
  [[ "$rk_b" == PASS* ]] || why="${why:+$why; }$rk_b"
  [[ "$rk_l" == "PASS  rink check-cartridge: measured" ]] || why="${why:+$why; }${rk_l:-no check-cartridge line (the run stopped)}"
  echo "$rk_c" | grep -q "WARN" && why="${why:+$why; }hockey.regular drew a warning: $(echo "$rk_c" | grep -m1 WARN)"
  note="schema = the embedded copy; catalog current; $(echo "$rk_c" | grep -m1 '^  pro' | cut -c3-120)"
  verdict rink.cartridge "$why" "$note"
fi
