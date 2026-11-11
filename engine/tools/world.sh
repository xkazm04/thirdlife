#!/bin/bash
# N2: several packs alive in one process (kernel/world/). Not a verify verb: no tl.verify/1 report.
#
#   world.sh run --packs=<a>,<b>,... [--frames=N] [--seeds=1,2,..] [--at=x:y:z,..] [--spacing=M] [--every=N,..]
#                [--pause=<i|all>:<from>:<ticks>;..] [--mode=smoke|bot] [--space=own|shared] [--trace=N] [--hold=N]
#                [--state=1] [--out=<file>]
#       one JSON line per pack (its state hash; "kind":"pack") and one for the world ("kind":"world"), tl.world/1.
#       A pack is a directory, or a bare name looked up in seeds/, kernel/examples/, kernel/world/packs/ and packs/.
#       List options take one value per pack or one value for all.
#   world.sh same --packs=<a>,<b>,... [options of run]
#       the acceptance check: every pack alone, then all together, three times; PASS when every pack's hash
#       together equals its hash alone, every time.
#   world.sh bench [--only=<test>] [--quick]
#       the measurements; writes kernel/world/BENCH.md and kernel/world/bench.json.
#
# Env: TL_GODOT (Godot console exe), TL_ENGINE_DIR (this engine/ directory), TL_RAW=1 (also print the engine's lines).
G="${TL_GODOT:-C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe}"
E="${TL_ENGINE_DIR:-$(cd "$(dirname "$0")/.." && pwd)}"
if command -v cygpath >/dev/null 2>&1; then
  E="$(cygpath -m "$E")"
  G="$(cygpath -m "$G")"
fi

resolve_pack() {
  local v="$1"
  case "$v" in res://*) echo "$v"; return;; esac
  if [ ! -d "$v" ]; then
    for base in seeds kernel/examples kernel/world/packs packs; do
      if [ -d "$E/$base/$v" ]; then echo "$E/$base/$v"; return; fi
    done
  fi
  if command -v cygpath >/dev/null 2>&1; then
    case "$v" in /*|[A-Za-z]:*) cygpath -m "$v";; *) cygpath -m "$PWD/$v";; esac
  else
    echo "$v"
  fi
}

fix_arg() {
  local a="$1"
  case "$a" in
    --packs=*)
      local v="${a#*=}" out="" item
      IFS=',' read -ra items <<< "$v"
      for item in "${items[@]}"; do out="${out:+$out,}$(resolve_pack "$item")"; done
      echo "--packs=$out";;
    --out=*|--out-dir=*)
      local k="${a%%=*}" v="${a#*=}"
      if command -v cygpath >/dev/null 2>&1; then
        case "$v" in /*|[A-Za-z]:*) v="$(cygpath -m "$v")";; *) v="$(cygpath -m "$PWD/$v")";; esac
      fi
      echo "$k=$v";;
    *) echo "$a";;
  esac
}

godot_mode() {   # godot_mode <mode> <args...>: the tl.world/1 lines on stdout; the exit code is the engine's
  local mode="$1"; shift
  local args=()
  for a in "$@"; do args+=("$(fix_arg "$a")"); done
  if [ -n "$TL_RAW" ]; then
    MSYS_NO_PATHCONV=1 MSYS2_ARG_CONV_EXCL='*' "$G" --headless --fixed-fps 60 --path "$E" res://kernel/host/host.tscn -- "$mode" "${args[@]}"
    return $?
  fi
  MSYS_NO_PATHCONV=1 MSYS2_ARG_CONV_EXCL='*' "$G" --headless --fixed-fps 60 --path "$E" res://kernel/host/host.tscn -- "$mode" "${args[@]}" 2>/dev/null \
    | tr -d '\r' | grep -E '^(\{"schema":"tl\.world/1"|\[bench\])'
  return "${PIPESTATUS[0]}"
}

hashes_of() { grep '"kind":"pack"' | sed -E 's/.*"index":([0-9]+).*"state_hash":"([0-9a-f]{16}).*/\1 \2/'; }

case "$1" in
  run)
    shift; godot_mode world "$@"; exit $?;;
  bench)
    shift; godot_mode world-bench "$@"; exit $?;;
  same)
    shift
    packs=""; rest=()
    for a in "$@"; do case "$a" in --packs=*) packs="${a#*=}";; *) rest+=("$a");; esac; done
    [ -z "$packs" ] && { echo "world.sh same: --packs=<a>,<b>,... is required"; exit 2; }
    IFS=',' read -ra items <<< "$packs"
    fail=0
    solo=()
    for i in "${!items[@]}"; do
      h="$(godot_mode world "--packs=${items[$i]}" "${rest[@]}" | hashes_of | cut -d' ' -f2)"
      solo+=("$h"); echo "alone     ${items[$i]}: ${h:-NO HASH}"
      [ -z "$h" ] && fail=1
    done
    for run in 1 2 3; do
      out="$(godot_mode world "--packs=$packs" "${rest[@]}")"
      while read -r idx h; do
        [ -z "$idx" ] && continue
        verdict="same"; [ "$h" != "${solo[$idx]}" ] && { verdict="DIFFERENT (alone ${solo[$idx]})"; fail=1; }
        echo "together $run ${items[$idx]} [#$idx]: $h $verdict"
      done <<< "$(echo "$out" | hashes_of)"
      [ "$(echo "$out" | hashes_of | wc -l)" -ne "${#items[@]}" ] && { echo "together $run: not every pack reported a hash"; fail=1; }
      echo "$out" | grep '"kind":"world"' | grep -o '"gate_leaks":[0-9]*\|"wrong_pack_calls":[0-9]*\|"script_errors":[0-9]*\|"engine_errors":[0-9]*\|"contact_or_body_limit_warnings":[0-9]*' | tr '\n' ' '; echo
    done
    [ $fail -eq 0 ] && echo "PASS world.same: every pack hashes together as it does alone, three runs" || echo "FAIL world.same"
    exit $fail;;
  *)
    sed -n '2,17p' "$0"; exit 2;;
esac
