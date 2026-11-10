# Sharing: what a player can keep, move and give away

Status: strategy and a draft standard, written 2026-11-10 by the Director for the owner's item (d) of the night plan.
Nothing here is built yet. The parts planned for the first build are marked **[first build]**.

Owner's rulings this rests on:
- Sharing comes in two steps: first the player's own saved data through Steam Cloud, later a community store.
- Two tiers (2026-11-10): data-only items install freely; items with scripts are shareable with other players only once
  they run in an isolated process behind a brokered API. Until then scripted items travel only in their owner's own
  cloud save.

## 1. The unit: an item

Everything a player can be proud of is an **item**: one folder with one card, `item.json`.

| Kind | Contents | Tier |
|---|---|---|
| `game` | a pack: `pack.json`, scripts, data, tests | code |
| `venue` | a layout file and its data, no scripts | data |
| `look` | a style file (palette, sun, ink, grade) | data |
| `tuning` | a set of values for the declared parameters of one named game | data |
| `kit` | new kit parts (today these are scripts that build meshes) | code |
| `world` | the world file: which items stand where | data |

**The tier is computed, never declared.** The packer reads the folder: any script, shader or scene makes the item
`code`. The installer computes it again and refuses an item whose card disagrees. A tier that only the card states is
a claim, not a fact.

Why a separate card and not more fields in `pack.json`: `pack.json` is what the engine needs to run a pack and its
unknown keys are errors; the card is what a person or a store needs, and it must also describe items that are not
packs.

## 2. The card: `item.json`, schema `tl.item/1` **[first build]**

```json
{
  "schema": "tl.item/1",
  "uid": "01JCA7M2Q8ZK4T9V3X5B6N7P8R",
  "kind": "game",
  "tier": "code",
  "title": "Marble run: three marbles",
  "summary": "Three marbles of different materials roll down a zig-zag ramp onto ice.",
  "description": "",
  "tags": ["physics", "race", "no-input"],
  "version": "0.1.0",
  "created": "2026-11-10T20:10:00Z",
  "updated": "2026-11-10T20:10:00Z",
  "author": { "handle": "player", "name": "" },
  "licence": "all-rights-reserved",
  "engine": { "kernelApi": "0.1", "kit": "0.1", "style": "0.1" },
  "capabilities": ["ball", "camera", "kit", "physics", "rules", "ui"],
  "footprint": { "size_m": [40, 30], "height_m": 12 },
  "requires": [],
  "provenance": {
    "built_by": "foreman",
    "job": "marble-run-three-marbles-20261110-2",
    "sentence": "A marble run: three marbles of different materials roll down a zig-zag wooden ramp onto an ice sheet, and the one that slides furthest wins.",
    "models": ["sonnet"],
    "human_code": false,
    "parent": null
  },
  "verify": {
    "report": "tl.verify/1",
    "verbs": { "lint": true, "smoke": true, "invariants": true, "bot": true },
    "bot_state_hash": "cc031fae",
    "bypasses": 1,
    "script_lines": 385
  },
  "content": { "hash": "sha256:...", "files": 9, "bytes": 31244 },
  "preview": { "thumb": "preview/thumb.jpg", "shots": [] }
}
```

Rules:
- `uid` is made once, when the item is first created, and never changes. It is random (26 characters), so two players
  cannot collide. A pack's `id` stays its local, readable name.
- `capabilities` is the item's declared grant: sorted, no duplicates, copied from `pack.json`. An update that adds a
  capability is a grant change and must be shown to the player before it installs.
- `provenance.parent` is `{uid, version, hash}` of the item this one was changed from. A chain of parents is how a
  remix keeps its credit.
- `provenance.sentence` is the player's own words. It is what lets someone else rebuild or vary the item with their
  own model.
- `verify` is evidence from the machine that built the item. The receiving machine runs the checks again and trusts
  only its own result.
- `content.hash` is taken over the sorted list of `(path, bytes, sha256)` of every file except `item.json` itself, not
  over the archive. Packing the same folder twice gives the same identity.
- `author` carries a handle and an optional display name. No e-mail address, no machine path, no account id.
- Absent values: optional text fields are empty strings, optional lists are empty lists, `parent` is `null`. A key is
  never left out.
- Not in the card: ratings, download counts, moderation labels, "safe" marks. Those are statements by a store about an
  item and belong to the store.
- `signature` is reserved for the store step and does not exist before it.

## 3. The package: `.tlitem` **[first build]**

One file per item: a zip with `item.json` at its root and the item's folder beside it. Entries are sorted by path,
carry a fixed timestamp and no extra fields, so the archive is reproducible. Godot's own `ZIPPacker` and `ZIPReader`
are enough; no outside tool is needed.

Limits, enforced at pack time and again at install: the pack limits that already exist (600 lines a script, 6,000 a
pack, 2 MiB of data), a thumbnail under 1 MB, an archive under 8 MB.

## 4. Step one: the player's own cloud save

Steam Auto-Cloud copies files under a configured root, per user and per game, within a byte quota and a file-count
limit that the developer sets. It moves whole files and knows nothing about their contents. That shapes the save:

```
<user data>/ThirdLife/
  save/                      synced
    profile.json             handle, settings, rev
    world.json               tl.world/1: plots, the item standing on each, player position, rev, device
    library/<uid>-<version>.tlitem     one file per item version, never rewritten
  local/                     not synced
    jobs/                    build logs, transcripts, captures
    cache/                   unpacked items, shader cache, engine snapshots
```

- **Few files, never rewritten.** An item version is one immutable file, so two machines can never disagree about it.
  Only `world.json` and `profile.json` change.
- **`world.json` is written whole to a temporary file and renamed**, and carries a revision counter and a device name,
  so a conflict between two machines is visible and the game can offer "keep this machine's world" or "take the cloud's".
- **Build output stays local.** A job directory is megabytes of logs and frames; the item it produced is tens of
  kilobytes.
- Rough size: a pack is at most 6,000 lines and 2 MiB of data; packed, tens to hundreds of kilobytes. A hundred games
  fit in well under 100 MB.
- A scripted item in the player's own save runs as it does today: it is the player's own code, built on their machine
  by their model. The fence is a guardrail against accidents there, not a security boundary.

## 5. Step two: the community store

- **Transport:** Steam Workshop fits the card: an item there has a title, a description, tags, a preview image under
  1 MB and a block of developer metadata of 5,000 bytes, enough for the card's summary fields. `kind`, `tier` and
  `kernelApi` become tags so the store can filter.
- **Data items** (venue, look, tuning, world) install without ceremony. They are still read as hostile input: checked
  against their schema and the limits before anything is built from them.
- **Code items** are not listed for other players until an isolation boundary exists. Today the fence is a text check
  that only the `lint` verb runs; `play` does not lint; reflection and several engine classes are not covered; and the
  `assets/` folder is never inspected, so unchecked code is reachable from a checked script. A pack loaded into the
  game's own process runs with everything the player's account can do.
- **What the boundary would be** (not designed, options only): the pack's simulation runs in a separate, restricted
  operating-system process and exchanges only state and input records with the game, which draws it. This is the same
  seam a multiplayer host needs (one process owns a game's simulation, others show it) and the same seam that lets a
  distant game run at a lower rate. Whether Godot can host this at acceptable cost is unproven.
- **Until then, a third route for games:** share the *recipe* (the sentence, the plan, the data items, the tuning) as a
  data item, and let the receiver's own model rebuild the scripts. The result is not identical, and the receiver pays
  for the build.
- **Updates:** an update whose `capabilities` grew, or whose tier changed from data to code, stops and asks.

## 6. What multiplayer would need from this

A shared world is a `world.json` plus the items it names, each identified by `uid`, `version` and `content.hash`: two
machines can check that they hold the same bytes before they start. Scripted items on a visitor's machine are exactly
the "code from another player" case of section 5, so playing a friend's scripted game needs either the isolation
boundary or a host that runs the game and sends state.

## 7. Open, for the owner (none blocks the first build)

1. The default licence of a shared item: all rights reserved, or a Creative Commons licence that allows remixing.
2. Whether a player's sentence (`provenance.sentence`) is shared by default or only when they choose.
3. Whether the recipe route of section 5 is worth offering before isolation exists.

## Sources and what is unverified

- Steam Auto-Cloud roots, per-user-per-game quota and file-count limit: Steamworks documentation, "Steam Cloud"
  (https://partner.steamgames.com/doc/features/cloud). The actual quota numbers are set per app in the Steamworks
  admin panel and were not found in the documentation.
- Workshop item fields, the 1 MB preview limit and the 5,000-byte developer metadata: Steamworks documentation,
  "ISteamUGC" (https://partner.steamgames.com/doc/api/ISteamUGC). The maximum size of an item's content was not found.
- The isolation rule for installed third-party code: the registry subject `untrusted-extension-host`.
- Unverified: that Godot's `ZIPPacker` can produce byte-reproducible archives; the cost of an isolated pack process.
