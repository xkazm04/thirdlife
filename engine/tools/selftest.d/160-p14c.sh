# Scan the shell tools for a quoted line break after tr -d.
# Deleting newlines here would erase the boundaries between log records.

# --- P14c ---
# The tools' log filters drop carriage returns with tr. When an editor turned `tr -d '<CR>'` into a quoted line break,
# view.sh deleted every newline of the window's log and `view.sh check` found no hash at all. No quoted line break
# may follow `tr -d` in any tool; the escape `'\r'` is the safe spelling.
if [ -z "$FILTER" ] || [[ "world.tools_tr_filter" == *"$FILTER"* ]]; then
  bad_tr="$(grep -n "tr -d [\"']\$" "$HERE"/*.sh "$HERE"/selftest.d/*.sh 2>/dev/null | tr '\n' ' ')"
  verdict world.tools_tr_filter "${bad_tr:+a quoted line break after tr -d: $bad_tr}" "no tool deletes newlines from a log by a mangled tr -d"
fi

