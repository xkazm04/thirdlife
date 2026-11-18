#!/bin/bash
# Kernel self-test: bash engine/tools/selftest.sh [name-filter] (or tl.sh selftest [name-filter]).
# One PASS/FAIL line per case; exit code 0 only when every case passed.
# No case reads the wall clock. Reports stay in $TL_SELFTEST_DIR (default: a temporary directory).
# Add cases in engine/tools/selftest.d/NNN-<lane-or-topic>.sh. Pick an unused number; C sort order is run order.
# Start with a short description and close all shell constructs in the file. Names starting with _ are skipped.
# Blocks share check, verdict, field, number, report_of and $HERE $TL $EX $OUT $FILTER.
# check filters by case-name substring. Guard work outside check with the same test, e.g.
#   if [ -z "$FILTER" ] || [[ "lane.case" == *"$FILTER"* ]]; then ...; fi
# See selftest.d/README.md for examples. Never edit selftest.sh to add tests.
HERE="$(cd "$(dirname "$0")" && pwd)"
TL="$HERE/tl.sh"
EX="$HERE/../kernel/examples"
OUT="${TL_SELFTEST_DIR:-${TMPDIR:-${TEMP:-/tmp}}/tl_selftest_$$}"
mkdir -p "$OUT"
FILTER="$1"
pass=0; fail=0

report_of() { echo "$OUT/$1.json"; }

# check <name> <expected exit> <verb and args...> [-- <ERE the report must match>...]
check() {
  local name="$1" want="$2"; shift 2
  if [ -n "$FILTER" ] && [[ "$name" != *"$FILTER"* ]]; then return; fi
  local args=() pats=() in_pats=0
  for a in "$@"; do
    if [ "$a" = "--" ]; then in_pats=1; elif [ $in_pats -eq 1 ]; then pats+=("$a"); else args+=("$a"); fi
  done
  local rep; rep="$(report_of "$name")"; rm -f "$rep"
  local last; last="$(TL_QUIET=1 bash "$TL" "${args[@]}" "--report=$rep")"; local got=$?
  local why=""
  [ "$got" != "$want" ] && why="exit code $got, expected $want"
  if [ ! -s "$rep" ]; then
    why="${why:+$why; }no report file"
  else
    [ "$(tr -d '\r\n' < "$rep")" != "$(echo "$last" | tr -d '\r\n')" ] && why="${why:+$why; }the last stdout line is not the report"
    grep -q '"schema":"tl.verify/1"' "$rep" || why="${why:+$why; }schema missing"
    local agree=0
    case "$got" in
      0) grep -q '"ok":true,"outcome":"passed"' "$rep" && agree=1;;
      1) grep -q '"ok":false,"outcome":"failed"' "$rep" && agree=1;;
      2) grep -q '"ok":false,"outcome":"not_run"' "$rep" && agree=1;;
      3) grep -q '"ok":false,"outcome":"watchdog"' "$rep" && agree=1;;
    esac
    [ $agree -eq 0 ] && why="${why:+$why; }outcome does not agree with exit code $got"
    for p in "${pats[@]}"; do
      grep -Eq -- "$p" "$rep" || why="${why:+$why; }report lacks /$p/"
    done
  fi
  verdict "$name" "$why"
}

verdict() {
  if [ -n "$FILTER" ] && [[ "$1" != *"$FILTER"* ]]; then return; fi
  if [ -z "$2" ]; then echo "PASS $1${3:+  ($3)}"; pass=$((pass+1)); else echo "FAIL $1: $2"; fail=$((fail+1)); fi
}

field() { grep -o "\"$2\":\"[^\"]*\"" "$(report_of "$1")" 2>/dev/null | head -1 | cut -d'"' -f4; }
number() { grep -o "\"$2\":[-0-9.e]*" "$(report_of "$1")" 2>/dev/null | head -1 | cut -d: -f2; }

# Sort the glob in the C locale while preserving the caller's locale for the tests.
mapfile -d '' -t selftest_blocks < <(export LC_ALL=C; printf '%s\0' "$HERE"/selftest.d/*.sh)
selftest_found=0
for selftest_block in "${selftest_blocks[@]}"; do
  [[ -f "$selftest_block" && ${selftest_block##*/} != _* ]] || continue
  selftest_found=$((selftest_found + 1))
  if ! bash -n "$selftest_block"; then
    FILTER="" verdict "selftest.d.${selftest_block##*/}" "does not parse"
    continue
  fi
  source "$selftest_block"
done
# A run that found no block is never a pass (docs/GATE-HONESTY.md).
[ "$selftest_found" -gt 0 ] || FILTER="" verdict selftest.blocks "no block found in $HERE/selftest.d"

echo "selftest: $pass passed, $fail failed (reports in $OUT)"
[ $fail -eq 0 ]
