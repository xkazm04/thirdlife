# R3: The other builders and the AI-first creators

Lane R3, 27 Nov 2026. Subject: the field around Minecraft and Roblox. (A) builders with a higher-level "smart" grammar or a strong coherent look; (B) AI and LLM creation in games up to late 2026, and how players received it. Roblox Cube is another lane's and is skipped. Every claim has a URL; claims I could not confirm are marked [unverified]. Figures a company reported about itself are marked "self-reported".

---

## 1. Why people build there

**The smart builders sell big, but people play them in short sessions.**
- Tiny Glade sold 616,000 copies on Steam in under a month, with 97% positive reviews and 1.37M wishlists. Its **median playtime is 1 h 04 min**, and DAU ran at about 30x CCU, against 8-10x for stickier games. People open it, make one lovely thing and leave. (https://newsletter.gamediscover.co/p/how-tiny-glade-built-its-way-to-600k)
- Townscaper sold 380,000 copies against Stålberg's own guess of "4,000". He expected about 40 minutes of play per person. (https://mcvuk.com/business-news/when-we-made-townscaper ; https://www.gamedeveloper.com/game-platforms/how-townscaper-works-a-story-four-games-in-the-making)
- Critics split on "toy vs game". The PC version scored 86 and the Switch version 63. Low scores ask for "objectives, goals, prizes", and one reviewer called it "basically a lego set with graphics". (https://techraptor.net/gaming/reviews/townscaper-review ; https://legacy.prod.metacritic.com/game/pc/townscaper/critic-reviews)
- The loop that sold both games is **showing off outside the game**: viral WIP clips, trailers, and player recreations such as Helm's Deep. (https://newsletter.gamediscover.co/p/how-tiny-glade-built-its-way-to-600k)

**Building tied to a need keeps people for hundreds of hours.**
- In Valheim, furniture sets "comfort", which sets how long the Rested buff lasts. A good base keeps you rested, safe from raids, and gives you a launch hub. (https://techraptor.net/gaming/guides/valheim-comfort-guide ; https://xgamingserver.com/blog/valheim-base-building-guide/)
- Valheim passed 10M copies (https://www.nme.com/news/valheim-surpasses-10million-copies-sold-and-500000-player-peak-3211930).
- Enshrouded passed 5M players and reached 1.0 in October 2026 (https://www.kitguru.net/gaming/joao-silva/enshrouded-1-0-release-window-set-for-fall-2026-as-game-reaches-over-5-million-players/).
- Rock Paper Shotgun called Enshrouded's building "the best building system in the survival genre" (quoted on https://store.steampowered.com/app/1203620/Enshrouded/).

**Life sims: the house is the stage for the people in it.**
- The Sims 4 Gallery took 11.5M uploads and 209M downloads in 2022 alone (https://gamingbolt.com/the-sims-4-players-hit-1-4-billion-hours-played-436-5-million-sims-created).
- One report says only about a third of total Sims 4 hours are in "simulation" mode [unverified split] (https://en.shiftdelete.net/eas-striking-analysis-on-the-sims-4-players/).
- Paralives (Early Access 25 May 2026) leads with build mode: curved walls, any-angle walls, split levels and a colour wheel for everything. Coverage calls build mode its strongest selling point. (https://www.paralives.com/development ; https://arynews.tv/paralives-build-mode-explained-why-early-access-players-say-its-a-game-changer-for-life-sim-builders)

**On UGC platforms, building is the means and the played game is the product.**
- Fortnite creator islands took 47% of player hours in May 2026. Payouts have passed $1B since UEFN launched. (https://www.tubefilter.com/2026/06/17/epic-games-unreal-editor-for-fortnite-creator-payouts/)
- About 70,000 Fortnite creators make about 488,000 maps. 0.08% of creators earned over $1M; about 90% earned under $1K. (https://naavik.co/deep-dives/the-state-of-ugc-games-2026/)
- The top genres are combat and tycoon formats: Zone Wars, box fights, deathrun, tycoons. Fortnite's "Steal the Brainrot" passed 1M CCU in December 2025, driven by TikTok clips. (https://www.fortnite.com/news/what-s-trending-in-creative---august ; https://naavik.co/deep-dives/the-state-of-ugc-games-2026/)
- Rec Room built its text-prompt Maker AI for "the roughly 90% of players who don't build" (https://www.ibtimes.co.uk/rec-room-shuts-down-ai-costs-overwhelm-revenue-1789414).

**Sharing.** The strong forms are a code or string that recreates a build:
- Townscaper's "Save to Clipboard" string and URL fragment (https://github.com/mokojm/townsclipper).
- Animal Crossing Dream Addresses, which have no search, so discovery happens on fan lists (https://nintendowire.com/animal-crossing-new-horizons-dream-address-database/).
- Factorio blueprint strings on factorioprints (https://primagames.com/tips/how-to-import-and-use-blueprints-in-factorio-2-0).
- Planet Coaster 2's cross-platform Frontier Workshop (https://planetcoaster.com/help-centre).
- Tiny Glade has no sharing at all. Its sharing is screenshots and video, and that alone carried it to 600k+. (https://newsletter.gamediscover.co/p/how-tiny-glade-built-its-way-to-600k)

## 2. The building primitive

### The magical family: the player draws intent, the system writes the detail

**Townscaper**
- The grid is an irregular, relaxed quad grid made by splitting hexes.
- Tiles are corner pieces, placed with marching-cubes logic. Wave Function Collapse picks valid modules, and a separate decoration pass follows.
- Stålberg: "I want the user to feel like they're in control of the large shapes... the larger shapes to feel very predictable, but the smaller shapes are allowed to vary quite a bit", and "it is actually allowed to fail silently."
- Limits he names:
  - WFC is poor at "long, thin things";
  - the rules are "quite limited";
  - a reskin needs "somewhere in the region of 500 tiles";
  - big structures lag between placing and decorating.
- (https://www.gamedeveloper.com/game-platforms/how-townscaper-works-a-story-four-games-in-the-making)

**Tiny Glade**
- The pillars are "a lot from little effort", "no wrong answers" and "it's alive" (ivy, birds, sheep react to what you build).
- You draw a wall and the game lays each brick. Some tools went through 6-7 prototypes and 5 external playtests.
- (https://newsletter.gamediscover.co/p/how-tiny-glade-built-its-way-to-600k)
- Players pushed the grammar past its edges: stacked lamps as wooden walls, stairs aligned into crenellations. The devs turned these hacks into features (bridges, raised buildings, half-timbering) instead of banning them. (https://80.lv/articles/exclusive-tiny-glade-developers-discuss-bevy-proceduralism-publishers-cozy-games ; https://www.gamesradar.com/games/city-builder/steam-next-fests-biggest-city-builder-adds-a-new-feature-after-outright-mad-scientist-like-players-kept-trying-to-brute-force-it-themselves)
- Even this game was gated by plain tool requests: stairs arrived July 2025, terrain height doubled, clutter became movable, and the 32-light cap was removed. (https://www.pcgamer.com/games/sim/tiny-glade-has-released-its-biggest-update-yet-which-includes-a-stair-tool-new-paths-and-floor-textures-and-a-secret-feature-involving-sheep ; https://80.lv/articles/tiny-glade-s-update-with-movable-clutter-multiple-lights-is-here)

**Why a novice's build looks good here:**
1. The player only states coarse intent: footprint, height, roof type.
2. Every edge case is authored: corners, junctions, roof meetings.
3. There is no failure state.
4. There is one art direction.

The cost is expressive range. You cannot make a thing the tileset did not foresee.

### The semi-smart family: walls and rooms, with roofs as the pain point

**The Sims 4**
- Walls are drawn and enclosed walls become rooms. There are room and foundation presets.
- Roofs are the classic pain: there is no auto-roof, "not even preset L and U shaped roofs", though some players say auto roofs "screw up the whole build". (https://forums.ea.com/discussions/the-sims-4-feedback-en/can-we-have-a-auto-roof-in-the-sims-4/11892689 ; https://forums.ea.com/discussions/the-sims-4-general-discussion-en/downsides-of-the-sims-4-building/1245920/replies/1245924)
- The novice failure is the big plain square room (https://www.thegamer.com/sims-4-level-up-building-skills-tips/).
- Serious builders escape the grid with the `bb.moveobjects` cheat. It is in every builder tutorial, and it can leave objects unusable by Sims. (https://simscommunity.info/2023/02/19/sims-4-tutorial-using-moveobjects-cheat/ ; https://ggrecon.com/guides/sims4-how-to-move-objects)

### The free-placement family: pieces with snap points

**Valheim**
- Pieces snap together. Structural support is colour-coded from blue to red. (https://xgamingserver.com/blog/valheim-base-building-guide/)
- Escape tools are mods:
  - PlanBuild (plan, copy, share blueprints);
  - Build Camera;
  - Infinity Hammer.
- They share a `.blueprint` format. (https://www.github.com/sirskunkalot/PlanBuild ; https://github.com/AzumattDev/BuildCameraCustomHammersEdition ; https://thunderstore.io/c/valheim/p/MikaMarik/ValheimTomrer/)

**LEGO Fortnite**
- At launch, building was called its weakest part: no way to level the ground, uneven floors, and a cap on bricks that made players quit.
- The fix made builds clear flora and fit slopes. (https://primagames.com/news/lego-fortnite-players-agree-that-building-is-frustrating-and-the-weakest-part-of-the-game ; https://www.gfinityesports.com/article/lego-fortnites-build-limits-are-making-players-quit ; https://techcrunch.com/2024/01/23/lego-fortnites-first-big-update-squashes-bugs-and-adds-a-launch-pad/)
- Its blueprint "Builds" were praised as a tutorial but felt restrictive (https://www.siliconera.com/building-in-lego-fortnite-can-feel-restrictive/).
- A brick-by-brick Brick Editor (50 bricks) reached UEFN creators in June 2025 (https://www.fortnite.com/news/introducing-the-lego-brick-editor-and-lego-bloom-tycoon-template-for-fortnite-creators).

**Planet Coaster 2**
- Scenery is placed piece by piece. Reviewers call scenery and paths "unnecessarily convoluted" and the console path tool "awful". (https://www.techradar.com/gaming/planet-coaster-2-review ; https://www.tomsguide.com/gaming/planet-coaster-2-review)
- Blueprints are the escape, but "your parks will look same-y until you start creating stuff from scratch" (https://gamewatcher.com/reviews/Planet-coaster-2-review/13434).
- PC Gamer asked for "a simplified building system for slapping together scenery for items you use a lot" (https://pcgamer.com/games/sim/planet-coaster-2-review).
- After launch the workshop cap went from 1 GB to 4 GB, about 3,000 to 12,000 blueprints (https://sportskeeda.com/esports/news-planet-coaster-2-hotfix-1-patch-notes).

### Voxel plus terrain: Enshrouded and Teardown

**Enshrouded**
- Custom voxel tech lets you dig and build "practically anything, anywhere" (https://www.pcgamer.com/games/survival-crafting/enshrouded-1-0-review/).
- There is no structural integrity, so blocks float (https://allthings.how/enshrouded-1-0-base-building-tips-that-save-materials-and-time/).
- You can build freeform or from pre-made templates for floors and walls. A preview saw the game ring a newly punched hole with proper structure. (https://gamingtrend.com/previews/enshrouded-preview-voxels-pickaxes-and-wingsuits/)
- Roofs and corner pieces are still chosen by hand from hotbars (https://gamespot.com/articles/enshrouded-base-building-guide/1100-6520568/).

**Teardown** is voxel destruction. Custom levels are modelled in MagicaVoxel (https://teardowngame.com/faq.html).

### Terraform-and-decorate: Animal Crossing New Horizons

- Island Designer paints paths, cliffs and water tile by tile.
- Complaints: "mind-numbing", no undo, auto-save with no backup, volatile diagonal aiming. Fans want the faster Happy Home Paradise editor "for everything". (https://www.destructoid.com/is-anyone-else-frustrated-by-animal-crossing-new-horizons-terraforming-system/ ; https://gamesradar.com/animal-crossing-new-horizon-fans-want-the-happy-home-paradise-editor-for-everything)
- 50.6M copies sold (https://www.nintendo.co.jp/ir/en/finance/software/switch.html?pubDate=20261002).

### Blueprinting: the universal tedium escape

- Factorio's blueprint library is shared across saves, with strings on factorioprints (https://wiki.factorio.com/Blueprint_library).
- Satisfactory 1.0 added Blueprint Designer Mk.2 and Mk.3 after players called Mk.1 too small (https://satisfactory.wiki.gg/wiki/Blueprint_Designer_Mk.1).
- Cities: Skylines has a workshop of 400,000+ items, growing by over 1,000 a day. Paradox left Steam Workshop for its own Paradox Mods for CS2, and the CS2 asset editor stayed in beta and was "pushed to the background". (https://pcgamer.com/cities-skylines-2-wont-use-steam-workshop-for-mod-sharing ; https://www.pcgamesn.com/cities-skylines-2/asset-editor-update ; https://www.pcgamer.com/uk/the-best-cities-skylines-mods-maps-and-assets)
- **At scale, every one of these games converges on copy, stamp and share. Nobody lays brick 50,000 by hand twice.**

## 3. The behaviour layer

| Game | Layer | Who uses it | What it yields |
|---|---|---|---|
| Fortnite | Devices, then Verse in UEFN (2023) | ~70k creators | Combat and tycoon formats dominate the charts (https://naavik.co/deep-dives/the-state-of-ugc-games-2026/) |
| Garry's Mod | Lua plus Workshop | Community devs | The base game has "no objectives"; the hits are mods such as Trouble in Terrorist Town and Prop Hunt (https://wikipedia.com/wiki/S%26Box) |
| Teardown | Lua, level editor, MagicaVoxel import, Workshop | Curated by the devs | A physics gun, a Quake railgun, mod contests twice a year (https://www.pcgamer.com/teardown-has-steam-workshop-now-and-that-means-theres-a-physics-gun) |
| Dreams | Logic gadgets inside a full creation suite | Small core | See below |
| Sims, Valheim, Enshrouded, Tiny Glade, Townscaper, ACNH | None for players | n/a | Life comes from the game's own systems |

**Fortnite.** Devices remain the primary building blocks for mechanics (https://www.fortnite.com/news/fortnite-ecosystem-2024-year-in-review-celebrating-creators-and-looking-ahead). Verse is "hard for creators who aren't engineers" per a forum thread; that is opinion, not data (https://forums.unrealengine.com/t/verse-the-elephant-in-the-room/2722619).

**Garry's Mod** sold 25.56M copies (https://kitguru.net/desktop-pc/mustafa-mahmoud/garrys-mod-reaches-new-milestone-of-25-million-copies-sold).

**Dreams is the cautionary tale.**
- The tools were generous: 150,000+ dreams, about 5,000 a week by 2022.
- The most-played beta creation had only 6,800 plays. (https://gamingbolt.com/dreams-has-over-150000-dreams-5000-new-creations-published-each-week ; https://www.pushsquare.com/news/2019/03/dreams_ps4_beta_participants_made_more_than_35000_creations)
- Live support ended 1 Sep 2023: "not able to define a sustainable path" (https://www.pushsquare.com/news/2023/07/dreams-live-service-ending-as-media-molecule-couldnt-find-a-sustainable-path).
- Critics: tiny audience, hard to market, no creator monetisation, an audience that never left the creator bubble (https://pushsquare.com/features/reaction-dreams-losing-support-is-a-sad-end-to-ps4s-most-unbelievable-project).

**Where the layer is absent, the builds live through the game's own systems:**
- Tiny Glade's sheep and ivy;
- Valheim's comfort and raids;
- Sims who use the house;
- ACNH villagers who walk your paths.

This is a real alternative to scripting. The world gives the build a reason, and the player does not have to program one.

## 4. The look

**One authored style flatters every novice build.**
- Townscaper gets coherence from one tileset and a palette. Colour is "key to allow users to express themselves" (https://mcvuk.com/business-news/when-we-made-townscaper).
- Tiny Glade aims at "perfectly imperfect" handmade detail and tactile material sounds. It is tuned for low-end PCs and inspired by Limbo and Inside. (https://newsletter.gamediscover.co/p/how-tiny-glade-built-its-way-to-600k)

**The price of one style:**
- Townscaper towns all read as Townscaper.
- A new style costs about 500 tiles (https://www.gamedeveloper.com/game-platforms/how-townscaper-works-a-story-four-games-in-the-making).
- Parks look "same-y" when built from stock blueprints (https://gamewatcher.com/reviews/Planet-coaster-2-review/13434).

**Where the look breaks:**
- UGC platforms with open import, where AI imagery made it worse.
- Kotaku found 120+ AI-generated thumbnails of caricatured people on Fortnite islands.
- PC Invasion counted 16 of 20 Trending islands using AI images or copyrighted content. (https://kotaku.com/fortnite-racist-offensive-ai-images-art-zonewars-epic-1851209249 ; https://pcinvasion.com/?p=412045)
- The Cities: Skylines asset workshop gives realism but mixes styles [unverified as a press claim; widely observed by players].

**What players do to escape a fixed look.** In the closed-style games (Townscaper, Tiny Glade, ACNH) players do not fight the look. They fight the limits of the tools (stairs, height, undo). In the open games the community imports assets: CS workshop, Sims custom content, Teardown via MagicaVoxel.

## 5. AI: every notable creation feature to late 2026, and how it landed

### World models (pixels, not editable worlds)

**Google Genie 3 and Project Genie** (US, AI Ultra, $249 per month, from 29 Jan 2026)
- Sessions are capped at 60 s, at 720p and 20-24 fps.
- The world "may not adhere closely to prompts... or follow real-world physics". Control is laggy and inconsistent. (https://blog.google/innovation-and-ai/models-and-research/google-deepmind/project-genie/ ; https://www.roadtovr.com/?p=126396 ; https://ground.news/article/numerous-video-game-company-share-prices-dropped-following-googles-project-genie-ai-rollout)
- The launch knocked about 24% off Unity, 13% off Roblox and 8% off Take-Two in a day (https://www.bloomberg.com/news/articles/2026-01-30/unity-video-game-stocks-fall-as-google-s-ai-tool-genie-sparks-fears).
- Analysts' rebuttal:
  - a "one-minute-long walking simulator generator" (mBank);
  - games need deterministic gameplay that is "structural, not cosmetic" (Raymond James);
  - Unity's CEO called it "complementary, not duplicative".
  - (https://www.sherwood.news/business/video-game-experts-say-googles-project-genie-isnt-an-industry-killer/)
- TechCrunch's hands-on found the worlds "sterile". Google itself called it a prototype people would not return to daily. (https://techcrunch.com/2026/01/29/i-built-marshmallow-castles-in-googles-new-ai-world-generator-project-genie)

**Genie 4** (27 Oct 2026, trusted testers)
- Adds audio and mid-simulation edits (weather, objects).
- Detail still drifts over longer sessions. Sessions run "a few minutes". (https://techcrunch.com/2026/10/27/googles-genie-4-world-model-adds-audio-more-realistic-worlds-and-real-time-steering/)

**Microsoft Muse / WHAMM Quake II demo** (Apr 2025): reaction was "pretty universally negative": unplayable, hallucinating, a slap at devs amid layoffs. Carmack and Sweeney defended it. (https://www.videogameschronicle.com/news/microsofts-quake-2-ai-experiment-sparks-negative-reactions/ ; https://www.techspot.com/news/107483-john-carmack-tim-sweeney-defend-microsoft-whamm-ai.html)

**Decart / Etched Oasis** (Oct 2024, AI Minecraft)
- No memory of the world: it "loses track of things you've done".
- Inventory and scenery mutate. (https://techcrunch.com/2024/10/31/decarts-ai-simulates-a-real-time-playable-version-of-minecraft ; https://www.techspot.com/news/105436-oasis-interactive-ai-experience-turns-minecraft-nightmarish-hallucination.html)

**Dynamics Lab Mirage 2** (Aug 2025)
- A "UGC game engine" world model. Worlds are edited by chat.
- About 200 ms latency, with weak control precision and stability. (https://the-decoder.com/mirage-2-allows-users-to-turn-sketches-and-photos-into-interactive-game-worlds/)

**World Labs Marble** (public Nov 2025; API Jan 2026; 1.1 in Apr 2026)
- Exports Gaussian splats or meshes with colliders. It is used as backdrops imported into Unity or Unreal.
- Game devs have "mixed feelings". (https://www.worldlabs.ai/blog/marble-world-model ; https://www.deeplearning.ai/the-batch/world-labs-makes-its-marble-generative-world-model-public-adds-chisel-editing-tool ; https://techcrunch.com/?p=3066962)

**Verdict on world models.** They are impressive and have no persistence, ownership or rules. None writes an editable, persistent world that a player can come back to.

### LLMs that build in a structured world

**MC-Bench** (2025)
- Models write code that builds a prompt in Minecraft. Humans vote blind.
- Claude 3.7 Sonnet led in early 2025. It is "technically a programming benchmark". (https://techcrunch.com/2025/03/20/a-high-schooler-built-a-website-that-lets-you-challenge-ai-models-to-a-minecraft-build-off)

**Research results**
- VoyagerVision built basic structures with 36% true success. Most failures came on complex shapes. (https://arxiv.org/abs/2507.00079v1)
- MineAnyBuild (NeurIPS 2025, 4,000 tasks): agents show "severe limitations in spatial planning" (https://neurips.cc/virtual/2025/poster/121620).
- MineCEraft (EMNLP 2026 Findings): 723 expert instructions, verifiable checks. I could not read its results [unverified] (https://arxiv.org/abs/2608.28884).
- **Talking-to-Build** (ICMI 2025, 30 participants, GPT-4-turbo into Minecraft commands)
  - The LLM interface "significantly improves player performance, engagement, and overall game experience" over typed commands.
  - The authors stress "predictability, transparency, and user agency". (https://arxiv.org/abs/2507.20300)

### AI-native creation platforms

**Astrocade**
- 10M MAU and 220M sessions a month by 7 Oct 2026. 100,000+ playable games, from hundreds of thousands of creators.
- $56M raised (Sequoia) in May 2026.
- CEO: players care "as long as it is fun". Self-reported. (https://gamesbeat.com/astrocade-hits-10m-monthly-players-for-its-ai-assisted-ugc-casual-games-platform/ ; https://fortune.com/2026/05/05/astrocade-raises-56-million-series-b-sequoia-video-games-platform-ali-amir-sadeghian/)

**Rosebud**
- "Hundreds of thousands" of games in 2025, self-reported (https://lab.rosebud.ai/blog/new-years-eve-reset-how-2025-changed-game-creation----and-why-2026-belongs-to-creators).
- About $40K MRR [unverified] (https://nilo.io/articles/rosebud-ai-reviews-reddit).

**Bitmagic**
- Text-to-game in Steam Early Access in 2024. An LLM assembles scenes from a pre-defined asset library.
- I found no 2025-2026 traction. (https://gamesbeat.com/bitmagic-launches-text-to-game-creation-platform-in-steam-early-access/ ; https://store.steampowered.com/app/2178290)

**The Sandbox Studio**
- An AI engine for text-to-multiplayer games. Beta from June 2026; the October public launch slipped.
- Works with Cursor, Codex and Claude Code. (https://cryptobriefing.com/sandbox-ai-game-engine-studio-launch/ ; https://egamers.io/?p=128549)

**Inworld** moved from consumer NPCs to runtime and voice infrastructure (Aug 2025). Few named shipped games. (https://gamesbeat.com/inworld-runtime-is-1st-ai-runtime-for-consumer-apps/ ; https://www.eesel.ai/de/blog/inworld-ai)

**Rec Room Maker AI** is the strongest single cautionary data point.
- Text-prompt creation launched in March 2025, aimed at the roughly 90% who don't build.
- Rec Room's co-founder said it "just frustrated our more impactful creators" (https://roadtovr.com/rec-room-layoff-half-staff-august-2025/).
- Sacra estimated one Maker AI user cost more per month than a $7.99 Plus subscriber paid. It was pulled from the bundle.
- Rec Room shut down on 1 June 2026: "Our costs always ended up overwhelming the revenue we brought in." (https://www.ibtimes.co.uk/rec-room-shuts-down-ai-costs-overwhelm-revenue-1789414)

### AI in shipped games and big platforms

**inZOI** (1M sold in its first week, Mar 2025)
- A 3D Printer turns a photo into furniture in about 20 s, on-device, and needs 8 GB VRAM. Smart Zoi runs NPC inner thoughts.
- Reception split: one Reddit user's "jaw was on the floor"; others objected to any gen-AI. (https://www.gamedeveloper.com/press-release/krafton-hits-1-million-sales-of-inzoi-in-first-week-of-early-access-launch ; https://gamesradar.com/games/the-sims/hyper-realistic-sims-4-competitor-inzoi-has-a-3d-print-feature-that-lets-you-turn-real-life-photos-into-in-game-items-and-it-works-surprisingly-well ; https://thegameswiki.com/inzoi/wiki/ai-features)
- Later Steam reviews went "mixed", with a recurring "looks pretty, lacking depth" (https://www.pcgamer.com/games/life-sim/would-be-sims-competitor-inzois-publisher-says-steam-concurrents-arent-as-important-as-sales-which-is-only-technically-correct).

**Fortnite**
- AI Darth Vader (May 2025): players got him to swear and use slurs within hours, and SAG-AFTRA filed an unfair labor practice charge (https://gameinformer.com/2025/05/19/sag-aftra-files-unfair-labor-practice-complaint-against-epic-games-due-to-ai-darth-vader).
- UEFN "Conversations" AI NPCs (Gemini 3.1 Flash-Lite plus ElevenLabs) shipped as Experimental on 16 Apr 2026, with a watermark (https://www.fortnite.com/news/bring-npcs-to-life-with-ai-powered-conversations).
- The Epic Developer Assistant for Verse has been in beta since 2025 (https://www.4gamer.net/games/144/G014484/20250604002).
- UE 5.8 shipped an MCP server in June 2026, and UE6 will merge with UEFN. Sweeney admits the risk of "AI slop" but calls the tools an "accelerant for real creators". (https://wccftech.com/epic-games-unreal-engine-6-claude-gemini-developer-control/ ; https://wccftech.com/tim-sweeney-unreal-engine-ai-tools-accelerant-real-creators/amp/)

**The Sims.**
- EA partnered with Stability AI (Oct 2025). A rumoured gen-AI Sims 4 remaster is [unverified].
- Community reaction is mostly negative ("a kick in the ribs").
- An AI build button exists only as a fan proposal. (https://simscommunity.info/2025/10/24/ea-partners-ai-company-announcement/ ; https://forums.ea.com/discussions/the-sims-4-feedback-en/ai-in-the-sims-4-%E2%80%93-a-proposal/5047913)

### What players think: evidence

**How much AI is on Steam**
- 49.9% of October 2026 Steam releases disclosed AI content, up from 1.7% in January 2024. Art is 63% of disclosures. (https://dexerto.com/gaming/almost-half-of-all-new-steam-games-use-ai-now-3423933 ; https://www.gadgetreview.com/?p=425709)
- Disclosure tracks low reach: 47% of games with under 10 reviews, 14% of games with 1,000+ (https://respawn.outlookindia.com/gaming/gaming-news/steam-ai-disclosures-near-50-in-october-2026). **AI-disclosed games are mostly the ones nobody plays** (my reading of the numbers; correlation, not cause).

**Player surveys**
- GameDiscoverCo (about 3,800 Steam users, mid-2026): 31% react negatively, 43% are fine, and 8% would refuse to buy. Many think studios hide it. (https://newsletter.gamediscover.co/p/what-do-steam-fans-really-think-about ; https://www.pcguide.com/news/pc-gamers-remain-skeptical-of-steams-ai-disclaimers-poll-shows-many-believe-game-devs-are-hiding-it/)
- Circana (US, Dec 2025): about 25% are less likely to buy or would refuse, up from about 22% in 2024 (https://respawn.outlookindia.com/gaming/gaming-news/do-gamers-care-about-genai-new-data-reveals-a-silent-majority).

**Developers.** GDC, November 2026: 55% think gen-AI is bad for the industry, 8% positive, 40% use it (https://www.gamingonlinux.com/2026/11/gdc-november-2026-survey-shows-40-percent-of-developers-using-generative-ai/).

**Enforcement and backlash**
- The Indie Game Awards pulled Clair Obscur's Game of the Year over gen-AI placeholder art that had already been patched out (https://www.pcgamer.com/games/rpg/indie-game-awards-pulls-two-awards-from-clair-obscur-over-generative-ai-use-we-have-a-hard-stance-against-gen-ai-in-videogames).
- Arc Raiders: Eurogamer gave it 2/5 over AI voices. Sales held, and Embark is re-recording lines with humans. (https://www.pcgamer.com/games/third-person-shooter/there-was-some-really-fair-criticism-arc-raiders-devs-understand-why-players-were-so-upset-about-its-ai-use-but-admit-that-it-was-too-impractical-to-record-every-voice-line/ ; https://www.pushsquare.com/news/2026/03/arc-raiders-replacing-some-of-its-controversial-ai-voices-with-better-human-ones)

**Pattern.** A loud minority punishes AI that replaces a craftsperson (art, voice). A majority tolerates AI that is invisible or fun. Nobody has measured AI as a player-side building helper at scale.

### What fails and what works, with evidence

**Fails**
1. **Cost per user.** Rec Room's Maker AI cost more than the subscription paid, and the platform shut down.
2. **Coherence and memory.** Oasis forgets the world; Genie drifts; VoyagerVision managed 36% on simple structures.
3. **Latency.** Genie is laggy; Mirage runs at about 200 ms.
4. **Low-effort floods erode discovery.** AI thumbnails crowd Fortnite's Trending, and Naavik warns of a "low-trust" Discover feed (https://naavik.co/deep-dives/the-state-of-ugc-games-2026/).
5. **"Frustrated our more impactful creators"** (Rec Room).
6. **Ownership.** In a randomized study (N=486, replicated with N=640), a model-led mode that rewrites ideas raised quality but cut diversity and perceived ownership. Human-led prompting kept both. (https://arxiv.org/abs/2510.23324)
7. **Randomness.** In Guzdial's AI level-editor studies, designers deleted about 60% of AI additions, down to about 45% with an adaptive agent. They complained it seemed "random" and filled "intentional empty space". (https://ar5iv.labs.arxiv.org/html/1901.06417)

**Works**
- A natural-language front end onto a deterministic command layer (Talking-to-Build).
- AI that adds to a human-built thing:
  - inZOI's photo-to-prop;
  - Fortnite AI NPCs inside creator-authored islands.
- AI as an inspiration source, when the human leads (Guzdial; https://arxiv.org/abs/2510.23324).

## 6. Complaints and gaps (from builders, not fighters)

- **Roofs and junctions** are hard and need manual piecework: Sims auto-roof requests, Enshrouded's hand-picked inner roof corners (https://forums.ea.com/discussions/the-sims-4-feedback-en/can-we-have-a-auto-roof-in-the-sims-4/11892689 ; https://gamespot.com/articles/enshrouded-base-building-guide/1100-6520568/).
- **Terrain that fights the build**: LEGO Fortnite's unlevelable ground, ACNH's tile-by-tile cliffs with no undo.
- **Grids and snapping too strict**, so people use cheats (`bb.moveobjects`), Paralives' free walls sell, and Valheim build-camera mods exist.
- **Scale tedium**, solved by copy and blueprint: PlanBuild, Factorio, Satisfactory Mk.2/3, Planet Coaster's workshop size cap.
- **Build caps and performance**: LEGO Fortnite's brick cap, Enshrouded dips in dense areas (https://www.technetbooks.com/2026/10/enshrouded-10-review-custom-voxel.html), Townscaper's decoration lag.
- **"Nothing to do with it"** in toy builders: Townscaper's Switch score, Tiny Glade's 1-hour median.
- **Discovery of shared builds**: ACNH has no search, the Frontier Workshop breaks, Fortnite has a cold start for new islands (https://naavik.co/deep-dives/the-state-of-ugc-games-2026/).
- **Sameness of stock assets** (Planet Coaster blueprints).
- **Gap the press names**: Naavik calls a category-defining non-combat Fortnite experience an open opportunity (https://naavik.co/deep-dives/the-state-of-ugc-games-2026/).

## 7. Openings for a game like ours, and where we lose

Our game has four parts: (a) a smart-piece grammar on a heightfield, (b) one cel look, (c) an LLM co-builder that writes the same edits as the hand tools, and (d) small playable games in the same world.

### Where we can clearly win

1. **Tiny Glade's magic plus a reason to stay.**
   - Tiny Glade proves "a lot from little effort, no wrong answers, it's alive" sells 600k+. It also proves a 1-hour median when nothing needs the build.
   - Our dungeons and unlocks earned in games are the Valheim "comfort" lever (the build pays back in play) that toy builders lack. **Make the Home matter to the games, and the games feed the Home.**
2. **AI as a co-builder, not a replacement.**
   - The evidence for the "ghost first, one undo, then editable by hand" design is strong. Talking-to-Build shows NL front ends beat raw commands. The N=486 study shows human-led AI keeps ownership and model-led AI erodes it.
   - Rec Room shows a prompt-to-game tool aimed at non-builders frustrated the real builders and lost money.
   - Our LLM writes the same small ops as the hands (heightfield, smart blocks, pieces). That is the deterministic, inspectable layer world models lack. No world model on the market persists or is editable.
3. **A grammar narrows what the LLM must get right.**
   - LLMs fail at raw spatial planning: MineAnyBuild, VoyagerVision at 36%.
   - With smart blocks that auto-corner roofs and stairs, the LLM only states Townscaper's "large shapes", and the grammar does the detail that LLMs get wrong. **The grammar is the LLM's safety net.** This is the strongest structural edge we have over Minecraft-style LLM building.
4. **One look makes AI output indistinguishable from hand output.**
   - Players punish AI that replaces art (Clair Obscur, Arc Raiders, Fortnite thumbnails).
   - Our LLM places kit parts and does not generate pixels or meshes. So there is no "AI art" in the output, and the result looks exactly like hand builds. Keep it that way, and say so to players.
5. **Stamps and items as the share unit.** Every builder at scale converges on blueprints and strings. Make a stamp a short code or link from day one: Townscaper strings, Factorio books, Dream Addresses. Ship search, which ACNH lacks.
6. **Terrain and the build are one tool.** The top builder complaints are unlevelable ground and tile-by-tile cliffs. Our grading paths, flatten and water-into-hollow can answer them. Enshrouded's dig-and-build is the bar.

### Where we lose (blunt)

- **Expressive range and the long tail.** Townscaper needs about 500 tiles per style and cannot do what the tileset did not foresee. A smart grammar always caps the ceiling below Minecraft blocks or Dreams' sculpting. Expert builders will hit our walls in hours. Tiny Glade survived only by turning player hacks into features.
- **Network effects and money.** Fortnite has 47% of its hours on creator islands, $1B+ paid out, and roughly 70k creators; Astrocade has 10M MAU. We have no multiplayer, no economy and no audience. Dreams had better tools than all of these and died for want of an audience and monetisation.
- **The behaviour layer.** Without player logic, our Home cannot become a game the way Garry's Mod modes or Fortnite tycoons do. The UGC hits are played formats, not pretty builds.
- **AI cost per user.** A per-edit Opus call is the Rec Room trap if it is free and unlimited. Budget it: quotas, small models for small edits, caching of stamps.
- **The "AI" label.** About 25-31% of players lean negative and 8% refuse outright. Steam AI disclosure correlates with obscurity. If the store page leads with "AI builds your world", the core cozy-builder audience may read it as slop.

### Traps

- Do not let the LLM fill empty space unasked. Designers deleted 45-60% of such AI additions.
- Do not lead with a prompt box for the non-builder. That is Rec Room, again.
- Do not chase world models.
- Do not ship a build cap that players hit (LEGO Fortnite).
- Do not leave undo off terrain (ACNH).

---

## Ten findings that should change our design

1. A build that nothing in the game needs gets about 1 hour: Tiny Glade's median playtime is 1 h 04 min despite 616k sales. Make Home pieces feed the dungeons and the dungeons feed the Home. (https://newsletter.gamediscover.co/p/how-tiny-glade-built-its-way-to-600k)
2. Player control belongs to the large shapes and the system writes the small ones ("predictable large shapes, varied small shapes; allowed to fail silently"). Give the LLM and the hand tools only the large-shape vocabulary. (https://www.gamedeveloper.com/game-platforms/how-townscaper-works-a-story-four-games-in-the-making)
3. LLMs are weak spatial planners (VoyagerVision 36% on basic structures; MineAnyBuild "severe limitations"), so the smart-block grammar has to absorb the geometry the LLM gets wrong. (https://arxiv.org/abs/2507.00079v1 ; https://neurips.cc/virtual/2025/poster/121620)
4. Model-led rewriting raises quality but cuts ownership and diversity, while human-led prompting keeps both (N=486, replicated with N=640). Keep the ghost-then-accept flow, and have the AI propose rather than overwrite. (https://arxiv.org/abs/2510.23324)
5. A prompt-to-create tool aimed at non-builders frustrated Rec Room's best creators, cost more per user than the subscription earned, and the platform shut down on 1 Jun 2026. Meter LLM edits and aim them at builders. (https://www.ibtimes.co.uk/rec-room-shuts-down-ai-costs-overwhelm-revenue-1789414 ; https://roadtovr.com/rec-room-layoff-half-staff-august-2025/)
6. Designers deleted about 45-60% of an AI's unasked additions and hated it filling "intentional empty space". The co-builder never adds what was not asked for. (https://ar5iv.labs.arxiv.org/html/1901.06417)
7. Players punish AI that replaces craft (Clair Obscur stripped of its award; 49.9% of Steam releases now disclose AI, mostly the least-played). Keep the LLM placing authored kit parts, never generating art, and say so on the store page. (https://www.pcgamer.com/games/rpg/indie-game-awards-pulls-two-awards-from-clair-obscur-over-generative-ai-use-we-have-a-hard-stance-against-gen-ai-in-videogames ; https://respawn.outlookindia.com/gaming/gaming-news/steam-ai-disclosures-near-50-in-october-2026)
8. Every builder converges on copy, stamp and share at scale, and the winners share a string (Townscaper clipboard, Factorio books). Make a stamp a short code or link with search from day one. (https://github.com/mokojm/townsclipper ; https://wiki.factorio.com/Blueprint_library)
9. Builders' top terrain complaints are ground that cannot be levelled and tile-by-tile cliffs with no undo. Terrain edits must be graded, undoable and fast. (https://primagames.com/news/lego-fortnite-players-agree-that-building-is-frustrating-and-the-weakest-part-of-the-game ; https://www.destructoid.com/is-anyone-else-frustrated-by-animal-crossing-new-horizons-terraforming-system/)
10. World models (Genie 3/4, Oasis, Mirage) still cannot persist or edit a world: 60 s to a few minutes, drift, forgotten edits. Our deterministic, saved edit ops are the moat, so do not chase pixel generation. (https://blog.google/innovation-and-ai/models-and-research/google-deepmind/project-genie/ ; https://techcrunch.com/2026/10/27/googles-genie-4-world-model-adds-audio-more-realistic-worlds-and-real-time-steering/ ; https://www.techspot.com/news/105436-oasis-interactive-ai-experience-turns-minecraft-nightmarish-hallucination.html)
