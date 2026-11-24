# E1 base (round 12): hokej as the base a user's game starts from

- **data/skin.json** (tl.rink.skin/1, unknown keys are errors; scripts/hud/skin.gd) holds the game's words and banks:
  - the title, the tagline, HOME's lines;
  - the team names (the commentator's blue / orange become them);
  - the level row;
  - the commentary bank (built-in, off, or a data file) and the bark bank (a data file or off).
  Team colours have one source, the cartridge's colour_hex: figures, HUD, bark plates and stand-ins.
- **engine/templates/rink_game** is hokej's generic part, byte for byte (selftest rink.template: 39 files), with a builder's
  README and three tests (first match, match hand, skin). The parity proofs stay in hokej.
- **Proof:** a copy of the template with the Pond cartridge (60 x 30, re-coloured green / purple) and a POND skin
  (Ducks / Geese) plays whole matches headless and shows its names and colours in a window (r12_pond_copy.jpg).
- **hokej is the same game:** the core hash ab881a00fb9af8ef, the first match 6f45bf07503f05b8, idle 3b762bc2, all unchanged.
- **Barn:** on a 60 x 30 rink only the ice, boards and markings resize. The benches and boxes stand on the floor behind
  the boards (r12_pond_60x30_in_barn.jpg). The barn should stay; its rink furniture should follow the boards (K6).
- **HUD PNGs:** they live in each pack's assets/hud/, copied with the template.
