# Run packs that fail during loading, simulation or bot play.
# Check the script errors, watchdog outcomes and frame budget.

# ---------------------------------------------------------------- V2
check bad.script_error 1 smoke "--pack=$EX/bad_script_error" --frames=120 -- '"id":"smoke.no_script_errors","ok":false' '"kind":"script_error","file":"scripts/main.gd","line":17'
check bad.parse_error 1 smoke "--pack=$EX/bad_parse_error" --frames=120 -- '"id":"smoke.loads","ok":false' '"kind":"script_error","file":"scripts/main.gd","line":6,"message":"Parse Error'
check bad.watchdog 3 smoke "--pack=$EX/bad_watchdog" --frames=600 -- '"id":"smoke.watchdog","ok":false' '"kind":"watchdog"' 'tick_timeout'
check bad.watchdog_bot 3 bot "--pack=$EX/bad_watchdog" --frames=600 -- '"kind":"watchdog"'
check bad.error_storm 3 smoke "--pack=$EX/bad_error_storm" --frames=600 -- '"id":"smoke.watchdog","ok":false' 'script_errors' '"kind":"script_error","file":"scripts/main.gd","line":16'
check bad.setup_loop 3 smoke "--pack=$EX/bad_setup_loop" --frames=600 -- '"kind":"watchdog"' '_pack_setup did not return'
check bad.bot_never_done 1 bot "--pack=$EX/bad_bot" --frames=300 -- '"id":"bot.completed","ok":false' 'frame_budget'

