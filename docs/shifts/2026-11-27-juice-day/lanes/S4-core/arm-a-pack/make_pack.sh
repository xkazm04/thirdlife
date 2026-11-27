#!/bin/bash
# S4-core: rebuild an arm's pack from its base and this overlay (the overlay's .gd.txt files are the pack's .gd scripts; stored
# as text so the repository's uid rule does not read them as engine scripts).
#   make_pack.sh <base pack dir> <overlay subdir: hand | editor | gen_hip> <out dir>
# Bases: hand = the J1 hand pack (.tl/proof-games/arsenal_meteor_hand, v0.1.22); editor = Create's v0.1.23
# (.tl/jobs/three-against-three-hockey-20261125-1/promoted/game.three_against_three_hockey@0.1.23); gen_hip = the job copy's v0.1.24.
set -e
here="$(cd "$(dirname "$0")" && pwd)"
base="$1"; sub="$2"; out="$3"
[ -d "$base" ] && [ -d "$here/$sub" ] && [ -n "$out" ] || { echo "usage: make_pack.sh <base pack> <hand|editor|gen_hip> <out>"; exit 2; }
rm -rf "$out"; cp -r "$base" "$out"
(cd "$here/$sub" && find . -type f) | while read -r f; do
  dest="$out/${f%.txt}"; case "$f" in *.gd.txt) ;; *) dest="$out/$f";; esac
  mkdir -p "$(dirname "$dest")"; cp "$here/$sub/$f" "$dest"
done
echo "made $out"
