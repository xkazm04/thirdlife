---
description: Run the Third Life gate and fix what it reports
---
Run `node devx/bin/tl.mjs check --tier fast --changed` (use `--tier full` if engine/kernel, kits, style or seeds changed).
Read the FAIL lines, fix the cause (not the check), rerun until green. Report the final JSON verdict line and any
`flaky-retry-passed` steps. Never edit `contracts/*` or `devx/arch.baseline.json` to make a check pass without saying so.
