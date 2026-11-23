# Paused 23:10 (owner: "Pause the processes, I will switch plan to access Fable again")

At 23:00 the Fable lanes (K2 figure, K6 arena, K7 look, K8 balance) hit the Fable usage limit (resets 29 Nov 17:00);
the Director restarted them on Opus, then the owner paused everything. All lane agents and the hourly standup timer are
stopped. Nothing was lost: every lane's work is in its worktree.

## On `hokej` (head f9d2db9, not pushed; main has documents only)
K1 core r1-r4, K2 figure r1-r5, K3 shell r1-r9, K4 reference, K5 screen r1-r4, K6 arena r1 (the hall), K7 look r1-r2.
Kernel 1.26. Last exe: hk-int/dist at 2bede87 (before the hall). Director's merged-head check was stopped mid-run.

## Where each lane stands (resume each with its brief + this list)
| Lane | Tree | State | Resume with |
|---|---|---|---|
| K1 core | hk-core | r5 just begun (D3D12 export guard first) | Controls selftests; thirdlife variant selection; D3D12 guard; Jam.Controls extraction |
| K2 figure | hk-figure | r6 not started (or barely) | the thrown-victim check; last family (abilities, dash, dive, celebrations) on thirdjam's sandbox cartridge; slide dust |
| K3 shell | hk-shell | r10 started | thirdjam's puck (8 cm, glow); a playtester-decided bot playing a whole match from the exe; fresh exe |
| K5 screen | hk-hud | r5 started | wire K1's Controls fields (possession, pass-target ring, take grace); controls panel per HEAD |
| K6 arena | hk-arena | r2 (sound) half: 579 assets exported, MetaSounds read | event table, kernel audio (1.27), wiring from snapshot events |
| K7 look | hk-look | r3 (shadows) not started | thirdjam's figure shadows on the ice; patch / shoulder colour; edge ink |
| K8 balance | hk-balance | r1 in progress, uncommitted: planning hand, HOCKEY-BALANCE.md, thirdlife patches, E01b kept, E02 running | finish E02 / E00, validate the planning hand, round 1 report |

## Before resuming
- Re-run on hk-int at f9d2db9: `rink.sh build` (CLI for rink.playtester_seat), import, selftests rink / rig.skater /
  look.skater / arena / hokej / dungeon / budget, the hokej bots, fast tier.
- Re-arm the standup timer (`/shift standup 2026-11-24-night`, hourly at :23).
