class_name InputFrame
extends RefCounted
## One tick of fighter input, produced by a Controller (human or AI).

const ACTIONS := ["light", "heavy", "jump", "guard", "dash", "q", "e", "r", "f", "throw"]

## Movement, -1..1 on both axes (y < 0 is up).
var move := Vector2.ZERO
## Normalised aim direction (mouse, right stick or towards the opponent).
var aim := Vector2.RIGHT
var held := {}
var pressed := {}
var released := {}
## Non-zero when a dash was requested this tick (shift + direction or double tap).
var dash_dir := Vector2.ZERO
## Shift without a direction: evasive back-step.
var dodge := false


func h(action: String) -> bool:
	return held.get(action, false)


func p(action: String) -> bool:
	return pressed.get(action, false)


func r(action: String) -> bool:
	return released.get(action, false)


func any_pressed() -> bool:
	for a in pressed:
		if pressed[a]:
			return true
	return dash_dir != Vector2.ZERO or dodge
