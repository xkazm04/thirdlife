# The editor path to a hokej-class game (night of 24-25 Nov 2026)

**The owner, 24 Nov ~23:20 (verbatim):** "alhough the hockey feel like thirdjam, we will need to use rest of this night to
achieve game like this can be built by user from the editor, our engine and prompt process should be capable and user
should have path even through more iterations to get there"

## Where the editor stands (scout, 23:45; full report in standups/2345-scout.md)
The Foreman builds a fresh hand-written pack (4 Sonnet builders x 15 min) copying the OLD hockey; nothing in it knows the
rink core, hokej, cartridges or SNAPSHOT.md. A generated pack could already call `ctx.cores.open` with its own cartridge
(the kernel opens `data/<name>.cartridge.json`, the thirdlife variant when a rules file lies beside it), but no builder
is pointed there, the cartridge schema is only inside the C++ (JamSchemaData.inl), hokej's words / colours / banks are
hockey-specific, iterations can only reopen one existing package, Create's done screen has no change box and no job
list, and a finished game stays in site/.

## The recipe (DIRECTIONS.md direction 10, made real)
A user's game = **a cartridge on a core + a skin**, started from a working base, never a fresh hand-written sim:
1. **Base**: a rink-game template (hokej made reusable): all game-specific text, colour and banks in data.
2. **Cartridge**: thirdjam's `tj.cartridge/1` (rink, teams, speeds, contact, rules, hooks, variants, zones, obstacles,
   pickups, abilities, look, camera) + optional `tl.rink.rules/1` sidecar; a readable schema, a validator in the
   Foreman, a catalog in player words, thirdjam's 12 modes and its sentence-to-cartridge cache as worked examples.
3. **Measured check**: the lab plays the generated cartridge headless (bots, the planning hand) and reports what a
   person will meet (goals a match, carry length, dead verbs) before the person's gate.
4. **Iterations**: every round is a playable build in minutes, because a change is mostly a cartridge / skin diff;
   the person says it in words in Create ("faster", "bigger rink", "rocket skates"), the Foreman turns it into a diff,
   measured, and he plays again; a job can be reopened later; a finished game can be added to the menu.

## Lanes (max 5 agents; models by task)
| Lane | Agent | Tree / branch | Owns |
|---|---|---|---|
| E1 base | K3's agent (Opus; knows hokej) | hk-shell | `engine/packs/hokej/**` made skinnable; `engine/templates/rink_game/**` (new: the base a job starts from) |
| E2 cartridge | K1's agent (Opus; knows the core) | hk-core | readable schema + limits from JamSchemaData.inl, `engine/cores/rink/CARTRIDGE.md` (catalog), `foreman/src/cartridge*.ts` (validator, diff), the lab check `rink.sh check-cartridge` |
| E3 route | new Opus agent | hk-editor (new) | the Foreman's core route: `foreman/src/{templates,designer,designctx,reference,house,quality,tofu,cards}.ts`, `foreman/prompts/**`, `engine/cards/**`, `devx/lib/cards/**` |
| E4 iterate | new Opus agent | hk-create (new) | iteration and the person's path: `engine/ui/create/**`, `engine/ui/foreman_door.gd`, `foreman/src/{foreman,cli,cli_args,cli_design,phases,promoter}.ts` change / reopen / add-to-menu paths, `engine/boot/dungeons.json` writer |
| K8 balance | K8's agent (Fable) | hk-balance | as before |

Proof lane E5 (after E1-E4 land): real Foreman jobs from Create on three prompts and their iterations, filmed, judged.

Landing: on `hokej` (hk-int), Director-verified; the owner's word lands hokej on main.
