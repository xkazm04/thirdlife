# bash docs/reports/astra-trial/d5/repro/a_walk_filter.sh
set -eu
G='C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe'
for name in jump walk.jump; do
    status=0
    output=$(timeout 120 "$G" --headless --path engine --script res://kernel/world/walks/walk_case.gd -- "$name") || status=$?
    trailer=$(printf '%s\n' "$output" | tr -d '\r' | sed -n '/^WALKCASE done /p')
    printf 'filter=%s exit=%s %s\n' "$name" "$status" "$trailer"
    if [ "$name" = walk.jump ] && [ "$status" -eq 0 ] && [ "$trailer" = 'WALKCASE done 0 0' ]; then
        echo 'REPRO walk_filter: FAIL selected an existing case, ran zero and exited successfully'
    fi
done
