# Compare verbs.json with the host option tables.
# Check world hashes for packs run together, sliced or paused.

# ---------------------------------------------------------------- N2: the one list of verbs, and the world host
# kernel/runner/verbs.json (tl.verbs/1) must name exactly the verbs and options of host.gd's OPTIONS table, and its
# "modes" exactly those of MODE_OPTIONS. Both sides are read as text here: no engine run.
sort_opts() {  # "verb:b,a" lines -> options sorted, lines sorted
  while IFS=: read -r v o; do echo "$v:$(echo "$o" | tr ',' '\n' | sort | tr '\n' ',' | sed 's/,$//')"; done | sort
}
table_of() {  # table_of <const name>: "verb:opt,opt,..." lines from the table in host.gd
  sed -n "/^const $1: Dictionary = {/,/^}/p" "$HERE/../kernel/host/host.gd" | sed -E 's/#.*$//' \
    | grep -o '"[a-z-]*": \[[^]]*\]' | sed -E 's/"([a-z-]*)": \[(.*)\]/\1:\2/; s/[" ]//g' | sort_opts
}
json_of() {   # json_of <verbs|modes>: the same lines from verbs.json (verbs at four spaces, options at eight)
  sed -n "/^  \"$1\": {/,/^  }/p" "$HERE/../kernel/runner/verbs.json" | tr -d '\r' \
    | grep -E '^    "[a-z-]+": \{|^        "[a-z-]+": \{' | sed -E 's/^        "([a-z-]+)".*/O \1/; s/^    "([a-z-]+)".*/V \1/' \
    | { v=""; o=""; while read -r k n; do if [ "$k" = V ]; then [ -n "$v" ] && echo "$v:$o"; v="$n"; o=""; else o="${o:+$o,}$n"; fi; done; [ -n "$v" ] && echo "$v:$o"; } | sort_opts
}
if [ -z "$FILTER" ] || [[ "verbs.json_matches_host" == *"$FILTER"* ]]; then
  why=""
  a="$(table_of OPTIONS)"; b="$(json_of verbs)"
  [ -z "$a" ] && why="could not read OPTIONS from host.gd"
  [ "$a" != "$b" ] && why="${why:+$why; }verbs differ: host.gd [$(echo $a)] verbs.json [$(echo $b)]"
  c="$(table_of MODE_OPTIONS)"; d="$(json_of modes)"
  [ -z "$c" ] && why="${why:+$why; }could not read MODE_OPTIONS from host.gd"
  [ "$c" != "$d" ] && why="${why:+$why; }modes differ: host.gd [$(echo $c)] verbs.json [$(echo $d)]"
  grep -q '"schema": "tl.verbs/1"' "$HERE/../kernel/runner/verbs.json" || why="${why:+$why; }verbs.json is not tl.verbs/1"
  verdict verbs.json_matches_host "$why" "$(echo "$a" | wc -l | tr -d ' ') verbs and $(echo "$c" | wc -l | tr -d ' ') world modes, the same options on both sides"
fi
# several packs in one process: every pack hashes together as it does alone (tools/world.sh same)
if [ -z "$FILTER" ] || [[ "world.same" == *"$FILTER"* ]]; then
  out="$(bash "$HERE/world.sh" same --packs=pack_min,ex_bounce,ex_wall,ex_wall --frames=600 2>&1)"
  why=""; echo "$out" | grep -q '^PASS world.same' || why="$(echo "$out" | grep -E 'DIFFERENT|NO HASH|FAIL|not every' | head -3 | tr '\n' ' ')"
  verdict world.same "$why" "pack_min, ex_bounce and two ex_wall in one process: 4 hashes equal to the solo runs, three times"
fi
# a pack that gets one world tick in 8, and one paused for 100 ticks, end in the state of the uninterrupted run
if [ -z "$FILTER" ] || [[ "world.sliced_and_paused" == *"$FILTER"* ]]; then
  hx() { grep '"kind":"pack"' | sed -E 's/.*"state_hash":"([0-9a-f]{16}).*/\1/' | tr '\n' ' '; }
  h0="$(bash "$HERE/world.sh" run --packs=ex_wall,ex_bounce --mode=bot --frames=3000 | hx)"
  o1="$(bash "$HERE/world.sh" run --packs=ex_wall,ex_bounce --mode=bot --frames=3000 --every=8,3 '--pause=1:100:100')"
  h1="$(echo "$o1" | hx)"
  why=""; [ -z "$h0" ] && why="no hashes"
  [ "$h0" != "$h1" ] && why="continuous [$h0] sliced and paused [$h1]"
  [ "$(echo "$h1" | wc -w)" -ne 2 ] && why="${why:+$why; }expected two hashes, got [$h1]"
  echo "$o1" | grep '"kind":"world"' | grep -q '"gate_leaks":0,"wrong_pack_calls":0' || why="${why:+$why; }a pack script ran on a tick its pack did not get"
  verdict world.sliced_and_paused "$why" "ex_wall on 1 world tick in 8, ex_bounce on 1 in 3 with a 100-tick pause: $h1"
fi

