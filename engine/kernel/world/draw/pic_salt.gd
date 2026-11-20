extends RefCounted
## Day of 20 Nov 2026 (lane cel-fable, after dio-fable's finding): the picture cache is keyed by a pack's content and
## the picture rules, not by the style. But a picture stores vertex colours, and a kit terrain bakes palette paints
## into them (TLKitTerrain `_c`): a picture filled under one style showed that style's land under another style, on
## this machine's shared cache as well.
##
## `salt()` is what the cache key carries for the loaded style: nothing when the baked paints are today's
## (style.json), so today's key stays byte-equal; else the paints themselves. Two styles with the same paints share
## their pictures, as before. A style that asks for geometry of its own in the landscape (`detail.road_rails`) is
## told apart by that key too, so no picture made beside it is ever served to a style without it.

## The palette keys TLKitTerrain bakes into a terrain's vertex colours (engine/kits/tl_kit_terrain.gd).
const BAKED: PackedStringArray = ["grass", "grass_dry", "grass_dark", "dirt", "sand", "rock", "rock_dark", "rock_warm", "cliff", "pine", "leaf"]

static var _classic: String = ""
static var _salts: Dictionary = {}      # style path -> salt
static var _lock: Mutex = Mutex.new()


static func salt() -> String:
	TLStyle.ensure()
	var path: String = TLStyle.style_path
	_lock.lock()
	if not _salts.has(path):
		if _classic.is_empty():
			var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(TLStyle.DEFAULT_PATH))
			_classic = paints(d if d is Dictionary else {})
		var now: String = paints(TLStyle.data)
		var salt_now: String = "" if now == _classic else "|paints:" + now
		# ... and a style's own landscape geometry (the row of rails along the road, terrain/road_rails.gd)
		var rails: float = float((TLStyle.data.get("detail", {}) as Dictionary).get("road_rails", 0.0))
		_salts[path] = salt_now + ("|rails:%s" % snappedf(rails, 0.01) if rails > 0.0 else "")
	var out: String = _salts[path]
	_lock.unlock()
	return out


## The baked paints of a style dictionary as one string ("#rrggbb,#rrggbb,..."; "-" for a key the style lacks).
static func paints(d: Dictionary) -> String:
	var pal: Dictionary = d.get("palette", {})
	var out: PackedStringArray = PackedStringArray()
	for k: String in BAKED:
		out.append(String(pal.get(k, "-")).to_lower())
	return ",".join(out)
