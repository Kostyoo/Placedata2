class_name HumanController
extends Controller
## Reads keyboard / mouse / gamepad actions registered by Game.setup_input().
## Several action prefixes can be merged (e.g. "p1" keyboard + "pad" gamepad).

const DIRS := {"left": Vector2.LEFT, "right": Vector2.RIGHT, "up": Vector2.UP, "down": Vector2.DOWN}

var prefixes: Array = []
var use_mouse := false
var clock := 0.0
var last_tap := {"left": -9.0, "right": -9.0, "up": -9.0, "down": -9.0}
var _prev_dir := {"left": false, "right": false, "up": false, "down": false}
var _mouse_moved_t := -9.0
var _pending_dodge := -1.0
var _last_dash := -9.0
var _last_mouse := Vector2.ZERO


func _init(p_prefixes: Array, p_use_mouse: bool) -> void:
	prefixes = p_prefixes
	use_mouse = p_use_mouse


func is_human() -> bool:
	return true


func _held(a: String) -> bool:
	for p in prefixes:
		var act: String = p + "_" + a
		if InputMap.has_action(act) and Input.is_action_pressed(act):
			return true
	return false


func _just(a: String) -> bool:
	for p in prefixes:
		var act: String = p + "_" + a
		if InputMap.has_action(act) and Input.is_action_just_pressed(act):
			return true
	return false


func _just_released(a: String) -> bool:
	for p in prefixes:
		var act: String = p + "_" + a
		if InputMap.has_action(act) and Input.is_action_just_released(act):
			return true
	return false


func _strength(a: String) -> float:
	var s := 0.0
	for p in prefixes:
		var act: String = p + "_" + a
		if InputMap.has_action(act):
			s = maxf(s, Input.get_action_strength(act))
	return s


func poll(dt: float) -> InputFrame:
	clock += dt
	var f := InputFrame.new()
	var mx := _strength("right") - _strength("left")
	var my := _strength("down") - _strength("up")
	f.move = Vector2(snappedf(clampf(mx, -1, 1), 0.01), snappedf(clampf(my, -1, 1), 0.01))
	if absf(f.move.x) < 0.35:
		f.move.x = 0.0
	if absf(f.move.y) < 0.45:
		f.move.y = 0.0
	for a in InputFrame.ACTIONS:
		f.held[a] = _held(a)
		f.pressed[a] = _just(a)
		f.released[a] = _just_released(a)

	# Digital direction edges (works for analog sticks too).
	var cur := {"left": f.move.x < -0.5, "right": f.move.x > 0.5, "up": f.move.y < -0.5, "down": f.move.y > 0.5}
	var newly := []
	for d in cur:
		if cur[d] and not _prev_dir[d]:
			newly.append(d)
	_prev_dir = cur

	# Double tap: press, release, press again quickly (and keep holding to run).
	for d in newly:
		if clock - last_tap[d] < Cfg.DOUBLE_TAP:
			f.dash_dir = DIRS[d]
			last_tap[d] = -9.0
		else:
			last_tap[d] = clock

	# Shift + direction (either order). Shift alone = back-step dodge, decided
	# after a short window so "shift then direction" is still a dash.
	var dir8 := Vector2(signf(f.move.x) if absf(f.move.x) > 0.5 else 0.0, signf(f.move.y) if absf(f.move.y) > 0.5 else 0.0)
	if f.pressed["dash"]:
		if dir8 != Vector2.ZERO:
			f.dash_dir = dir8
		else:
			_pending_dodge = clock
	elif f.held["dash"] and newly.size() > 0 and dir8 != Vector2.ZERO and clock - _last_dash > 0.12:
		f.dash_dir = dir8
	if _pending_dodge >= 0.0:
		if f.dash_dir != Vector2.ZERO:
			_pending_dodge = -1.0
		elif not f.held["dash"] or clock - _pending_dodge > 0.07:
			f.dodge = true
			_pending_dodge = -1.0
	if f.dash_dir != Vector2.ZERO:
		if clock - _last_dash < 0.12:
			f.dash_dir = Vector2.ZERO
		else:
			_last_dash = clock

	# Aim.
	f.aim = _default_aim(f)
	if use_mouse and fighter != null and fighter.arena != null:
		var mp: Vector2 = fighter.arena.get_mouse_world()
		if mp.distance_to(_last_mouse) > 1.0:
			_mouse_moved_t = clock
			_last_mouse = mp
		var d: Vector2 = mp - fighter.chest_pos()
		if d.length() > 8.0:
			f.aim = d.normalized()
	for p in prefixes:
		if p == "pad":
			var rs := Vector2(Input.get_joy_axis(0, JOY_AXIS_RIGHT_X), Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y))
			if rs.length() > 0.45:
				f.aim = rs.normalized()
	return f


func _default_aim(f: InputFrame) -> Vector2:
	if fighter == null or fighter.opponent == null:
		return Vector2.RIGHT
	var d: Vector2 = fighter.opponent.chest_pos() - fighter.chest_pos()
	if f.move.y != 0.0:
		d.y += f.move.y * 260.0
	return d.normalized() if d.length() > 1.0 else Vector2(fighter.facing, 0)
