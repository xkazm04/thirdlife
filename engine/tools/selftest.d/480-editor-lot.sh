# E6 (editor lane, 19 Nov): a game made in the workbench rises on the lot the player chose. The site reads the
# workbench's draft (<jobs root>/_editor/*.json, found by the job's sentence) and moves the walk's lot there with the
# player's ring; a job without a draft keeps the walk's lot. One headless world with two lots on copies of the
# arrive fixture: lot 0 has a draft (at 100,-30, radius 26), lot 1 has none (stays at -40,60, radius 30). A fresh
# extent cache, so a ring measured earlier on this machine (site.ring) does not decide the radius.
if [ -z "$FILTER" ] || [[ "site.editor_lot" == *"$FILTER"* ]]; then
  el_godot="${TL_GODOT:-C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe}"
  el_engine="$(cd "$HERE/.." && pwd)"
  el_dir="$OUT/editor-lot"; rm -rf "$el_dir"; mkdir -p "$el_dir/jobs/_editor" "$el_dir/plain"
  if command -v cygpath >/dev/null 2>&1; then el_engine="$(cygpath -m "$el_engine")"; el_dir="$(cygpath -m "$el_dir")"; fi
  cp -R "$el_engine/kernel/world/site/fixtures/arrive" "$el_dir/jobs/bounce"
  cp -R "$el_engine/kernel/world/site/fixtures/arrive" "$el_dir/plain/bounce"
  el_sentence="$(head -n 1 "$el_dir/jobs/bounce/job.jsonl" | sed -E 's/.*"sentence":"([^"]*)".*/\1/')"
  printf '{"schema":"tl.editor-draft/1","sentence":"bounce","request":"%s","answers":{},"footprint":{"size_m":[30,20],"height_m":3,"estimate":true},"lot":{"at":[100.0,-30.0],"yaw_deg":15.0,"radius":26}}\n' "$el_sentence" > "$el_dir/jobs/_editor/bounce-1.json"
  printf '{"schema":"tl.walk/1","name":"editor_lot","visitor":true,"ticks":60,"mode":"bot","plots":[{"id":"a","pack":"pack_min","origin":[-120,0,0],"seed":1}],"landscape":{"lots":[{"at":[40,0],"radius":30,"h":0,"job":"%s/jobs/bounce","replay":{"ticks_per_event":20}},{"at":[-40,60],"radius":30,"h":0,"job":"%s/plain/bounce","replay":{"ticks_per_event":20}}]},"player":[[0,[0,0,40]]]}\n' "$el_dir" "$el_dir" > "$el_dir/walk.json"
  el_out="$(TL_CACHE_DIR="$el_dir/cache" MSYS_NO_PATHCONV=1 "$el_godot" --headless --fixed-fps 60 --path "$el_engine" res://kernel/host/host.tscn -- world "--walk=$el_dir/walk.json" 2>&1 | tr -d '\015')"
  el_rc=$?
  el_l0="$(echo "$el_out" | grep '^\[site\] {' | grep -o '{"lot":0,[^]]*][^}]*}[^}]*}')"
  el_l1="$(echo "$el_out" | grep '^\[site\] {' | grep -o '{"lot":1,[^]]*][^}]*}[^}]*}')"
  why=""
  [ -n "$el_l0" ] || why="no [site] report for lot 0 (the world did not finish): $(echo "$el_out" | grep -E 'SCRIPT ERROR|rror' | head -2 | tr '\n' ' ')"
  echo "$el_l0" | grep -q '"lot_from":"workbench draft bounce-1.json"' || why="${why:+$why; }lot 0 does not name the draft: $el_l0"
  echo "$el_l0" | grep -q '"at":\[100.0,-30.0\]' || why="${why:+$why; }lot 0 is not at 100,-30: $(echo "$el_l0" | grep -o '"at":\[[^]]*\]')"
  echo "$el_l0" | grep -q '"radius":26.0' || why="${why:+$why; }lot 0 does not have the player's 26 m ring: $(echo "$el_l0" | grep -o '"radius":[0-9.]*')"
  echo "$el_l1" | grep -q '"lot_from"' && why="${why:+$why; }lot 1 (no draft) was moved: $el_l1"
  echo "$el_l1" | grep -q '"radius":30.0' || why="${why:+$why; }lot 1 lost the walk's 30 m: $(echo "$el_l1" | grep -o '"radius":[0-9.]*')"
  echo "$el_out" | grep -q '^\[site\] lot 0: at \[100.0, -30.0\], radius 26.0 m, from the workbench draft bounce-1.json' || why="${why:+$why; }no '[site] lot 0: ... from the workbench draft' line"
  echo "$el_out" | grep -q '^\[tl\] world done' || why="${why:+$why; }the world did not end (no '[tl] world done')"
  verdict site.editor_lot "$why" "lot 0 from the draft at 100,-30 ring 26 m; lot 1 without a draft stays at the walk's lot ($(echo "$el_l1" | grep -o '"radius":[0-9.]*'))"
fi
