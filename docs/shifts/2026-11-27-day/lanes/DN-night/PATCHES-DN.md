# PATCHES-DN: changes lane DN needs in files that are not its own (27 Nov 2026)

## 1. `engine/kernel/world/build/PIECES.md` line 11 (the file table): stale since piece_draw.gd changed

Now:

    | `piece_draw.gd` | MultiMeshes per prototype per 16 m section; light and breakable parts as nodes (cap 48); bodies |

Wanted:

    | `piece_draw.gd` | MultiMeshes per prototype per 16 m section (lit parts too); breakable parts as nodes (cap 48); the lit parts' kit lights as sockets of `home/day_lamps.gd` (the 48 nearest the camera burn when the Home's clock says the lamps are on); bodies |

Why: lane DN draws a house, street lamp and light mast instanced like every other piece; their lights are sockets that
`home/day_lamps.gd` lights by time of day and by distance to the camera (BUILD.md "Keys": N, H).

## 2. (APPLIED in round 2 by lane DN, approved by the Director 12:50) stars in the night sky: `engine/style/shaders/sky_cel.gdshader`

What landed differs from the sketch below: stars are drawn under the glow, the disc and the clouds; a second uniform `moon` draws the disc as a moon. See STYLE.md "Time of day".

Not needed for this lane's acceptance; the night sky is the cel sky's own colours today. If the look lane wants stars,
one uniform (`stars`, 0 = none, the default, so every look and pin stays byte-identical) and, at the end of `sky()`
before `COLOR = c;`:

    uniform float stars = 0.0;   // lane DN: 0..1 how many stars (the day section's night sets it)
    ...
    if (stars > 0.0 && h > 0.05) {
        vec2 sp = vec2(atan(d.z, d.x), asin(h)) * 180.0;           // about one cell per third of a degree
        vec2 si = floor(sp);
        float r = fract(sin(dot(si, vec2(127.1, 311.7))) * 43758.5453);
        vec2 so = fract(sp) - 0.5 - (vec2(fract(r * 13.7), fract(r * 7.3)) - 0.5) * 0.6;
        float star = step(1.0 - 0.012 * stars, r) * (1.0 - smoothstep(0.06, 0.12, length(so)));
        c = mix(c, vec3(0.92, 0.95, 1.0), star * smoothstep(0.05, 0.25, h));
    }

and `"stars"` added to `day/style_day.gd` KEYS["sky"] with `"stars": 1.0` in style_crisp.json `day.night.sky`.
