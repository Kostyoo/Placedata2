extends SceneTree
## Loads every script to surface parse errors: godot --headless -s tools/check_scripts.gd

func _init() -> void:
	var bad := 0
	for path in _collect("res://scripts"):
		var s = load(path)
		if s == null or not (s is Script) or not s.can_instantiate():
			print("FAILED: ", path)
			bad += 1
	print("checked, failures: ", bad)
	quit(1 if bad > 0 else 0)


func _collect(dir: String) -> Array:
	var out := []
	var d := DirAccess.open(dir)
	for f in d.get_files():
		if f.ends_with(".gd"):
			out.append(dir + "/" + f)
	for sub in d.get_directories():
		out += _collect(dir + "/" + sub)
	return out
