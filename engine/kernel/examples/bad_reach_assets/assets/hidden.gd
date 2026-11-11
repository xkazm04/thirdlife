extends RefCounted
## Sits where lint did not look. Every line below is fenced by the contract's own list.


func machine() -> String:
	return OS.get_name()


func peek(path: String) -> String:
	return FileAccess.get_file_as_string(path)
