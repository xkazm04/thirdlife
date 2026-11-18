# bash docs/reports/astra-trial/d5/repro/r_stopped_world.sh
# When Bash sources this file during startup of the nested world test, stop that
# specific child before its first verdict. The parent selftest runs normally.
if [[ "${BASH_SOURCE[0]}" != "$0" ]]; then
  if [[ "$0" == */world.sh && "$1" == same ]]; then
    kill -TERM "$BASHPID"
  fi
  return
fi

set -eu
export BASH_ENV="$PWD/${BASH_SOURCE[0]}"
child_status=0
bash engine/tools/world.sh same --packs=pack_min || child_status=$?
echo "Stopped world.sh control exit=$child_status"
[ "$child_status" -eq 143 ] || exit 1
result=0
TL_SELFTEST_DIR=docs/reports/astra-trial/d5/repro \
  bash engine/tools/selftest.sh world.same || result=$?
if [ "$result" -eq 0 ]; then
  echo "REPRO stopped_world: FAIL world.same returned success after the world.sh child stopped before its first hash"
else
  echo "REPRO stopped_world: PASS exit=$result"
fi
