# bash docs/reports/astra-trial/d5/repro/r_clip_input.sh
set -eu
scratch=$(mktemp -d docs/reports/astra-trial/d5/repro/r_clip_XXXXXX)
trap 'rm -f "$scratch/film.avi"; rmdir "$scratch"' EXIT
# Stand-in for an existing source movie. The invalid kind should reject the
# command before running Godot, FFmpeg, or touching neighboring files.
echo "existing source movie" > "$scratch/film.avi"
code=0
bash engine/tools/look.sh clip rig:typo "$scratch/film.mp4" || code=$?
if [ "$code" -eq 2 ] && [ ! -e "$scratch/film.avi" ]; then
  echo "REPRO clip_input: FAIL invalid kind exited 2 and deleted the pre-existing film.avi beside the requested film.mp4"
else
  echo "REPRO clip_input: exit=$code existing AVI present=$(test -e "$scratch/film.avi" && echo yes || echo no)"
fi
