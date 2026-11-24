# E3 route: standup

00:15 | state: working | did: read the plan, the scout map, METHOD, JOB/CARDS, SNAPSHOT/GAMEMODE, API 24, MODES; template rink_sport + card.rink_core; ref/ carries ref/cores/rink/ and ref/base/<base>/ | next: cartridge-first plan, base package | gates: -
00:45 | state: working | did: plan check for a core (one base package, the root, not counted, scopes may lie inside it, cartridge in phase 1, card enforced); the Foreman executes kind "base" itself; cartridge gate (V0) before any verb; measured check at every look beside hokej's | next: fake end to end | gates: foreman typecheck clean
01:20 | state: done | did: fake end to end `foreman new "3 against 3 hockey on a small pond rink"` -> plan (base + cartridge + skin) -> base copied, an unknown cartridge key refused and fixed, core check ok beside hokej, person gate, promoted; designer.ts held at its 600-line ratchet (coreplan.ts); fixture base as JSON (no .gd in the tree) | next: E1 / E2 landing (3 tests skip by name until then) | gates: npm test 340: 330 pass, 0 fail, 10 skipped (baseline 325/318/7); tl check --tier fast PASS 5/5 (arch 12/12, assets 4/4, cards 3/3, devx.test 229/229, foreman.typecheck)

landable E3
