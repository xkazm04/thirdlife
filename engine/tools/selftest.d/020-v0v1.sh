# Exercise the V0 and V1 lint rules with deliberately bad packs.
# Check the reported file, line and pattern for each violation.

# ---------------------------------------------------------------- V0 / V1
check bad.schema 1 lint "--pack=$EX/bad_schema" -- '"id":"lint.schema","ok":false' '"kind":"schema","file":"pack.json","line":9,"message":"unknown key .author.'
check bad.schema_smoke 2 smoke "--pack=$EX/bad_schema" -- '"kind":"schema"'
check bad.layout 1 lint "--pack=$EX/bad_layout" -- '"id":"lint.layout","ok":false' '"kind":"layout","file":"stray.md"' '"kind":"layout","file":"tests/missing.gd"' '"kind":"layout","file":"data/notes.txt"'
check bad.fence 1 lint "--pack=$EX/bad_fence" -- '"id":"lint.fence","ok":false' '"kind":"fence","file":"scripts/fence.gd","line":1,"message":".class_name. is outside the fence'
if [ -z "$FILTER" ] || [[ "bad.fence_each_line" == *"$FILTER"* ]]; then
  want="$( (echo 1; awk '/^# FENCE BEGIN/{f=1;next}/^# FENCE END/{f=0}f{print NR}' "$EX/bad_fence/scripts/fence.gd") | sort -n | tr '\n' ' ')"
  got="$(grep -o '"kind":"fence","file":"scripts/fence.gd","line":[0-9]*' "$(report_of bad.fence)" | grep -o '[0-9]*$' | sort -n | tr '\n' ' ')"
  why=""; [ "$want" != "$got" ] && why="fence lines reported [$got] expected [$want]"
  verdict bad.fence_each_line "$why" "$(echo $want | wc -w | tr -d ' ') fenced patterns, each reported once with its line; comments and strings ignored"
fi
check bad.capability 1 lint "--pack=$EX/bad_capability" -- '"id":"lint.capabilities","ok":false' '"kind":"capability","file":"scripts/main.gd","line":6'
check bad.capability_run 1 smoke "--pack=$EX/bad_capability" --frames=10 -- '"kind":"script_error","file":"scripts/main.gd","line":6,"message":"TLBodies needs the capability .physics.'
check bad.bypass 0 lint "--pack=$EX/bad_bypass" -- '"primitive":"TLRules","file":"scripts/main.gd","line":4' '"file":"scripts/main.gd","line":10,"pattern":"RigidBody3D.new\(\)"' '"line":16,"pattern":"Area3D.new\(\)"' '"line":21,"pattern":"apply_impulse"'
check bad.bypass_kit_part 0 lint "--pack=$EX/bad_bypass" -- '"kit_parts_added":1,'
# look and geometry made by hand (WP5b): materials and lights are `style` bypasses in scripts/, gen/ and tests/; meshes
# are `kit` bypasses in scripts/ and tests/; a generator's geometry stays in kit_parts_added and is not counted twice
check bad.bypass_look 0 lint "--pack=$EX/bad_bypass" -- '"primitive":"style","file":"scripts/main.gd","line":29,"pattern":"StandardMaterial3D.new\(\)"' '"primitive":"style","file":"scripts/main.gd","line":30,"pattern":"DirectionalLight3D.new\(\)"' '"primitive":"kit","file":"scripts/main.gd","line":31,"pattern":"BoxMesh.new\(\)"' '"primitive":"kit","file":"scripts/main.gd","line":32,"pattern":"MeshInstance3D.new\(\)"' '"primitive":"style","file":"gen/part.gd","line":9,"pattern":"ShaderMaterial.new\(\)"' '"kit_parts_added":1,'
if [ -z "$FILTER" ] || [[ "bad.bypass_gen_not_double_counted" == *"$FILTER"* ]]; then
  why=""; grep -q '"primitive":"kit","file":"gen/' "$(report_of bad.bypass_look)" 2>/dev/null && why="geometry in gen/ was also listed as a kit bypass"
  [ -s "$(report_of bad.bypass_look)" ] || why="no bad.bypass_look report"
  verdict bad.bypass_gen_not_double_counted "$why" "gen/part.gd: ArrayMesh and MeshInstance3D only in kit_parts_added"
fi
check bad.size 1 lint "--pack=$EX/bad_size" -- '"id":"lint.size","ok":false' '"kind":"size","file":"scripts/big.gd","line":601'
check bad.nondeterminism_lint 1 lint "--pack=$EX/bad_nondeterminism" -- '"kind":"fence","file":"scripts/main.gd","line":8,"message":".randf\(. is outside the fence'
for p in assets filetype reflection classes tree alias load; do
  check "bad.reach_$p" 1 lint "--pack=$EX/bad_reach_$p" -- '"id":"lint.fence","ok":false'
done

