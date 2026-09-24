class_name Controller
extends RefCounted
## Base class for anything that drives a fighter.

var fighter = null  # Fighter (untyped to avoid a cyclic reference)


func poll(_dt: float) -> InputFrame:
	return InputFrame.new()


func is_human() -> bool:
	return false
