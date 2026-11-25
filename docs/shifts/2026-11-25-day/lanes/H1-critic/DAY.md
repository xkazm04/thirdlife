# H1, editor hardening: what changed on 25 Nov, and the real job that asked for it

Each line: what a person now meets, and the finding that caused it. Every fix landed with a test that failed before it.

**Judging a game (the critic, the bots)**
- The critic sees the game with its HUD on, as a person does. *Hockey critic stills had the HUD off.*
- A game is judged by its own design, not hockey's. A basketball pack is no longer told it lacks hockey's board checks, and a kart game is not asked how a body stumbles. *G4 got 70 hockey contact rows; G5 got 49 body rows.*
- A team ball game's spacing bound scales to its court and players: G4's 15 x 11 m court counts a pile-up within 1.5 m, not hockey's 5 m. *G4.*
- When the critic asks about play and the revise round changes only the look, the person is told "the look changed, the play did not", and which bots did not change. *G2 spent about 70 min of rounds on a score panel and a crowd; its matches stayed frame for frame the same.*
- A person's note on a kept card is a requirement the critic checks. "Keep the camera steady" is measured: the runner now reports how far the camera turns and travels each second. *G4's camera slid after the player, 5.3 m a second.*
- A passed phase is not judged again. *G5's greybox critic re-ran after two phase passes.*
- The critic never asks the drawing to hide what the simulation does. *G1's rival was drawn 2.3 m from where the core had him.*

**What a person is told**
- What changed after a change: the person's words first, then the builder's words of what they will see, then the files. Anything not made is said apart. *G2 got a list of file names; half of its two-ask change was silently not made.*
- A toy's worth is said only when the matches show it: unclear at 20 seeds, measured to 80, else "not clear yet". *G1: at 20 seeds three toys of four pointed the wrong way.*
- A named figure is compared with what was asked: "about three minutes" means minutes of play, said as over or short. *G1's three-minute clock was called "falls short" at 3.9 minutes with goal pauses.*
- Questions are words with chips, asked once; removals are named with their reason. *G1's harbour asked the same thing three times, as JSON.*
- A failed build says why in words and offers Resume beside Try again. *G5 failed on its last check after 2 hours, and Try again would have thrown the work away.*

**The person's word counts**
- A yes to "may I change these files" widens that package's scope; a bare "yes, go ahead" grants the files the question named. *G4's fix was dropped twice as out of scope.*
- A card choice ("Never Held") or an answer ("drop the possession target") lifts a plan bound, and cards now name the bounds they lift. *G5 lost three rounds to a bound the person had dropped.*
- The game's text (title, tagline, names, commentary) goes to the skin's owner. *G1's "line under the title" went to a package that could not edit it.*
- Play words go to the package that owns the cartridge; a change with two asks is routed in parts. *G1, G2.*

**Not losing work**
- Resume sends the failing test's owner back, using a fix already waiting in its workspace, and each Resume grants one more try. A person's waiting change goes first and carries that fix with it. *G5's fix sat unmerged while the same check failed twice.*
- A first promotion is checked in a window; a refused press, a race on a lock file, and a clock-starved round no longer cost a round or fail a test. *H2's pause test failed 2 of 3; G-lanes lost rounds to a busy machine.*
- The ledger counts every part of a builder's session and keeps its note. *G5 core r8 was logged at 365 tokens out of 30,705.*

**Still open:** dusk needs thirdjam's night lights exported (tomorrow). A timer game shows no clock (G1).
