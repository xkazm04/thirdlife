# The village workbench

The four concept plates use a red workshop flag, pale paper, dark ink and a honey-coloured choice. I carried those into the editor. On the map, a fenced track and a little floodlit court help the player recognise their neighbours. The proposed game has survey pegs, a measured ring and its gate. Terracotta hatching shows the part of that ring shared with a neighbour or the road. [Hockey workbench](after-astra-raw/s2-hockey-720.jpg) · [Overlapping lots](after-astra-raw/s3-overlap-720.jpg)

## File by file

| File under `engine/ui/editor/` | What changed and why |
| --- | --- |
| `look.gd` | Mixed paper, ink, wood, meadow and warning colours from the house style. Set Archivo's width and weight axes for body and display type. Gave the choices a shallow lower edge and strengthened the text on disabled buttons. |
| `presswork.gd` | A style box paints the flag, ruled paper edges, recipe emblems and the stack of cards on the empty interview sheet. These details live behind the existing controls. |
| `workshop_art.gd` | Drew small illustrations for the courts, ramps, circuit, crane, cabin, trees and workshop stationery. Each uses the palette supplied by the editor. Cached versions at different sizes keep the miniature drawings legible when zooming. |
| `workbench.gd` | Applied the ink-coloured header and review bar, put the recipe emblem beside its explanation, and gave questions and proposals distinct type weights. The player's sentence and the request retain their prominent positions. |
| `village_map.gd` | Drew fences at the plot radii, wheel tracks along the road and landmarks inside the plots. The rink carries the selected number of jerseys per side. Labels make room for the gate and verdict. On the game sheet, each package has a boarded bay with its own state sign. |
| `map_landscape.gd` | Anchored meadow colour, banks, grass, rock and tree groups to village coordinates so they stay in place between views. The foreground keeps the active lot clear for the placement drawing. |
| `scale_strip.gd` | Drew a side elevation on graph paper beside the existing 2 m walker. Rink boards, stand bracing, light masts and course ramps give the estimated length and height something recognisable to measure. |
| `game_sheet.gd` | Set the current state into the header and ruled the decision rows. Adjusted the question and answer column widths to give longer decisions room at 720p. Bay colours connect the package list with its signs on the map. |
| `fonts/Archivo.ttf` and `fonts/OFL.txt` | Bundled the Archivo variable font and its SIL Open Font License 1.1. [Font and licence source](https://github.com/google/fonts/tree/main/ofl/archivo) |

## Verification

Captured and inspected all ten static screens with `bash .tl/look-shots.sh docs/shifts/2026-11-19-night/lanes/editor/look-pass/after`. The game list matches its before capture pixel for pixel. [Empty workbench](after-astra-raw/s1-empty-720.jpg) · [Rink close-up](after-astra-raw/s4-closeup-720.jpg) · [Course at 1080p](after-astra-raw/s7-course-1080.jpg) · [Game sheet at 720p](after-astra-raw/s8-game-sheet-720.jpg) · [Game sheet at 1080p](after-astra-raw/s9-game-sheet-1080.jpg)

In a separate read-only layout check, the interview choices, decision rows, change controls and approval controls fit their viewport or existing scroll area at both resolutions. The hockey change preview showed the existing 45 m ring inside the proposed 54 m ring. The UI selftest reported **123 passed, 0 failed**.
