# Record a declared mouse button and its keyboard equivalent as game actions.
# needs: OUTW and p7_play from 110-p7.sh.

# --- K2d ---
# A mouse button as a declared action key: ex_down declares "knock" on K and the left button. In a scripted session
# without a window the left button held frames 90..95 reaches the game as "knock" in exactly those frames (recorded
# like a key), the right button (not declared) does not, and the K key still does.
if [ -z "$FILTER" ] || [[ "k2.button" == *"$FILTER"* ]]; then
  BREC="$OUTW/k2_button.input.json"; rm -f "$BREC"
  p7_play k2_button "$EX/ex_down" 200 '[[90,"button","left",1],[96,"button","left",0],[120,"button","right",1],[126,"button","right",0],[150,"key","K",1],[153,"key","K",0]]' "$BREC"
  got="$(grep -o '\[[0-9]*,"knock",1\]' "$BREC" 2>/dev/null | grep -o '^\[[0-9]*' | tr -d '[' | tr '\n' ' ')"
  want="$( (seq 90 95; seq 150 152) | tr '\n' ' ')"
  why=""; [ "$got" = "$want" ] || why="the game saw knock in frames [$got], expected 90..95 (left button) and 150..152 (K)"
  verdict k2.button_is_a_key "$why" "ex_down: knock from the left button in 6 frames, not from the right button, from K in 3"
fi

