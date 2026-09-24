class_name AIController
extends Controller
## CPU opponent. Produces InputFrames exactly like a player would, so it uses
## the same mechanics (buffering, dashes, parries...). Difficulty changes
## reaction time, defence probabilities and combo execution.

const LEVELS := [
	{"react": 0.36, "guard": 0.25, "parry": 0.03, "dodge": 0.1, "combo": 0.35, "aggr": 0.35, "tech": 0.2, "think": 0.3},
	{"react": 0.22, "guard": 0.48, "parry": 0.1, "dodge": 0.22, "combo": 0.72, "aggr": 0.55, "tech": 0.55, "think": 0.18},
	{"react": 0.13, "guard": 0.66, "parry": 0.22, "dodge": 0.35, "combo": 0.95, "aggr": 0.72, "tech": 0.85, "think": 0.1},
]

var level := 1
var cfg: Dictionary
## Training dummy behaviour: 0 = fight, 1 = stand, 2 = always guard, 3 = jump around.
var dummy := 0
var arena = null
var me: Fighter = null
var op: Fighter = null
var clock := 0.0

var move_dir := Vector2.ZERO
var move_until := 0.0
var hold_until := {}
var press_now := {}
var dash_req := Vector2.ZERO
var dodge_req := false
var next_think := 0.0
var plan := "neutral"
var plan_until := 0.0
var defense_at := -1.0
var defense_kind := ""
var threat_uid := -1
var combo_uid := -1
var combo_step_t := 0.0
var air_chase_until := 0.0
var want_height := 260.0
var last_proj_t := 0.0


func _init(p_level := 1) -> void:
	level = clampi(p_level, 0, 2)
	cfg = LEVELS[level]


func attach(f: Fighter, p_arena) -> void:
	me = f
	fighter = f
	arena = p_arena
	op = f.opponent


func _press(a: String, hold := 0.0) -> void:
	press_now[a] = true
	if hold > 0.0:
		hold_until[a] = clock + hold


func _hold(a: String, dur: float) -> void:
	hold_until[a] = maxf(hold_until.get(a, 0.0), clock + dur)


func _move(d: Vector2, dur: float) -> void:
	move_dir = d
	move_until = clock + dur


func poll(dt: float) -> InputFrame:
	clock += dt
	var f := InputFrame.new()
	if me == null or op == null:
		return f
	press_now.clear()
	dash_req = Vector2.ZERO
	dodge_req = false
	match dummy:
		1:
			return f
		2:
			f.held["guard"] = true
			f.pressed["guard"] = int(clock * 2.0) != int((clock - dt) * 2.0) and me.state != Fighter.S.GUARD
			return f
		3:
			if me.on_ground and randf() < dt * 1.5:
				f.pressed["jump"] = true
				f.held["jump"] = true
			return f
	_think(dt)
	if clock < move_until:
		f.move = move_dir
	for a in InputFrame.ACTIONS:
		var held: bool = hold_until.get(a, 0.0) > clock
		f.held[a] = held or press_now.get(a, false)
		f.pressed[a] = press_now.get(a, false)
	f.dash_dir = dash_req
	f.dodge = dodge_req
	var target := op.chest_pos() + op.vel * 0.12
	var d := target - me.chest_pos()
	f.aim = d.normalized() if d.length() > 1.0 else Vector2(me.facing, 0)
	return f


# ================================================================ brain
func _think(_dt: float) -> void:
	var dx := op.position.x - me.position.x
	var adx := absf(dx)
	var sx := signf(dx) if dx != 0.0 else float(me.facing)
	var dy := op.center_pos().y - me.center_pos().y

	# --- recovery / teching
	if me.state == Fighter.S.TUMBLE and randf() < cfg["tech"] * 0.25:
		_press("jump")
		return
	if me.state == Fighter.S.HITSTUN and me.knockdown_pending and me.vel.y > 0.0 and me.position.y > Cfg.FLOOR_Y - 80 and randf() < cfg["tech"] * 0.2:
		_press("guard")
	if me.state == Fighter.S.GRABBED and randf() < cfg["tech"] * 0.12:
		_press("throw")
	if me.state == Fighter.S.KNOCKDOWN:
		if randf() < 0.3:
			_move(Vector2(-sx if randf() < 0.5 else sx, 0), 0.3)
		return

	# --- continue combos when our attack connected
	if me.state == Fighter.S.ATTACK:
		_combo_logic(sx)
		return
	if me.state == Fighter.S.GRAB:
		if randf() < 0.5:
			_move(Vector2(-sx, 0), 0.3)
		return

	# --- defence
	var threat := _threat(adx)
	if threat:
		if defense_at < 0.0:
			defense_at = clock + cfg["react"] * randf_range(0.7, 1.3)
			var r := randf()
			if r < cfg["parry"]:
				defense_kind = "parry"
			elif r < cfg["parry"] + cfg["guard"]:
				defense_kind = "guard"
			elif r < cfg["parry"] + cfg["guard"] + cfg["dodge"]:
				defense_kind = "dodge"
			elif me.char_id == "ronin" and me.cooldowns["r"] <= 0.0 and randf() < 0.35 and level > 0:
				defense_kind = "counter"
			else:
				defense_kind = "none"
		if clock >= defense_at and me.is_free() or (clock >= defense_at and me.state == Fighter.S.GUARD):
			_do_defense(sx)
			return
	else:
		defense_at = -1.0
		if hold_until.get("guard", 0.0) > clock and me.state == Fighter.S.GUARD and randf() < 0.2:
			hold_until["guard"] = 0.0

	if not me.is_free():
		# guard-cancel options
		if me.state == Fighter.S.GUARD and not threat and randf() < 0.1:
			hold_until["guard"] = 0.0
		return

	# --- punish / pressure opponents in trouble
	if clock < air_chase_until and me.char_id == "ronin":
		_air_chase(dx, dy, sx)
		return
	if op.state in [Fighter.S.STAGGER, Fighter.S.GUARDBREAK] and adx < 170.0 and absf(dy) < 140.0:
		_press("heavy" if randf() < 0.5 else "light")
		return
	if op.state in [Fighter.S.HITSTUN, Fighter.S.TUMBLE] and adx < 150.0 and absf(dy) < 160.0 and randf() < cfg["combo"]:
		_press("light")
		return

	if clock < next_think:
		return
	next_think = clock + cfg["think"] * randf_range(0.6, 1.4)
	if me.is_flier:
		_neutral_flier(dx, dy, adx, sx)
	else:
		_neutral_ground(dx, dy, adx, sx)


func _threat(adx: float) -> bool:
	if op.state == Fighter.S.ATTACK and not op.cur_move.is_empty():
		var m: Dictionary = op.cur_move
		if op.move_t < float(m["startup"]) + float(m["active"]):
			var box: Rect2 = m["box"]
			if box.size != Vector2.ZERO:
				var r := op.box_world(box).grow(50.0)
				if r.intersects(me.hurtbox()):
					return true
			var lg: Vector2 = m["lunge"]
			if adx < 300.0 and absf(lg.x) > 0.0:
				return true
			if m["kind"] in ["special", "ult"] and adx < 380.0:
				return true
	for p in arena.projectiles:
		if not is_instance_valid(p) or not p.alive or p.owner_f != op:
			continue
		if p.kind == "bolt":
			if absf(p.position.x - me.position.x) < p.width * 0.5 + 40.0 and p.age < p.telegraph:
				return true
			continue
		var fut: Vector2 = p.position + p.vel * 0.3
		var hb := me.hurtbox().grow(70.0)
		if hb.has_point(fut) or hb.has_point(p.position):
			return true
	return false


func _do_defense(sx: float) -> void:
	match defense_kind:
		"parry":
			var t_left := 0.0
			if op.state == Fighter.S.ATTACK and not op.cur_move.is_empty():
				t_left = float(op.cur_move["startup"]) - op.move_t
			if t_left < 0.12:
				_press("guard")
				defense_at = clock + 0.4
		"guard":
			if me.state != Fighter.S.GUARD:
				_press("guard", 0.45)
			else:
				_hold("guard", 0.25)
		"dodge":
			if me.is_flier and not me.on_ground:
				dash_req = Vector2(-sx, -1).normalized() if randf() < 0.5 else Vector2(0, -1)
				dash_req = Vector2(signf(dash_req.x), signf(dash_req.y))
			elif randf() < 0.5:
				dodge_req = true
			else:
				_press("jump", 0.2)
			defense_at = clock + 0.5
		"counter":
			_press("r")
			defense_at = clock + 0.8
		_:
			defense_at = clock + 0.3


func _combo_logic(sx: float) -> void:
	var n := me.move_name
	if not me.move_connected:
		return
	if combo_uid == me.move_uid:
		return
	if randf() > cfg["combo"]:
		combo_uid = me.move_uid
		return
	combo_uid = me.move_uid
	if me.ki >= Cfg.KI_MAX and randf() < 0.55 and op.alive:
		_press("f")
		return
	var ronin := me.char_id == "ronin"
	match n:
		"l1", "down_l", "air_l1":
			_press("light")
		"l2", "air_l2":
			_press("light")
		"l3":
			var r := randf()
			if r < 0.45:
				_press("light")
			elif r < 0.75:
				_move(Vector2(0, -1), 0.2)
				_press("heavy")
			else:
				_press("q" if me.cooldowns["q"] <= 0.0 else "light")
		"up_h":
			if ronin:
				_move(Vector2(sx * 0.3, -1), 0.3)
				_press("jump")
				air_chase_until = clock + 1.4
		"up_l":
			if ronin:
				_press("jump")
				air_chase_until = clock + 1.2
			else:
				_move(Vector2(0, -1), 0.4)
				_press("light")
		"air_l3":
			_move(Vector2(0, 1), 0.2)
			_press("light")
		"l4", "h", "air_h":
			if me.cooldowns["e"] <= 0.0 and randf() < 0.4:
				_press("e")
			elif me.cooldowns["q"] <= 0.0 and randf() < 0.3:
				_press("q")
		"run_l":
			_press("light")


func _air_chase(dx: float, dy: float, sx: float) -> void:
	var dist := me.center_pos().distance_to(op.center_pos())
	_move(Vector2(sx, 0), 0.1)
	if dy < -60.0 and me.vel.y > -200.0 and me.jumps_left > 0:
		_press("jump")
	if dist < 150.0:
		_press("light")


func _neutral_ground(dx: float, dy: float, adx: float, sx: float) -> void:
	var aggr: float = cfg["aggr"]
	var op_high := dy < -170.0
	# anti-air
	if op_high and adx < 170.0 and randf() < 0.55:
		_move(Vector2(0, -1), 0.2)
		_press("heavy" if randf() < 0.5 else "light")
		return
	# flier high above: chase with jumps, crescent waves, wait underneath
	if op_high:
		var r := randf()
		if r < 0.3 and me.cooldowns["e"] <= 0.0:
			_press("e")
			return
		if r < 0.65 and adx < 420.0:
			_move(Vector2(sx, 0), 0.5)
			_press("jump", 0.3)
			air_chase_until = clock + 1.2
			return
		if r < 0.8:
			dash_req = Vector2(0, -1)
			air_chase_until = clock + 1.2
			return
		_move(Vector2(sx, 0), 0.4)
		return
	# ultimate when in range
	if me.ki >= Cfg.KI_MAX and adx < 420.0 and randf() < 0.3:
		_press("f")
		return
	if adx < 150.0:
		var r2 := randf()
		if op.state == Fighter.S.GUARD and r2 < 0.45:
			_press("throw")
		elif r2 < 0.35 + aggr * 0.3:
			_press("light")
		elif r2 < 0.55 + aggr * 0.2:
			_move(Vector2(0, 1), 0.2)
			_press("light")
		elif r2 < 0.7:
			_press("heavy")
		elif r2 < 0.8:
			dodge_req = true
		else:
			_move(Vector2(-sx, 0), 0.3)
		return
	if adx < 380.0:
		var r3 := randf()
		if r3 < 0.25 * aggr + 0.1:
			dash_req = Vector2(sx, 0)
			_move(Vector2(sx, 0), 0.35)
		elif r3 < 0.4 and me.cooldowns["q"] <= 0.0 and adx < 330.0:
			_press("q")
		elif r3 < 0.55:
			_move(Vector2(sx, 0), 0.25)
			_press("jump", 0.25)
		elif r3 < 0.7:
			_move(Vector2(sx, 0), 0.4)
		elif r3 < 0.8 and me.cooldowns["e"] <= 0.0:
			_press("e")
		else:
			_move(Vector2(-sx, 0), 0.25)
		return
	# far
	var r4 := randf()
	if r4 < 0.35 and me.cooldowns["e"] <= 0.0:
		_press("e")
	elif r4 < 0.75 * (0.5 + aggr):
		dash_req = Vector2(sx, 0)
		_move(Vector2(sx, 0), 0.6)
	else:
		_move(Vector2(sx, 0), 0.4)


func _neutral_flier(dx: float, dy: float, adx: float, sx: float) -> void:
	var aggr: float = cfg["aggr"]
	var h := Cfg.FLOOR_Y - me.position.y
	var low_stamina := me.stamina < me.stamina_max * 0.28
	if me.exhausted or (low_stamina and me.on_ground and me.stamina < me.stamina_max * 0.7):
		# rest on the ground, keep distance
		if adx < 220.0:
			if randf() < 0.4:
				_press("light")
			else:
				dodge_req = true
		else:
			_move(Vector2(-sx, 0), 0.3)
			if me.cooldowns["q"] <= 0.0 and randf() < 0.4:
				_press("q")
		return
	if low_stamina and not me.on_ground:
		_move(Vector2(-sx * 0.5, 1), 0.5)
		return
	if me.ki >= Cfg.KI_MAX and randf() < 0.35:
		_press("f")
		return
	if me.on_ground:
		if randf() < 0.7:
			_move(Vector2(-sx * 0.3, -1), 0.3)
			_press("jump")
		elif adx < 140.0:
			_press("light")
		return
	# airborne
	var r := randf()
	if adx < 140.0 and absf(dy) < 130.0:
		if r < 0.45 + aggr * 0.3:
			_press("light")
		elif r < 0.65:
			_move(Vector2(0, -1), 0.2)
			_press("heavy")
		elif r < 0.8:
			dash_req = Vector2(-sx, -1)
		else:
			_press("heavy")
		return
	# keep a comfortable height and distance, zone with feathers
	var want_x := 320.0 + (1.0 - aggr) * 150.0
	var mv := Vector2.ZERO
	if adx < want_x - 60.0:
		mv.x = -sx
	elif adx > want_x + 80.0:
		mv.x = sx
	if h < want_height - 60.0:
		mv.y = -1.0
	elif h > want_height + 120.0:
		mv.y = 1.0
	_move(mv, 0.35)
	if r < 0.3 and me.cooldowns["q"] <= 0.0:
		_press("q")
	elif r < 0.4 and me.cooldowns["e"] <= 0.0:
		_press("e")
	elif r < 0.5 and me.cooldowns["r"] <= 0.0 and adx < 520.0:
		_press("r")
	elif r < 0.5 + aggr * 0.25:
		var d := Vector2(sx, signf(dy) if absf(dy) > 60.0 else 0.0)
		dash_req = d
		_move(d, 0.4)
	elif r < 0.75 and op.on_ground and adx < 200.0:
		_move(Vector2(0, 1), 0.2)
		_press("heavy")
	want_height = randf_range(160.0, 360.0) if randf() < 0.2 else want_height
