extends RefCounted
## The `.tlitem` container: a plain zip in one canonical form, written and read here.
##
## Why not ZIPPacker: it stamps every entry with the wall clock and offers no way to set the time, so two packings of
## the same folder differ (measured, see JOURNAL.md). Why not ZIPReader for unpacking: it gives no entry sizes before
## it inflates, so a hostile archive could not be refused before memory is spent. A standard zip tool (and ZIPReader)
## still opens what this writes.
##
## Canonical form, and the only form `read` accepts:
##   entries sorted by path (byte order), each exactly once; paths are relative, ASCII, `/`-separated;
##   method 0 (stored) or 8 (deflate; chosen only when it is smaller); flags 0; time 00:00:00, date 1980-01-01;
##   no extra field, no comment, no data descriptor, no encryption, no zip64, one disk;
##   local entries packed back to back from offset 0, then the central directory, then the end record, then nothing.
## No global class names are used here.

const SIG_LOCAL: int = 0x04034b50
const SIG_CENTRAL: int = 0x02014b50
const SIG_END: int = 0x06054b50
const DOS_TIME: int = 0
const DOS_DATE: int = 0x0021          # 1980-01-01
const MAX_PATH: int = 180
const MAX_DEPTH: int = 8
const RESERVED: Array = ["con", "prn", "aux", "nul", "com1", "com2", "com3", "com4", "com5", "com6", "com7", "com8",
	"com9", "lpt1", "lpt2", "lpt3", "lpt4", "lpt5", "lpt6", "lpt7", "lpt8", "lpt9"]


## "" when `rel` is a safe relative path inside an item; otherwise the reason.
static func path_problem(rel: String) -> String:
	if rel.is_empty():
		return "empty path"
	if rel.length() > MAX_PATH:
		return "path longer than %d characters" % MAX_PATH
	if rel.begins_with("/") or rel.begins_with("\\"):
		return "absolute path"
	if rel.contains("\\"):
		return "backslash in path"
	if rel.contains(":"):
		return "drive or scheme in path (':')"
	var parts: PackedStringArray = rel.split("/")
	if parts.size() > MAX_DEPTH:
		return "deeper than %d levels" % MAX_DEPTH
	for seg: String in parts:
		if seg.is_empty():
			return "empty path segment"
		if seg == "." or seg == "..":
			return "'%s' segment (no path may leave the item)" % seg
		for i: int in seg.length():
			var c: int = seg.unicode_at(i)
			var ok: bool = (c >= 48 and c <= 57) or (c >= 65 and c <= 90) or (c >= 97 and c <= 122) or c == 95 or c == 45 or c == 46
			if not ok:
				return "character not allowed in a path (allowed: letters, digits, '_', '-', '.')"
		if seg.ends_with("."):
			return "segment ends with a dot"
		if RESERVED.has(seg.get_slice(".", 0).to_lower()):
			return "reserved device name '%s'" % seg
	return ""


## CRC-32 and raw deflate stream of `data`, both from the engine's zlib (the gzip container carries them).
static func crc_and_deflate(data: PackedByteArray) -> Dictionary:
	if data.is_empty():
		return {"ok": true, "crc": 0, "raw": PackedByteArray()}
	var g: PackedByteArray = data.compress(FileAccess.COMPRESSION_GZIP)
	var n: int = g.size()
	if n < 18 or g[0] != 0x1f or g[1] != 0x8b or g[2] != 8 or g[3] != 0:
		return {"ok": false, "crc": 0, "raw": PackedByteArray()}
	if g.decode_u32(n - 4) != data.size():
		return {"ok": false, "crc": 0, "raw": PackedByteArray()}
	return {"ok": true, "crc": g.decode_u32(n - 8), "raw": g.slice(10, n - 8)}


## Builds the archive. `files` is {path: PackedByteArray}. Returns {ok, bytes, error}.
static func build(files: Dictionary) -> Dictionary:
	var paths: Array = files.keys()
	paths.sort()
	var out: StreamPeerBuffer = StreamPeerBuffer.new()
	var central: StreamPeerBuffer = StreamPeerBuffer.new()
	for p: String in paths:
		var why: String = path_problem(p)
		if not why.is_empty():
			return {"ok": false, "bytes": PackedByteArray(), "error": "%s: %s" % [p, why]}
		var data: PackedByteArray = files[p]
		var cd: Dictionary = crc_and_deflate(data)
		if not cd["ok"]:
			return {"ok": false, "bytes": PackedByteArray(), "error": "%s: could not be compressed" % p}
		var method: int = 0
		var body: PackedByteArray = data
		if (cd["raw"] as PackedByteArray).size() < data.size():
			method = 8
			body = cd["raw"]
		var name: PackedByteArray = p.to_ascii_buffer()
		var offset: int = out.get_size()
		out.put_u32(SIG_LOCAL)
		out.put_u16(20)
		out.put_u16(0)
		out.put_u16(method)
		out.put_u16(DOS_TIME)
		out.put_u16(DOS_DATE)
		out.put_u32(int(cd["crc"]))
		out.put_u32(body.size())
		out.put_u32(data.size())
		out.put_u16(name.size())
		out.put_u16(0)
		out.put_data(name)
		if not body.is_empty():
			out.put_data(body)
		central.put_u32(SIG_CENTRAL)
		central.put_u16(20)
		central.put_u16(20)
		central.put_u16(0)
		central.put_u16(method)
		central.put_u16(DOS_TIME)
		central.put_u16(DOS_DATE)
		central.put_u32(int(cd["crc"]))
		central.put_u32(body.size())
		central.put_u32(data.size())
		central.put_u16(name.size())
		central.put_u16(0)
		central.put_u16(0)
		central.put_u16(0)
		central.put_u16(0)
		central.put_u32(0)
		central.put_u32(offset)
		central.put_data(name)
	var cd_offset: int = out.get_size()
	var cd_bytes: PackedByteArray = central.data_array
	if not cd_bytes.is_empty():
		out.put_data(cd_bytes)
	out.put_u32(SIG_END)
	out.put_u16(0)
	out.put_u16(0)
	out.put_u16(paths.size())
	out.put_u16(paths.size())
	out.put_u32(cd_bytes.size())
	out.put_u32(cd_offset)
	out.put_u16(0)
	return {"ok": true, "bytes": out.data_array, "error": ""}


## Reads an archive as hostile input. Nothing is inflated before every size and path has been checked.
## `limits`: {max_archive, max_files, max_file, max_total}. Returns {ok, files: {path: bytes}, errors: [String]}.
static func read(buf: PackedByteArray, limits: Dictionary) -> Dictionary:
	var errors: Array = []
	var files: Dictionary = {}
	var n: int = buf.size()
	if n > int(limits["max_archive"]):
		return _refuse("the archive has %d bytes; the limit is %d" % [n, int(limits["max_archive"])])
	if n < 22:
		return _refuse("too short to be a zip archive")
	var eo: int = n - 22
	if buf.decode_u32(eo) != SIG_END:
		return _refuse("no end record in the last 22 bytes (an archive comment or trailing data is not accepted)")
	if buf.decode_u16(eo + 4) != 0 or buf.decode_u16(eo + 6) != 0:
		return _refuse("multi-disk archives are not accepted")
	var count: int = buf.decode_u16(eo + 10)
	if buf.decode_u16(eo + 8) != count:
		return _refuse("entry counts in the end record disagree")
	if count > int(limits["max_files"]):
		return _refuse("%d entries; the limit is %d" % [count, int(limits["max_files"])])
	var cd_size: int = buf.decode_u32(eo + 12)
	var cd_off: int = buf.decode_u32(eo + 16)
	if buf.decode_u16(eo + 20) != 0:
		return _refuse("an archive comment is not accepted")
	if cd_off + cd_size != eo:
		return _refuse("the central directory does not end where the end record begins")
	# ---- pass 1: the central directory, nothing inflated
	var entries: Array = []
	var at: int = cd_off
	var prev: String = ""
	var seen: Dictionary = {}
	var total: int = 0
	var expect_local: int = 0
	for i: int in count:
		if at + 46 > eo or buf.decode_u32(at) != SIG_CENTRAL:
			return _refuse("entry %d: the central directory is damaged" % i)
		var flags: int = buf.decode_u16(at + 8)
		var method: int = buf.decode_u16(at + 10)
		var crc: int = buf.decode_u32(at + 16)
		var csize: int = buf.decode_u32(at + 20)
		var usize: int = buf.decode_u32(at + 24)
		var nlen: int = buf.decode_u16(at + 28)
		var extra: int = buf.decode_u16(at + 30)
		var comment: int = buf.decode_u16(at + 32)
		var local: int = buf.decode_u32(at + 42)
		if at + 46 + nlen > eo:
			return _refuse("entry %d: the name runs past the central directory" % i)
		var name_bytes: PackedByteArray = buf.slice(at + 46, at + 46 + nlen)
		var printable: bool = true
		for b: int in name_bytes:
			if b < 32 or b > 126:
				printable = false
		if not printable:
			return _refuse("entry %d: the name has bytes outside printable ASCII" % i)
		var name: String = name_bytes.get_string_from_ascii()
		var why: String = path_problem(name)
		if not why.is_empty():
			return _refuse("entry '%s': %s" % [name, why])
		if seen.has(name.to_lower()):
			return _refuse("entry '%s': the same path twice (names differing only in case count as the same)" % name)
		seen[name.to_lower()] = true
		if i > 0 and not (prev < name):
			return _refuse("entry '%s': entries are not sorted by path" % name)
		prev = name
		if flags != 0:
			return _refuse("entry '%s': flags %d (encryption, data descriptors and other options are not accepted)" % [name, flags])
		if method != 0 and method != 8:
			return _refuse("entry '%s': compression method %d (only stored and deflate are accepted)" % [name, method])
		if extra != 0 or comment != 0:
			return _refuse("entry '%s': extra fields and comments are not accepted" % name)
		if buf.decode_u16(at + 12) != DOS_TIME or buf.decode_u16(at + 14) != DOS_DATE:
			return _refuse("entry '%s': the timestamp is not the fixed one (the archive was not made by `item.sh pack`)" % name)
		if buf.decode_u16(at + 34) != 0 or buf.decode_u32(at + 38) != 0:
			return _refuse("entry '%s': disk number or file attributes are set (links and special files are not accepted)" % name)
		if usize > int(limits["max_file"]):
			return _refuse("entry '%s': %d bytes; one file may have at most %d" % [name, usize, int(limits["max_file"])])
		total += usize
		if total > int(limits["max_total"]):
			return _refuse("the contents add up to more than %d bytes" % int(limits["max_total"]))
		if method == 0 and csize != usize:
			return _refuse("entry '%s': a stored entry whose two sizes differ" % name)
		if usize == 0 and (csize != 0 or method != 0 or crc != 0):
			return _refuse("entry '%s': an empty file must be stored with CRC 0" % name)
		if local != expect_local:
			return _refuse("entry '%s': its data is not where the previous entry ends (gaps and overlaps are not accepted)" % name)
		if local + 30 + nlen + csize > cd_off:
			return _refuse("entry '%s': its data runs into the central directory" % name)
		if buf.decode_u32(local) != SIG_LOCAL or buf.decode_u16(local + 6) != 0 or buf.decode_u16(local + 8) != method \
				or buf.decode_u16(local + 10) != DOS_TIME or buf.decode_u16(local + 12) != DOS_DATE \
				or buf.decode_u32(local + 14) != crc or buf.decode_u32(local + 18) != csize \
				or buf.decode_u32(local + 22) != usize or buf.decode_u16(local + 26) != nlen or buf.decode_u16(local + 28) != 0 \
				or buf.slice(local + 30, local + 30 + nlen) != name_bytes:
			return _refuse("entry '%s': the local header disagrees with the central directory" % name)
		expect_local = local + 30 + nlen + csize
		entries.append({"name": name, "method": method, "crc": crc, "csize": csize, "usize": usize, "data": local + 30 + nlen})
		at += 46 + nlen
	if at != eo:
		return _refuse("the central directory holds more than its %d entries" % count)
	if expect_local != cd_off:
		return _refuse("there is data between the last entry and the central directory")
	# ---- pass 2: inflate, each entry bounded by its declared size, each checked against its CRC
	for e: Dictionary in entries:
		var data: PackedByteArray = PackedByteArray()
		var usize2: int = int(e["usize"])
		if usize2 > 0:
			var body: PackedByteArray = buf.slice(int(e["data"]), int(e["data"]) + int(e["csize"]))
			if int(e["method"]) == 0:
				data = body
			else:
				var gz: StreamPeerBuffer = StreamPeerBuffer.new()
				gz.put_data(PackedByteArray([0x1f, 0x8b, 8, 0, 0, 0, 0, 0, 0, 0x0a]))
				gz.put_data(body)
				gz.put_u32(int(e["crc"]))
				gz.put_u32(usize2)
				data = gz.data_array.decompress(usize2, FileAccess.COMPRESSION_GZIP)
			if data.size() != usize2:
				errors.append("entry '%s': does not inflate to its declared %d bytes" % [str(e["name"]), usize2])
				continue
			var cd: Dictionary = crc_and_deflate(data)
			if not cd["ok"] or int(cd["crc"]) != int(e["crc"]):
				errors.append("entry '%s': CRC mismatch" % str(e["name"]))
				continue
		files[str(e["name"])] = data
	if not errors.is_empty():
		return {"ok": false, "files": {}, "errors": errors}
	return {"ok": true, "files": files, "errors": []}


static func _refuse(message: String) -> Dictionary:
	return {"ok": false, "files": {}, "errors": [message]}
