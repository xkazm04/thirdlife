# bash docs/reports/astra-trial/d5/repro/r_empty_filter.sh
set -eu
out=docs/reports/astra-trial/d5/repro
result=0
TL_SELFTEST_DIR="$out" bash engine/tools/selftest.sh walk.jmup || result=$?
if [ "$result" -eq 0 ]; then
  echo "REPRO empty_filter: FAIL expected a nonzero status for zero matching cases, got 0"
else
  echo "REPRO empty_filter: PASS status=$result"
fi
