#!/bin/bash
# room.sh: is there room on the shared machine for a heavy step (a Foreman job, a Godot run, a C++ build, a lab check)?
# The owner's limits for the night of 27 Nov 2026: RAM used at most 80 %, no CPU cap (another session develops too).
#   bash room.sh          prints one line; exit 0 = room, 1 = no room now
#   bash room.sh --wait   waits (re-checking every 60 s, at most 45 min) until there is room; exit 0, or 1 after 45 min
# CPU is the mean of three samples 5 s apart. Never kill anything to make room: wait.
RAM_MAX=${ROOM_RAM_MAX:-80}; CPU_MAX=${ROOM_CPU_MAX:-100}
probe() {
  powershell -NoProfile -c "\$o=Get-CimInstance Win32_OperatingSystem; \$r=[math]::Round(100-100*\$o.FreePhysicalMemory/\$o.TotalVisibleMemorySize); \$c=@(); 1..3 | % { \$c += (Get-CimInstance Win32_Processor | Measure-Object -Property LoadPercentage -Average).Average; Start-Sleep -Seconds 5 }; \$m=[math]::Round((\$c | Measure-Object -Average).Average); \"\$r \$m\"" | tr -d '\r'
}
check() {
  read RAM CPU < <(probe)
  if [ "$RAM" -le "$RAM_MAX" ] && [ "$CPU" -le "$CPU_MAX" ]; then echo "room: RAM ${RAM}% (max $RAM_MAX), CPU ${CPU}% (max $CPU_MAX)"; return 0; fi
  echo "no room: RAM ${RAM}% (max $RAM_MAX), CPU ${CPU}% (max $CPU_MAX)"; return 1
}
if [ "$1" = "--wait" ]; then
  for i in $(seq 1 45); do check && exit 0; sleep 45; done; echo "no room after 45 min: say so in STANDUP.md and keep doing light work"; exit 1
fi
check
