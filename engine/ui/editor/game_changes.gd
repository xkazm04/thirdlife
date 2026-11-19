extends RefCounted

## Pair submissions with logged requests in order. Each logged outcome belongs to one submission,
## including when the player returns to an option they picked in an earlier change.
static func outcomes(changes: Array, logged: Array) -> PackedStringArray:
	var result := PackedStringArray()
	result.resize(changes.size())
	var start := 0
	for i in changes.size():
		var c: Dictionary = changes[i]
		var decision := {"key": c.key, "to": c.to}
		for j in range(start, logged.size()):
			var event: Dictionary = logged[j]
			if event.has("decision"):
				if event.decision != decision:
					continue
			elif event.text != str(c.text).replace("\"", "'"):
				continue
			result[i] = event.outcome
			start = j + 1
			break
	return result
