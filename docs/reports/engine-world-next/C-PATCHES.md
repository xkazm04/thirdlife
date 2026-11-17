# Lane C: changes needed outside lane C's files (for the Director)

## 1. `docs/generated/REPORTS.md` (generated): regenerate after merging both lanes

Already regenerated once in this worktree (`node devx/bin/tl.mjs arch --index`, 42 reports) because the new status
file `docs/reports/engine-world-next/C.md` made rule `reports-index-fresh` red. It is a generated digest, not a file
of lane C: after merging lanes C and S, run `node devx/bin/tl.mjs arch --index` once more and commit the result.

## 2. `engine/kernel/API.md` section 22 (not the header): the example error sentence names API 1.0

Lane C owns the header only (now "kernelApi 1.5"). Section 22 still quotes the refusal as
`kernelApi '2.0' cannot run on this kernel, which offers API 1.0: ...`. Proposed: replace "offers API 1.0" by
"offers API 1.5" in that sentence (the runner prints KERNEL_API, which is 1.5), or reword it as
"offers API <KERNEL_API>" so the example does not age with every minor.

## 3. `contracts/CARDS.md` (Director only): two wording questions

a) `rules_keys` row, "Checked against": now "set in the seed's `data/rules.json`". Measured: the house game hockey has
   no `data/rules.json`; it passes the `"rules"` object of `data/tuning.json` to `TLRules.create`. `tl cards check`
   now reads rules keys from both places. Proposed wording: "set in the example's data: the top level of
   `data/rules.json`, or the `"rules"` object of a `data/*.json` the pack passes to `TLRules.create`".

b) "Added 2026-11-17" paragraph: add one sentence on the reference copy: "The Foreman copies every card to
   `<job>/ref/cards/` and every house pack a card names, whole, to `<job>/ref/packs/<pack>/` (hockey: 172,464 bytes
   in 52 files); a builder brief maps the card's `engine/...` path to that copy in one line above the card text."

## 4. `contracts/JOB.md` (Director only): what "change not made" leaves in the log

The amendment says pack/ is put back before the job's state event. Implemented: pack/ is copied to
`reports/change-not-made-s<seq>/pack/`, the last promoted pack replaces pack/, and ordinary `merge` events (only when a
package's merged-file list differs from the promotion's) put the log's file lists back, all before `job_state`; the
reason ends "pack/ was put back to the last promotion <id> <version> (<dest>); the unpromoted files of the change are
kept only in reports/change-not-made-s<seq>/pack/." The construction site draws `merge` events: a put-back may show
as a merge of a package with `removed` files. Proposed sentence for JOB.md: "The put-back is logged as `merge` events
(files back, `removed` the change's new files) before the job's state event; the unpromoted pack/ is kept in
`reports/change-not-made-s<seq>/pack/`."
