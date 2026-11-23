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
