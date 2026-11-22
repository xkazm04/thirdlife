# The actual village builder supplies the reference heightfield.
home_selected=0
for home_case in determinism extent reach chunk village; do
  [[ "home.a.$home_case" == *"$FILTER"* ]] && home_selected=1
done
if [ "$home_selected" -eq 1 ]; then
  home_engine="$(cygpath -m "$(realpath "$HERE/..")")"
  export TL_HOME_TEST="$(cygpath -m "$OUT")/home-a"
  home_log="$TL_HOME_TEST/check.log"
  mkdir -p "$TL_HOME_TEST"
  home_code=0
  TL_STYLE=crisp MSYS_NO_PATHCONV=1 "${TL_GODOT:-C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe}" --headless --fixed-fps 60 --quit-after 500 --path "$home_engine" --script "$home_engine/kernel/world/home/verify.gd" > "$home_log" 2>&1 || home_code=$?
  for home_case in determinism extent reach chunk village; do
    home_line="$(grep -F "PASS home.a.$home_case " "$home_log" | tr -d '\r')"
    home_error=""
    if [ -z "$home_line" ] || [ "$home_code" != 0 ] || grep -qE '^SCRIPT ERROR|^ERROR:' "$home_log"; then home_error="generator exit $home_code; see $home_log"; fi
    verdict "home.a.$home_case" "$home_error" "${home_line#PASS home.a.$home_case }"
  done
fi
