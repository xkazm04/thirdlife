# Day run, 25 Nov 2026: editor hardening + games made through the editor

**The owner (25 Nov, morning), verbatim:** "we will spend most of daily run builders for editor hardening, one to build
derivation of the hockey game through it from lenses of players. Multiple to start game from scratch and see whether
iterations can lead the user into outputs with similar quality." Then: "1,2,4 today 5,11,19 dynamically based on PC
resources today or tomorrow. We should keep PC busy at around 50-70% RAM and 70% CPU max knowing other processes are
developing today too. Again consider when fit using Fable, Opus, Sonnet based on task complexity during the day".

Games (numbers from docs/shifts/2026-11-24-night/VERDICT.md; concept + target images in
docs/shifts/2026-11-24-night/concepts/): today **1 Arsenal hockey** (derivation on the rink core), **2 Robot soccer**,
**4 Half-court 3 v 3** (from scratch); when the machine has room, today or tomorrow: **5 Bumper-kart football**,
**11 Biplane duel**, **19 Shield wall**.

## The machine
- Limits: RAM used at most 70 %, CPU at most 70 % (other sessions develop on this machine). Aim: 50-70 % RAM.
- Every heavy step (a Foreman job start, a Godot run, a C++ build, a lab check, a test suite) is preceded by
  `bash C:/Users/kazda/kiro/third-life/docs/shifts/2026-11-25-day/tools/room.sh --wait`. Never kill anything to make room.
- At most 5 agents at once (owner, 24 Nov). The later games start when a lane finishes AND room.sh says room.

## Lanes
| Lane | Model (why) | Tree / branch | Owns |
|---|---|---|---|
| H1 critic and checks | Opus (engineering) | d25-hard-a | foreman quality/shots/coregate/rinkjudge/fastchange, `engine/cores/rink/lab/check_cartridge.mjs`, the merge gate's kit check |
| H2 core and base | Opus (C++ glue + base) | d25-hard-b | `engine/cores/rink/native/glue/**`, SNAPSHOT.md, the rink DLLs, `engine/templates/rink_game/**` + hokej's shared files (byte-equal), foreman base upgrade, Create My games |
| G1 Arsenal hockey | Fable (design judged through three player lenses) | d25-arsenal | its real jobs and proof docs only |
| G2 Robot soccer | Opus (drive Create, diagnose the editor) | d25-robot | its real jobs and proof docs only |
| G4 Half-court 3 v 3 | Opus | d25-court | its real jobs and proof docs only |
| later: G5, G11, G19 | Opus, or Sonnet for a game whose route is already proven | new trees | as G2 |
| later: H3 small editor fixes | Sonnet (exact, mechanical) | new tree | as listed by the Director |

Game lanes play the PERSON: they never edit foreman/ or engine/ code; what blocks them goes to the Director (who routes
it to H1/H2) and they carry on. Editor fixes land on main; the Director fast-forwards a game lane's tree and rebuilds.

## Landing
Lanes land on main as each round is proven (the owner's word of 25 Nov: merge progress right away), Director-verified:
fast tier on the merged tree, foreman npm test when foreman changed, the touched selftest blocks, world when the engine
changed. Not pushed unless the owner asks. Standups hourly at :41 (`standups/HHMM.md`).

## Launched (25 Nov ~12:25)
| Lane | Model | Tree | Agent |
|---|---|---|---|
| H1 critic and checks | Opus | d25-hard-a | ab414a1a6a6b544f2 |
| H2 core and base | Opus | d25-hard-b | ad80b7cf16c0e7586 |
| G1 Arsenal hockey | Fable | d25-arsenal | acc7d893f9d72602c |
| G2 Robot soccer | Opus | d25-robot | af697fa864f7c5d7b |
| G4 Half-court | Opus | d25-court | ac92056dfc84f5243 |
Standups: cron 301bc462, hourly at :41 (session-only). Queue: G5, G11, G19 when a lane finishes and room.sh says room.
