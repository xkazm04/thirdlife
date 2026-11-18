# Give the runner a missing pack, an unknown verb and a bad option.
# Each request must produce a not_run report.

# ---------------------------------------------------------------- could not run
check norun.missing_pack 2 smoke "--pack=$EX/no_such_pack" -- '"kind":"load"'
check norun.bad_verb 2 dance "--pack=$EX/pack_min" -- '"kind":"engine"'
check norun.bad_option 2 smoke "--pack=$EX/pack_min" --speed=9 -- 'unknown option --speed'

