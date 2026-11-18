# BASH_ENV helper for the gate.*_stopped cases (350-bugfix-gate.sh); the runner skips names starting with _.
# Every bash started with BASH_ENV pointing here sources it first: a `world.sh <verb>` child (verb TL_BUGFIX_STOP,
# default same) stops itself before it runs anything (exit 143); every other script carries on unchanged.
if [[ "$0" == */world.sh && "${1:-}" == "${TL_BUGFIX_STOP:-same}" ]]; then
  kill -TERM "$BASHPID"
fi
