# Kernel selftest blocks

Run `bash engine/tools/selftest.sh [name-filter]` from the repo root. For example, `bash engine/tools/selftest.sh verbs.` runs the cases whose names contain the literal substring `verbs.`. An empty filter runs the suite. A filter that selects no case exits 2 (could not run), never 0.

No case reads the wall clock. Measure simulation time in physics frames (60 Hz).

Add a file named `NNN-<lane-or-topic>.sh` in this directory. Pick an unused three-digit number. The C locale's filename sort order determines execution order, so a number between two existing blocks inserts your cases between them. The runner skips names starting with `_` and files with other extensions. Never edit selftest.sh to add tests.

Start with two to four comment lines describing the cases. The runner checks each block with `bash -n` before sourcing it. A syntax error produces a failing verdict and the run continues with the next file. Close every conditional, loop and function in the same file. Blocks share one shell and the same verdict counters. Keep block-specific helpers with their cases. If you use a variable, function or report from an earlier block, add a `# needs: ... from NNN-topic.sh` comment at the top.

| Helper | Use |
| --- | --- |
| `check NAME EXIT VERB ARGS... [-- ERE...]` | Run the verb, check its exit code and JSON report, and match each optional regular expression against the report. |
| `verdict NAME REASON [NOTE]` | An empty reason prints PASS with the optional note. A nonempty reason prints FAIL with the reason. |
| `report_of NAME` | Print the path of the case's JSON report. |
| `field NAME KEY` / `number NAME KEY` | Read the first matching string or numeric field from that report. |

`$HERE` is the tools directory, `$TL` is the runner wrapper, and `$EX` holds the kernel examples. Use `$OUT` for reports and scratch files. Set `TL_SELFTEST_DIR` to choose that directory.

`check` and `verdict` filter their own case names. Guard work outside `check` with the same `$FILTER` test, including setup, command substitutions and cleanup. For example, a block can check the verb manifest without starting Godot.

```bash
# Check that the verb manifest declares the expected schema.
# This reads the same file the runner ships.
if [ -z "$FILTER" ] || [[ "example.verbs_schema" == *"$FILTER"* ]]; then
  why=""
  grep -q '"schema": "tl.verbs/1"' "$HERE/../kernel/runner/verbs.json" || why="missing tl.verbs/1 schema"
  verdict example.verbs_schema "$why"
fi
```
