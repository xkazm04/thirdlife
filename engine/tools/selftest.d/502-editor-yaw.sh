# The job and draft place the same construction on the editor's X/Z axis.
if [ -z "$FILTER" ] || [[ "site.editor_yaw" == *"$FILTER"* ]]; then
  ey_godot="${TL_GODOT:-C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe}"
  ey_engine="$(cd "$HERE/.." && pwd)"
  if ! ey_dir="$(mktemp -d "$OUT/editor-yaw-XXXXXX")"; then
    verdict site.editor_yaw "could not create fixture directory"
    return
  fi
  if command -v cygpath >/dev/null 2>&1; then
    ey_dir="$(cygpath -am "$ey_dir")"
    ey_engine="$(cygpath -am "$ey_engine")"
  fi
  why=""
  node - "$ey_engine" "$ey_dir" <<'NODE' || why="could not prepare job logs"
const fs = require("node:fs");
const [engine, dir] = process.argv.slice(2);
const lines = fs.readFileSync(engine + "/kernel/world/site/fixtures/arrive/job.jsonl", "utf8").split(/\r?\n/).slice(0, 8);
for (const source of ["legacy", "zero", "job", "draft"]) {
  const created = JSON.parse(lines[0]);
  created.sentence += " " + source;
  const lot = {at: [5, -12], radius: 32, yaw_deg: source === "zero" ? 0 : 30};
  if (source === "draft") {
    fs.mkdirSync(dir + "/_editor");
    fs.writeFileSync(dir + "/_editor/test.json", JSON.stringify({schema: "tl.editor-draft/1", request: created.sentence, lot}));
  } else if (source !== "legacy") {
    created.lot = lot;
  }
  fs.mkdirSync(dir + "/" + source);
  fs.writeFileSync(dir + "/" + source + "/job.jsonl", [JSON.stringify(created), ...lines.slice(1), ""].join("\n"));
}
NODE
  if [ -z "$why" ]; then
    MSYS_NO_PATHCONV=1 "$ey_godot" --headless --fixed-fps 60 --quit-after 12000 --path "$ey_engine" \
      --script res://kernel/world/site/fixtures/editor_yaw.gd -- "$ey_dir" >"$ey_dir/proof.log" 2>&1 || why="Godot exited $?"
    if grep -qE '^(SCRIPT ERROR|ERROR):' "$ey_dir/proof.log" || ! grep -q '^SITE EDITOR YAW OK' "$ey_dir/proof.log"; then
      why="yaw proof did not finish cleanly: $(grep -m1 -E '^(SCRIPT ERROR|ERROR):' "$ey_dir/proof.log")"
    fi
    grep '^Zero-yaw' "$ey_dir/proof.log"
  fi
  verdict site.editor_yaw "$why" "four crane/bay boxes, two rail walls, job and draft, repeat build"
  rm -rf -- "$ey_dir"
fi
