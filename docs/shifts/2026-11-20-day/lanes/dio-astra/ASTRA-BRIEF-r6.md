# dio-astra, round 6 (18:20 to 19:00, short and final): brief for Astra

Round 5 is verified by the operator: fast PASS; selftests style. 12/12, rig. 14/14, moves. 14/14 (moves.replay
re-run with a private cache after a corrupt file in the machine-wide picture cache), flight. 13/13, wings 2/2,
character. 1/1; classic seeded with a fresh cache per side 22/22 at 0/255, figures and parkour 0/255; my 07 lower half
59/134/182 against the board's 59/133/181. The full world/packs gate is running now.

## The one item
COMMON.md rule 5 and the Director (16:35): the diorama must not cost more than 2x classic GPU. Your gallery tour: 2.981
ms against 1.336 ms classic = **2.23x**. My own windowed tour on the same tree: 3.004 ms against 1.334 ms classic
(different run, same story). Bring the delivered default under 2x on the same 16-camera tour, measured against classic
in the same session, without giving back what the board needs (your call how: cheaper soft shadows, shadow distance,
the horizon pass, anything in your scope). Keep every switch key working.

**Stop by 19:00** with gates green (fast; `--tier full --only world,packs,kit.selftest`; `style.`, `rig.`) and classic
exact, append "Round 6" to `ASTRA-NOTES.md`. Keep the stills you publish under about 300 KB each (the Director had
recompressed them; round 5 doubled their size). Do not touch `shotset.sh`; one windowed capture at a time. Read-only git;
do not commit. Never kill a process you did not start.
