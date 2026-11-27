
# Zones and rules: a build that does something (a door, a coin, a course)
Zones in the region now: {{zones}}
Rules on them now: {{rules}}
Room: {{room}}
- {"op":"zone","id":n,"box":[[x0,y0,z0],[x1,y1,z1]],"look":"<look>","name":"<1-24 chars>"} marks a box of cells, low
  corner first, at most 64 a side. The walker is in it while his feet cell is: the cell above the block he stands on,
  or the ground's y. look: "pad" a glowing disc on the box's floor, "flag" a pole on its floor centre, "coin" a token
  at its centre, "none" unseen. name is optional.
- {"op":"rule","id":n,"when":{trigger},"if":[conditions],"do":[1-8 effects]}: when the trigger fires and every
  condition holds ("if" left out when none), the effects run in order.
  Triggers: {"on":"enter"|"leave"|"use","zone":z} (use: E pressed inside), {"on":"every","frames":60-36000} (60 = 1 s),
  {"on":"count","counter":"c","at":1-999}, {"on":"start"}, {"on":"finish"} (a run starts / is finished).
  Conditions: {"running":true|false}, {"counter":"c","min":0-999,"max":0-999} (min and/or max).
  Effects: {"do":"start","run":"<name>"} (clock and counters 0, coins back), {"do":"checkpoint","zone":z},
  {"do":"finish"}, {"do":"respawn"}, {"do":"add","counter":"c","by":-99..99}, {"do":"take","zone":z} (a coin goes),
  {"do":"open"|"close"|"toggle","zone":z} (its blocks vanish and stop colliding while open),
  {"do":"launch","up_cm":0-3000,"fwd_cm":0-3000}, {"do":"teleport","zone":z}, {"do":"say","text":"<1-60>","frames":30-600}.
- {"op":"unzone",...} / {"op":"unrule",...} remove one, written whole as listed; unrule a zone's rules first.
Ids are the answer's own (1, 2, 3...; the Home renumbers). A rule names a zone made before it or a listed one.
Counters: a-z and _, at most 8 in the Home.
Space (checked before the player accepts): a pad or flag zone's bottom row is the feet cell over a floor (a block
placed or there, or the ground); a coin is 1 x 2 x 1 cells on such a feet cell (it floats 1 m up), never in a block;
every block rests on the ground or another block. A run's way must be walkable: stairs, slabs, half-block steps; a
jump climbs 1 block only over at most 1 empty cell, and crosses at most 2 empty cells only when flat or going down.
Worked examples (flat ground at y 10):
A door that opens and closes on E: two dark wood cells in a wall, a zone round them to stand in.
{"op":"fill","from":[100,10,52],"to":[100,11,52],"shape":1,"mat":4,"rot":0}
{"op":"zone","id":1,"box":[[100,10,52],[100,11,52]],"look":"none","name":"Door"}
{"op":"zone","id":2,"box":[[99,10,51],[101,11,53]],"look":"none"}
{"op":"rule","id":1,"when":{"on":"use","zone":2},"do":[{"do":"toggle","zone":1}]}
A short run: start pad, a stair onto a ledge (top 11, a checkpoint) with a coin, a 1-cell gap, a pillar with the flag.
{"op":"fill","from":[100,10,49],"to":[101,10,49],"shape":3,"mat":1,"rot":0}
{"op":"fill","from":[100,10,46],"to":[101,10,48],"shape":1,"mat":1,"rot":0}
{"op":"fill","from":[100,10,43],"to":[101,11,44],"shape":1,"mat":2,"rot":0}
{"op":"zone","id":1,"box":[[100,10,50],[101,10,51]],"look":"pad","name":"Start"}
{"op":"zone","id":2,"box":[[101,11,46],[101,12,46]],"look":"coin"}
{"op":"zone","id":3,"box":[[100,11,46],[101,11,48]],"look":"none"}
{"op":"zone","id":4,"box":[[100,12,43],[101,12,44]],"look":"flag","name":"Finish"}
{"op":"rule","id":1,"when":{"on":"enter","zone":1},"do":[{"do":"start","run":"Hop"}]}
{"op":"rule","id":2,"when":{"on":"enter","zone":2},"if":[{"running":true}],"do":[{"do":"take","zone":2},{"do":"add","counter":"coins","by":1}]}
{"op":"rule","id":3,"when":{"on":"enter","zone":3},"if":[{"running":true}],"do":[{"do":"checkpoint","zone":3}]}
{"op":"rule","id":4,"when":{"on":"enter","zone":4},"if":[{"running":true}],"do":[{"do":"finish"}]}
{"op":"zone","id":5,"box":[[100,10,45],[101,10,45]],"look":"none","name":"Fall"}
{"op":"rule","id":5,"when":{"on":"enter","zone":5},"if":[{"running":true}],"do":[{"do":"respawn"}]}
A fall: under EACH jump gap a zone of look none on the floor the walker lands on if he misses (the ground, or a lower
landing), just the gap's cells: enter, if running, respawn (at the last checkpoint). Never one zone round the whole
course (it is refused next to a lot, and it catches the start and the stairs). Name the run in the note.
