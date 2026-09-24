class_name Fighter
extends Node2D
## Base fighter: custom kinematics, state machine, combat, procedural rig.
##
## Positions are in world units (background pixels). The fighter's feet are at
## `position`. Drawing happens in "art pixels" (Cfg.PX world units each) inside
## the low-res actor viewport, so everything is naturally pixelated.

enum S {
	IDLE, WALK, RUN, CROUCH, AIR, FLY, DASH, DODGE, ATTACK, GUARD, PARRY, BLOCKSTUN,
	HITSTUN, TUMBLE, KNOCKDOWN, GETUP, STAGGER, GUARDBREAK, GRAB, GRABBED, WALL,
	LOCKED, INTRO, WIN, KO,
}
enum R { NONE, HIT, BLOCK, PARRY, WHIFF, COUNTERED, ARMOR }

const PX := Cfg.PX
## Global damage tuning knob (round length).
const DAMAGE_SCALE := 0.82
const FREE_STATES := [S.IDLE, S.WALK, S.RUN, S.CROUCH, S.AIR, S.FLY, S.WALL]

const MOVE_DEFAULTS := {
	"name": "", "kind": "light",
	"startup": 0.08, "active": 0.06, "recovery": 0.2,
	"box": Rect2(6, -44, 22, 20),
	"dmg": 30.0, "chip": 0.12, "guard_dmg": 10.0,
	"hitstun": 0.3, "blockstun": 0.16,
	"kb": Vector2(200, 0), "air_kb": Vector2(240, 320),
	"launch": false, "knockdown": false, "wall_bounce": false, "ground_bounce": false,
	"hitstop": 0.06, "shake": 2.0, "zoom": 0.0,
	"hits": 1, "hit_every": 0.07,
	"lunge": Vector2.ZERO, "lunge_t0": 0.0, "lunge_t1": 0.0,
	"air": false, "air_stall": 0.0, "hover": false, "end_on_land": true, "landing_lag": 0.06,
	"next": "", "chain_dir": true,
	"cancel_special": true, "jump_cancel": false,
	"parryable": true, "unblockable": false, "otg": false,
	"armor": false, "invuln": Vector2(-1, -1),
	"sfx": "swing_l", "hit_sfx": "hit_l", "spark": "normal",
	"slash": {}, "poses": [],
	"chargeable": false,
	"spawn_t": -1.0, "spawn": "", "update": "", "on_hit": "", "pose_fn": "",
	"cost": 0.0, "cd_key": "", "cd": 0.0,
	"anti_air": false, "strength": 0,
	"kb_along_aim": false, "no_turn": false, "ult": false, "ult_hit": false,
	"throw": false, "keep_momentum": false,
}

# ------------------------------------------------------------ identity
var player_idx := 0
var char_id := ""
var display_name := ""
var arena = null  # Arena
var opponent: Fighter = null
var controller: Controller = null
var inp := InputFrame.new()
var input_enabled := false
var palette := {}
var palette_alt := {}
var fx_color := Color(0.5, 0.95, 1.0)
var fx_color2 := Color(1, 1, 1)

# ------------------------------------------------------------ stats
var max_hp := 1000.0
var walk_speed := 320.0
var run_speed := 700.0
var dash_speed := 1250.0
var dash_time := 0.16
var air_dash_speed := 1100.0
var jump_vel := 1400.0
var dbl_jump_vel := 1360.0
var super_jump_vel := 1650.0
var gravity := 3000.0
var fall_mult := 1.22
var max_fall := 1500.0
var air_speed := 380.0
var air_accel := 2600.0
var ground_accel := 5200.0
var is_flier := false
var extra_jumps := 1
var air_dashes_max := 1
var weight := 1.0
var body_w := 16.0
var body_h := 58.0

# flier
var fly_speed := 430.0
var boost_speed := 760.0
var fly_accel := 2800.0
var takeoff_vel := 820.0
var stamina_max := 100.0
var drain_hover := 7.0
var drain_move := 10.0
var drain_boost := 22.0
var dash_stamina := 12.0
var stamina_regen := 45.0

# rig dimensions (art px)
var HIP_H := 27.0
var THIGH := 13.5
var SHIN := 13.5
var TORSO := 15.0
var NECK := 2.0
var HEAD_R := 5.0
var UARM := 9.0
var LARM := 9.0
var SH_DROP := 2.0

# ------------------------------------------------------------ runtime
var vel := Vector2.ZERO
var facing := 1
var on_ground := true
var state: int = S.IDLE
var state_t := 0.0
var hp := 1000.0
var ki := 0.0
var guard_hp := 100.0
var guard_regen_delay := 0.0
var stamina := 100.0
var exhausted := false
var hitstop := 0.0
var invuln := 0.0
var alive := true
var clock := 0.0

var jumps_left := 1
var air_dashes_left := 1
var jump_cut := false
var fastfall := false
var run_active := false
var run_release := 0.0
var boosting := false
var boost_release := 0.0
var dash_dir := Vector2.ZERO
var dash_t := 0.0
var dash_is_dodge := false
var perfect_used := false
var afterimage_t := 0.0
var wall_side := 0
var step_t := 0.0

var buffer := {}
var buffered_dash := Vector2.ZERO
var last_press := {"light": -9.0, "heavy": -9.0, "guard": -9.0, "jump": -9.0}
var cooldowns := {"q": 0.0, "e": 0.0, "r": 0.0}

var moves := {}
var cur_move: Dictionary = {}
var move_name := ""
var move_t := 0.0
var move_uid := 0
var move_connected := false
var move_hit_keys := {}
var move_spawned := false
var move_from_pose := {}
var charging := false
var charge_t := 0.0
var charge_mult := 1.0
var armor_hits := 0
var landing_lag := 0.0

var hitstun := 0.0
var combo_hits := 0
var combo_damage := 0.0
var juggle := 0
var knockdown_pending := false
var wall_bounce_pending := false
var ground_bounce_pending := false
var wall_bounced := false
var ground_bounced := false
var stun_time := 0.0
var grab_partner: Fighter = null
var grab_break_ok := false
var last_hit_by_move := {}

# visuals
var P := {}  # named poses
var pose := {}
var joints := {}
var anim_t := 0.0
var walk_phase := 0.0
var squash := 1.0
var flash_t := 0.0
var flash_color := Color.WHITE
var shake_off := Vector2.ZERO
var tumble_rot := 0.0
var aura_t := 0.0
var flip_t := 0.0
var vanished := false
var ghost_draw := false
var chains: Array = []

signal ko


# ================================================================ setup
func setup(p_arena, idx: int, p_controller: Controller, alt: bool) -> void:
	arena = p_arena
	player_idx = idx
	controller = p_controller
	controller.fighter = self
	_setup_stats()
	_build_poses()
	_build_moves()
	if alt and not palette_alt.is_empty():
		palette = palette_alt
		_on_alt_palette()
	pose = P["idle"].duplicate()
	hp = max_hp
	_init_chains()


## Menu preview: no arena, no controller, just the animated rig.
func setup_preview(alt: bool) -> void:
	_setup_stats()
	_build_poses()
	_build_moves()
	if alt and not palette_alt.is_empty():
		palette = palette_alt
		_on_alt_palette()
	pose = P["idle"].duplicate()
	hp = max_hp
	_init_chains()
	for c in chains:
		c.reset(position + Vector2(0, -HIP_H * 2 * PX))


func preview_pose(_dt: float) -> Dictionary:
	return _pose_idle()


func preview_tick(dt: float, showcase := "") -> void:
	clock += dt
	anim_t += dt
	var target: Dictionary = preview_pose(dt)
	if showcase != "" and P.has(showcase):
		target = P[showcase]
	Pose.blend_into(pose, target, 1.0 - exp(-dt * (30.0 if showcase != "" else 10.0)))
	joints = compute_joints(pose)
	_update_chains(dt)
	queue_redraw()


func reset_for_round(x: float, face: int) -> void:
	position = Vector2(x, Cfg.FLOOR_Y)
	vel = Vector2.ZERO
	facing = face
	on_ground = true
	hp = max_hp
	guard_hp = 100.0
	stamina = stamina_max
	exhausted = false
	alive = true
	hitstop = 0.0
	invuln = 0.0
	cur_move = {}
	move_name = ""
	charging = false
	combo_hits = 0
	juggle = 0
	grab_partner = null
	buffer.clear()
	for k in cooldowns:
		cooldowns[k] = 0.0
	jumps_left = extra_jumps
	air_dashes_left = air_dashes_max
	boosting = false
	run_active = false
	flash_t = 0.0
	set_state(S.INTRO)
	pose = P["idle"].duplicate()
	for c in chains:
		c.reset(position + Vector2(0, -HIP_H * 2 * PX))


# Subclass hooks ------------------------------------------------------
func _setup_stats() -> void:
	pass


func _build_poses() -> void:
	P["idle"] = Pose.make({})


func _build_moves() -> void:
	pass


func _init_chains() -> void:
	pass


func _on_alt_palette() -> void:
	pass


func draw_body(_ci: CanvasItem, _p: Dictionary, _j: Dictionary, _sil: Color, _use_sil: bool) -> void:
	pass


func mv(d: Dictionary) -> Dictionary:
	var m := MOVE_DEFAULTS.duplicate(true)
	for k in d:
		m[k] = d[k]
	return m


# ================================================================ helpers
func is_free() -> bool:
	return state in FREE_STATES


func airborne() -> bool:
	return not on_ground


func center_pos() -> Vector2:
	return position + Vector2(0, -body_h * PX * 0.5)


func chest_pos() -> Vector2:
	return position + Vector2(0, -body_h * PX * 0.68)


func head_pos() -> Vector2:
	return position + Vector2(0, -body_h * PX * 0.9)


func hurtbox() -> Rect2:
	var w := body_w * PX
	var h := body_h * PX
	match state:
		S.CROUCH:
			h *= 0.66
		S.KNOCKDOWN, S.KO:
			return Rect2(position.x - h * 0.45, position.y - 14 * PX, h * 0.9, 14 * PX)
		S.TUMBLE, S.HITSTUN:
			if not on_ground:
				w *= 1.25
		S.ATTACK:
			if cur_move.get("name", "").begins_with("down"):
				h *= 0.72
	return Rect2(position.x - w * 0.5, position.y - h, w, h)


func pushbox() -> Rect2:
	var w := body_w * PX * 0.8
	var h := body_h * PX * (0.66 if state == S.CROUCH else 0.9)
	return Rect2(position.x - w * 0.5, position.y - h, w, h)


func box_world(r: Rect2) -> Rect2:
	var x := r.position.x if facing > 0 else -r.position.x - r.size.x
	return Rect2(position.x + x * PX, position.y + r.position.y * PX, r.size.x * PX, r.size.y * PX)


func local_to_world(p: Vector2) -> Vector2:
	return position + Vector2(p.x * facing, p.y) * PX + shake_off


func face_opponent() -> void:
	if opponent == null:
		return
	var dx := opponent.position.x - position.x
	if absf(dx) > 8.0:
		facing = 1 if dx > 0 else -1


func set_state(s: int) -> void:
	if state == S.ATTACK and s != S.ATTACK:
		_end_move_cleanup()
	state = s
	state_t = 0.0


func gain_ki(amount: float) -> void:
	ki = clampf(ki + amount, 0.0, Cfg.KI_MAX)


func hp_ratio() -> float:
	return clampf(hp / max_hp, 0.0, 1.0)


func _neutral_state() -> int:
	if on_ground:
		return S.IDLE
	if is_flier and not exhausted:
		return S.FLY
	return S.AIR


func go_neutral() -> void:
	set_state(_neutral_state())


func fx():
	return arena.fx


func snd(n: String, vol := 0.0, pitch := 1.0) -> void:
	Sfx.play(n, vol, pitch)


# ================================================================ tick
func tick(dt: float) -> void:
	clock += dt
	anim_t += dt
	flash_t = maxf(0.0, flash_t - dt)
	if hitstop > 0.0:
		hitstop -= dt
		if state in [S.HITSTUN, S.BLOCKSTUN, S.GUARDBREAK, S.LOCKED, S.TUMBLE]:
			shake_off = Vector2(randf_range(-2.5, 2.5), 0)
		else:
			shake_off = Vector2.ZERO
		# still poll input so presses during hitstop get buffered
		_read_input(dt)
		queue_redraw()
		return
	shake_off = Vector2.ZERO
	state_t += dt
	_tick_timers(dt)
	_read_input(dt)
	_update_state(dt)
	_physics(dt)
	_update_anim(dt)
	_update_chains(dt)
	queue_redraw()


func _tick_timers(dt: float) -> void:
	invuln = maxf(0.0, invuln - dt)
	for k in cooldowns:
		cooldowns[k] = maxf(0.0, cooldowns[k] - dt)
	if state in [S.GUARD, S.BLOCKSTUN, S.PARRY]:
		guard_regen_delay = 1.0
	else:
		guard_regen_delay -= dt
		if guard_regen_delay <= 0.0:
			guard_hp = minf(100.0, guard_hp + 28.0 * dt)
	squash = lerpf(squash, 1.0, 1.0 - exp(-dt * 14.0))
	landing_lag = maxf(0.0, landing_lag - dt)
	# flight stamina
	if is_flier:
		if on_ground:
			stamina = minf(stamina_max, stamina + stamina_regen * dt)
			if exhausted and stamina >= stamina_max * 0.35:
				exhausted = false
		elif not exhausted and state in [S.FLY, S.ATTACK, S.GUARD, S.PARRY, S.BLOCKSTUN, S.DODGE]:
			var d := drain_hover
			if boosting:
				d = drain_boost
			elif state == S.FLY and inp.move.length() > 0.2:
				d = drain_move
			stamina = maxf(0.0, stamina - d * dt)
			if stamina <= 0.0:
				exhausted = true
				boosting = false
				if state == S.FLY or state == S.GUARD:
					set_state(S.AIR)
				fx().text(head_pos() + Vector2(0, -20), "УСТАЛОСТЬ", Color(1, 0.6, 0.5), 1)
				snd("flap", -6, 0.7)


func _read_input(dt: float) -> void:
	for k in buffer.keys():
		buffer[k] -= dt
		if buffer[k] <= 0.0:
			buffer.erase(k)
	if controller == null:
		inp = InputFrame.new()
		return
	var f: InputFrame = controller.poll(dt)
	if not input_enabled:
		f = InputFrame.new()
	inp = f
	for a in InputFrame.ACTIONS:
		if inp.p(a):
			buffer[a] = Cfg.BUFFER_TIME
			if last_press.has(a):
				last_press[a] = clock
	# light + heavy together = throw
	if (inp.p("light") and clock - last_press["heavy"] < 0.08) or (inp.p("heavy") and clock - last_press["light"] < 0.08):
		buffer["throw"] = Cfg.BUFFER_TIME
	if inp.dash_dir != Vector2.ZERO:
		buffer["dashdir"] = Cfg.BUFFER_TIME
		buffered_dash = inp.dash_dir
	if inp.dodge:
		buffer["dodge"] = Cfg.BUFFER_TIME


func has_buf(a: String) -> bool:
	return buffer.has(a)


func take(a: String) -> bool:
	if buffer.has(a):
		buffer.erase(a)
		return true
	return false


# ================================================================ states
func _update_state(dt: float) -> void:
	match state:
		S.INTRO, S.WIN:
			vel.x = move_toward(vel.x, 0.0, 3000 * dt)
		S.IDLE, S.WALK:
			_st_ground(dt)
		S.CROUCH:
			_st_crouch(dt)
		S.RUN:
			_st_run(dt)
		S.AIR:
			_st_air(dt)
		S.FLY:
			_st_fly(dt)
		S.WALL:
			_st_wall(dt)
		S.DASH:
			_st_dash(dt)
		S.DODGE:
			_st_dodge(dt)
		S.ATTACK:
			_st_attack(dt)
		S.GUARD:
			_st_guard(dt)
		S.PARRY:
			_st_parry(dt)
		S.BLOCKSTUN:
			_st_blockstun(dt)
		S.HITSTUN:
			_st_hitstun(dt)
		S.TUMBLE:
			_st_tumble(dt)
		S.KNOCKDOWN:
			_st_knockdown(dt)
		S.GETUP:
			_st_getup(dt)
		S.STAGGER, S.GUARDBREAK:
			_st_stagger(dt)
		S.GRAB:
			_st_grab(dt)
		S.GRABBED:
			_st_grabbed(dt)
		S.LOCKED:
			vel = Vector2.ZERO
		S.KO:
			vel.x = move_toward(vel.x, 0.0, 1500 * dt)


func _try_actions() -> bool:
	if landing_lag > 0.0:
		return false
	if has_buf("f") and ki >= Cfg.KI_MAX and moves.has("ult"):
		take("f")
		start_move("ult")
		return true
	for k in ["q", "e", "r"]:
		if has_buf(k):
			if cooldowns[k] <= 0.0 and _ability_ok(k):
				take(k)
				start_move(_ability_move(k))
				return true
			elif cooldowns[k] > 0.0:
				take(k)
				fx().text(head_pos() + Vector2(0, -24), "%.1f" % cooldowns[k], Color(0.7, 0.7, 0.8), 0)
	if has_buf("throw") and on_ground and moves.has("throw"):
		take("throw")
		take("light")
		take("heavy")
		start_move("throw")
		return true
	if has_buf("guard"):
		take("guard")
		start_parry()
		return true
	if has_buf("heavy"):
		take("heavy")
		start_move(normal_name("heavy"))
		return true
	if has_buf("light"):
		take("light")
		start_move(normal_name("light"))
		return true
	if has_buf("dashdir"):
		take("dashdir")
		if start_dash(buffered_dash):
			return true
	if has_buf("dodge"):
		take("dodge")
		if start_dodge(Vector2.ZERO):
			return true
	if has_buf("jump"):
		if _try_jump():
			take("jump")
			return true
	return false


func _ability_move(k: String) -> String:
	var air_name := "air_" + k
	if not on_ground and moves.has(air_name):
		return air_name
	return k


func _ability_ok(k: String) -> bool:
	var m: String = _ability_move(k)
	if not moves.has(m):
		return false
	return ki >= float(moves[m]["cost"])


func normal_name(kind: String) -> String:
	var up := inp.move.y < -0.5
	var down := inp.move.y > 0.5
	var air := not on_ground
	var pre := "air_" if air else ""
	var n := ""
	var running := state == S.RUN or (state == S.DASH and dash_t > 0.04) or boosting
	if kind == "light":
		if running and moves.has(pre + "run_l"):
			n = pre + "run_l"
		elif up:
			n = pre + "up_l"
		elif down:
			n = pre + "down_l"
		else:
			n = pre + "l1"
		if not moves.has(n):
			n = pre + "l1"
	else:
		if up:
			n = pre + "up_h"
		elif down:
			n = pre + "down_h"
		else:
			n = pre + "h"
		if not moves.has(n):
			n = pre + "h"
	if not moves.has(n):
		n = n.trim_prefix("air_")
	return n


# ---------------------------------------------------------------- ground
func _st_ground(dt: float) -> void:
	if not on_ground:
		set_state(_neutral_state())
		return
	if _try_actions():
		return
	if is_flier and not exhausted and inp.move.y < -0.5:
		takeoff()
		return
	if inp.move.y > 0.5:
		set_state(S.CROUCH)
		return
	face_opponent()
	var target := inp.move.x * walk_speed
	vel.x = move_toward(vel.x, target, ground_accel * dt)
	if absf(inp.move.x) > 0.1:
		if state != S.WALK:
			set_state(S.WALK)
		walk_phase += dt * 11.0 * (walk_speed / 320.0)
	elif state != S.IDLE:
		set_state(S.IDLE)


func _st_crouch(dt: float) -> void:
	if not on_ground:
		set_state(_neutral_state())
		return
	face_opponent()
	vel.x = move_toward(vel.x, 0.0, ground_accel * dt)
	if _try_actions():
		return
	if inp.move.y <= 0.5:
		set_state(S.IDLE)


func _st_run(dt: float) -> void:
	if not on_ground:
		set_state(_neutral_state())
		return
	if _try_actions():
		return
	var d := signf(inp.move.x) if absf(inp.move.x) > 0.4 else 0.0
	if d != 0.0:
		if int(d) != facing:
			facing = int(d)
			fx().dust(position, 5, -d, 1.2)
			snd("step", -4, 1.2)
		vel.x = move_toward(vel.x, d * run_speed, 11000.0 * dt)
		run_release = 0.0
	else:
		run_release += dt
		vel.x = move_toward(vel.x, 0.0, 2500 * dt)
		if run_release > 0.12:
			run_active = false
			set_state(S.IDLE)
			return
	walk_phase += dt * 15.0
	step_t -= dt
	if step_t <= 0.0:
		step_t = 0.2
		snd("step", -10, randf_range(0.9, 1.15))
		fx().dust(position + Vector2(-facing * 12, 0), 2, -facing, 0.5)
		arena.petals.impulse(position, 90.0, Vector2(vel.x * 0.35, -60))


func takeoff() -> void:
	on_ground = false
	vel.y = -takeoff_vel
	set_state(S.FLY)
	snd("flap", -2)
	fx().dust(position, 8, 0, 1.4)
	arena.petals.impulse(position, 150.0, Vector2(0, -260))
	squash = 1.15


func _try_jump() -> bool:
	if is_flier:
		if on_ground and not exhausted:
			takeoff()
			return true
		if state == S.FLY and stamina > 6.0:
			vel.y = minf(vel.y, -620.0)
			stamina -= 6.0
			snd("flap", -4, 1.1)
			fx().ring(position + Vector2(0, -20), Color(1, 1, 1, 0.5), 10, 50, 0.25, 3)
			return true
		if state == S.AIR and not exhausted:
			set_state(S.FLY)
			vel.y = -500
			snd("flap", -3)
			return true
		return false
	if on_ground:
		_do_jump(0)
		return true
	if state == S.WALL:
		_do_jump(2)
		return true
	if jumps_left > 0:
		_do_jump(1)
		return true
	return false


func _do_jump(kind: int) -> void:
	var hx := inp.move.x
	match kind:
		0:
			vel.y = -jump_vel
			if run_active and state == S.RUN:
				vel.x = facing * run_speed * 0.92
			else:
				vel.x = hx * air_speed
			snd("jump")
			fx().dust(position, 6, 0, 1.0)
			arena.petals.impulse(position, 120.0, Vector2(vel.x * 0.3, -200))
		1:
			vel.y = -dbl_jump_vel
			jumps_left -= 1
			if absf(hx) > 0.3:
				vel.x = hx * maxf(air_speed, absf(vel.x) * 0.9)
			snd("double_jump")
			flip_t = 0.34
			fx().ring(position + Vector2(0, -6), Color(fx_color, 0.8), 12, 70, 0.3, 4, 0.35)
			fx().petal_burst(position + Vector2(0, -10), 8, Vector2(0, 120))
		2:
			vel = Vector2(-wall_side * 640.0, -jump_vel * 0.92)
			facing = -wall_side
			jumps_left = extra_jumps
			air_dashes_left = air_dashes_max
			snd("jump", 0, 1.15)
			fx().dust(position + Vector2(wall_side * 24, -40), 6, -wall_side, 1.0)
		3:
			vel.y = -super_jump_vel
			vel.x = hx * air_speed
			jumps_left = 0
			snd("double_jump", 0, 0.8)
			fx().ring(position, Color(fx_color, 0.9), 16, 90, 0.35, 5, 0.3)
			fx().dust(position, 12, 0, 1.6)
			arena.petals.impulse(position, 220.0, Vector2(0, -420))
	on_ground = false
	jump_cut = kind == 3
	fastfall = false
	squash = 1.18
	set_state(S.AIR)


# ---------------------------------------------------------------- air
func _st_air(dt: float) -> void:
	if on_ground:
		go_neutral()
		return
	if _try_actions():
		return
	var cap := maxf(air_speed, absf(vel.x))
	if absf(inp.move.x) > 0.1:
		vel.x = move_toward(vel.x, inp.move.x * cap, air_accel * dt)
	else:
		vel.x = move_toward(vel.x, 0.0, air_accel * 0.35 * dt)
	if not jump_cut and vel.y < -400.0 and not inp.h("jump") and not is_flier:
		vel.y *= 0.55
		jump_cut = true
	if inp.move.y > 0.5 and vel.y > -150.0:
		fastfall = true
	# wall cling for grounded fighters
	if not is_flier and wall_side != 0 and signf(inp.move.x) == wall_side and vel.y > -100.0:
		set_state(S.WALL)
		vel = Vector2.ZERO
		jumps_left = extra_jumps
		air_dashes_left = air_dashes_max
		fx().dust(position + Vector2(wall_side * 20, -60), 4, -wall_side, 0.8)
		snd("land", -8, 1.3)
		return
	if is_flier and not exhausted and inp.move.y < -0.5:
		set_state(S.FLY)


func _st_wall(dt: float) -> void:
	if on_ground:
		go_neutral()
		return
	facing = -wall_side
	vel.x = wall_side * 30.0
	vel.y = minf(vel.y + 900.0 * dt, 140.0)
	if has_buf("jump"):
		take("jump")
		_do_jump(2)
		return
	if _try_actions():
		return
	if signf(inp.move.x) != wall_side and state_t > 0.1:
		set_state(S.AIR)
		return
	if wall_side == 0:
		set_state(S.AIR)


func _st_fly(dt: float) -> void:
	if on_ground:
		go_neutral()
		return
	if exhausted:
		set_state(S.AIR)
		return
	if _try_actions():
		return
	var d := inp.move
	if d.length() > 1.0:
		d = d.normalized()
	if boosting:
		if d.length() < 0.2:
			boost_release += dt
			if boost_release > 0.12:
				boosting = false
		else:
			boost_release = 0.0
	var spd := boost_speed if boosting else fly_speed
	var target := d * spd
	var acc := fly_accel * (1.6 if boosting else 1.0)
	vel = vel.move_toward(target, acc * dt)
	if boosting and absf(d.x) > 0.2:
		facing = 1 if d.x > 0 else -1
	elif not boosting:
		face_opponent()
	# touch down
	if position.y >= Cfg.FLOOR_Y - 1.0 and d.y > 0.3:
		position.y = Cfg.FLOOR_Y
		_land()
	if boosting:
		afterimage_t -= dt
		if afterimage_t <= 0.0:
			afterimage_t = 0.05
			fx().afterimage(self, Color(fx_color, 0.35), 0.22)


# ---------------------------------------------------------------- dash
func start_dash(d: Vector2) -> bool:
	if d == Vector2.ZERO:
		return false
	if is_flier and not on_ground:
		if exhausted or stamina < 4.0:
			return false
		stamina = maxf(0.0, stamina - dash_stamina)
		dash_dir = d.normalized()
		vel = dash_dir * dash_speed
	elif on_ground:
		if d.y < -0.5 and absf(d.x) < 0.5:
			if is_flier:
				if exhausted:
					return false
				takeoff()
				vel.y = -dash_speed * 0.8
				dash_dir = Vector2.UP
				set_state(S.DASH)
				_dash_common()
				return true
			_do_jump(3)
			return true
		if absf(d.x) < 0.5:
			return false
		dash_dir = Vector2(signf(d.x), 0)
		vel = dash_dir * dash_speed
		run_active = true
	else:
		if air_dashes_left <= 0:
			return false
		air_dashes_left -= 1
		if d.y > 0.5 and absf(d.x) < 0.5:
			dash_dir = Vector2.DOWN
			vel = Vector2(vel.x * 0.3, 1600.0)
			fastfall = true
		else:
			dash_dir = Vector2(signf(d.x) if d.x != 0.0 else float(facing), 0)
			vel = dash_dir * air_dash_speed
			vel.y = -40.0
	if absf(dash_dir.x) > 0.1:
		facing = 1 if dash_dir.x > 0 else -1
	set_state(S.DASH)
	_dash_common()
	return true


func _dash_common() -> void:
	dash_t = 0.0
	dash_is_dodge = false
	perfect_used = false
	afterimage_t = 0.0
	snd("dash")
	if on_ground:
		fx().dust(position, 7, -facing, 1.3)
	fx().speed_burst(center_pos(), dash_dir, fx_color)
	arena.petals.impulse(center_pos(), 160.0, dash_dir * 520.0)


func start_dodge(d: Vector2) -> bool:
	if is_flier and not on_ground:
		if exhausted or stamina < 4.0:
			return false
		stamina = maxf(0.0, stamina - dash_stamina * 0.8)
	elif not on_ground:
		if air_dashes_left <= 0:
			return false
		air_dashes_left -= 1
	var dirx := -facing if d == Vector2.ZERO else int(signf(d.x))
	if dirx == 0:
		dirx = -facing
	vel = Vector2(dirx * 720.0, 0.0 if on_ground else -120.0)
	if is_flier and not on_ground and d.y != 0.0:
		vel.y = signf(d.y) * 600.0
	set_state(S.DODGE)
	dash_t = 0.0
	dash_is_dodge = true
	perfect_used = false
	snd("dash", -3, 1.25)
	fx().afterimage(self, Color(fx_color, 0.5), 0.3)
	return true


func dash_iframes() -> bool:
	if state == S.DASH:
		return dash_t < 0.11
	if state == S.DODGE:
		return dash_t < 0.22
	return false


func _st_dash(dt: float) -> void:
	dash_t += dt
	afterimage_t -= dt
	if afterimage_t <= 0.0:
		afterimage_t = 0.03
		fx().afterimage(self, Color(fx_color, 0.45), 0.2)
	# attack out of dash
	if dash_t > 0.05 and (has_buf("light") or has_buf("heavy") or has_buf("q") or has_buf("e") or has_buf("r") or has_buf("f")):
		if _try_actions():
			return
	if dash_t < dash_time:
		if is_flier and not on_ground:
			vel = dash_dir * dash_speed * (1.0 - 0.3 * dash_t / dash_time)
		elif on_ground:
			vel.x = dash_dir.x * dash_speed
		elif dash_dir != Vector2.DOWN:
			vel.y = -20.0
			vel.x = dash_dir.x * air_dash_speed
		return
	# dash finished
	if is_flier and not on_ground:
		set_state(S.FLY)
		if inp.move.length() > 0.3:
			boosting = true
			boost_release = 0.0
			vel = inp.move.normalized() * boost_speed
		else:
			vel *= 0.35
		return
	if on_ground:
		if absf(inp.move.x) > 0.4:
			facing = 1 if inp.move.x > 0 else -1
			vel.x = facing * run_speed
			set_state(S.RUN)
			run_release = 0.0
		else:
			run_active = false
			vel.x *= 0.5
			set_state(S.IDLE)
		return
	vel.x *= 0.65
	set_state(S.AIR)


func _st_dodge(dt: float) -> void:
	dash_t += dt
	vel.x = move_toward(vel.x, 0.0, 2600 * dt)
	if is_flier and not on_ground and not exhausted:
		vel.y = move_toward(vel.y, 0.0, 2600 * dt)
	if dash_t > 0.3:
		go_neutral()


# ---------------------------------------------------------------- guard
func start_parry() -> void:
	set_state(S.PARRY)
	if on_ground:
		vel.x *= 0.3
	elif is_flier and not exhausted:
		vel *= 0.3
	snd("swing_l", -12, 1.6)


func can_hold_guard() -> bool:
	return on_ground or (is_flier and not exhausted and state != S.AIR)


func _st_parry(dt: float) -> void:
	face_opponent()
	vel.x = move_toward(vel.x, 0.0, 3000 * dt)
	if is_flier and not on_ground and not exhausted:
		vel.y = move_toward(vel.y, 0.0, 3000 * dt)
	if state_t > Cfg.PARRY_WINDOW:
		if inp.h("guard") and (on_ground or (is_flier and not exhausted)):
			set_state(S.GUARD)
		elif state_t > Cfg.PARRY_WINDOW + 0.12:
			go_neutral()


func _st_guard(dt: float) -> void:
	face_opponent()
	vel.x = move_toward(vel.x, 0.0, 3000 * dt)
	if is_flier and not on_ground:
		vel.y = move_toward(vel.y, 0.0, 3000 * dt)
		if exhausted:
			set_state(S.AIR)
			return
	if has_buf("dashdir"):
		take("dashdir")
		start_dodge(buffered_dash)
		return
	if has_buf("dodge"):
		take("dodge")
		start_dodge(Vector2.ZERO)
		return
	if not inp.h("guard"):
		go_neutral()
		return
	if has_buf("jump") or has_buf("light") or has_buf("heavy") or has_buf("throw") or has_buf("q") or has_buf("e") or has_buf("r") or has_buf("f"):
		take("guard")
		_try_actions()


func _st_blockstun(dt: float) -> void:
	vel.x = move_toward(vel.x, 0.0, 1800 * dt)
	if is_flier and not on_ground:
		vel.y = move_toward(vel.y, 0.0, 2000 * dt)
	# Just-defend: pressing guard again during blockstun re-arms the parry.
	if has_buf("guard") and state_t > 0.03:
		take("guard")
		start_parry()
		return
	if state_t >= stun_time:
		if inp.h("guard"):
			set_state(S.GUARD)
		else:
			go_neutral()


# ---------------------------------------------------------------- hit states
func _st_hitstun(dt: float) -> void:
	hitstun -= dt
	if on_ground:
		vel.x = move_toward(vel.x, 0.0, 2000 * dt)
	if hitstun <= 0.0:
		if on_ground:
			_combo_reset()
			go_neutral()
		else:
			set_state(S.TUMBLE)


func _st_tumble(_dt: float) -> void:
	if on_ground:
		_combo_reset()
		go_neutral()
		return
	if alive and (inp.p("jump") or inp.p("guard") or inp.p("light") or inp.p("heavy") or inp.dash_dir != Vector2.ZERO or inp.dodge):
		air_recover()


func air_recover() -> void:
	invuln = 0.28
	vel = Vector2(vel.x * 0.25, -520.0)
	_combo_reset()
	jumps_left = mini(jumps_left, 1)
	snd("jump", -2, 1.3)
	fx().ring(center_pos(), Color(1, 1, 1, 0.7), 10, 60, 0.25, 3)
	fx().afterimage(self, Color(fx_color, 0.5), 0.25)
	if is_flier and not exhausted:
		set_state(S.FLY)
	else:
		set_state(S.AIR)


func _st_knockdown(dt: float) -> void:
	vel.x = move_toward(vel.x, 0.0, 2600 * dt)
	if not alive:
		set_state(S.KO)
		return
	if state_t > 0.55:
		set_state(S.GETUP)
		invuln = 0.42
		_combo_reset()
		if absf(inp.move.x) > 0.5:
			vel.x = signf(inp.move.x) * 520.0


func _st_getup(dt: float) -> void:
	vel.x = move_toward(vel.x, 0.0, 1600 * dt)
	if state_t > 0.36:
		face_opponent()
		go_neutral()


func _st_stagger(dt: float) -> void:
	vel.x = move_toward(vel.x, 0.0, 2000 * dt)
	if is_flier and not on_ground:
		vel.y = move_toward(vel.y, 200.0, 800 * dt)
	if state_t >= stun_time:
		if state == S.GUARDBREAK:
			guard_hp = 100.0
		_combo_reset()
		go_neutral()


func _combo_reset() -> void:
	combo_hits = 0
	combo_damage = 0.0
	juggle = 0
	wall_bounced = false
	ground_bounced = false
	knockdown_pending = false
	wall_bounce_pending = false
	ground_bounce_pending = false


# ---------------------------------------------------------------- grab
func _st_grab(_dt: float) -> void:
	vel = Vector2.ZERO
	if grab_partner == null:
		if state_t >= 0.56:
			go_neutral()
		return
	if grab_partner.state != S.GRABBED:
		grab_partner = null
		go_neutral()
		return
	grab_partner.position = position + Vector2(facing * 42.0, 0)
	if state_t >= 0.34:
		var victim := grab_partner
		grab_partner = null
		var back := signf(inp.move.x) == -facing
		if back:
			victim.position.x = clampf(position.x - facing * 40.0, Cfg.WALL_L + 30, Cfg.WALL_R - 30)
		var dir := -facing if back else facing
		victim.state = S.IDLE
		var tm: Dictionary = moves["throw"]
		var hitmv := mv({"name": "throw_hit", "dmg": tm["dmg"], "kb": Vector2(520, 520), "air_kb": Vector2(520, 520),
			"launch": true, "knockdown": true, "hitstun": 0.6, "unblockable": true, "parryable": false,
			"hitstop": 0.12, "shake": 8.0, "hit_sfx": "hit_h", "spark": "heavy", "strength": 2})
		victim.facing = -dir
		arena.resolve_direct_hit(self, victim, hitmv, dir)
		snd("throw")


func begin_grab(victim: Fighter) -> void:
	interrupt_move()
	set_state(S.GRAB)
	grab_partner = victim
	victim.get_grabbed(self)
	snd("hit_m", -2, 0.8)


func _st_grabbed(_dt: float) -> void:
	vel = Vector2.ZERO
	if grab_partner == null or grab_partner.state != S.GRAB:
		if state_t > 0.1:
			go_neutral()
		return
	if grab_break_ok and state_t < 0.26 and (inp.p("throw") or has_buf("throw")):
		take("throw")
		arena.throw_break(grab_partner, self)


func lock_for_ult() -> void:
	interrupt_move()
	set_state(S.LOCKED)
	vel = Vector2.ZERO
	boosting = false


func on_countered(_atk: Fighter, _from_proj: bool) -> void:
	pass


func get_grabbed(by: Fighter) -> void:
	set_state(S.GRABBED)
	grab_partner = by
	grab_break_ok = true
	facing = -by.facing
	vel = Vector2.ZERO
	cur_move = {}


# ================================================================ moves
func start_move(n: String) -> void:
	if not moves.has(n):
		return
	var m: Dictionary = moves[n]
	if not bool(m["no_turn"]):
		face_opponent()
	cur_move = m
	move_name = n
	move_t = 0.0
	move_uid += 1
	move_connected = false
	move_hit_keys.clear()
	move_spawned = false
	move_from_pose = pose.duplicate()
	charging = bool(m["chargeable"]) and inp.h("heavy")
	charge_t = 0.0
	charge_mult = 1.0
	armor_hits = 1 if bool(m["armor"]) else 0
	boosting = false
	if float(m["cost"]) > 0.0:
		ki -= float(m["cost"])
	if m["cd_key"] != "":
		cooldowns[m["cd_key"]] = float(m["cd"])
	if bool(m["ult"]):
		ki = 0.0
	set_state(S.ATTACK)
	if on_ground and not bool(m["keep_momentum"]):
		vel.x *= 0.35
	elif not on_ground and bool(m["hover"]):
		vel *= 0.3
	if m["sfx"] != "" and float(m["startup"]) < 0.12:
		snd(m["sfx"], -2)
	_on_move_start(n, m)


func _on_move_start(_n: String, _m: Dictionary) -> void:
	pass


func move_total(m: Dictionary) -> float:
	return float(m["startup"]) + float(m["active"]) + float(m["recovery"])


func in_active() -> bool:
	if state != S.ATTACK or cur_move.is_empty() or charging:
		return false
	var su: float = cur_move["startup"]
	return move_t >= su and move_t < su + float(cur_move["active"])


func _st_attack(dt: float) -> void:
	var m := cur_move
	if m.is_empty():
		go_neutral()
		return
	var su: float = m["startup"]
	var ac: float = m["active"]
	# heavy charge
	if charging:
		if inp.h("heavy") and charge_t < 0.9 and move_t >= su * 0.85:
			charge_t += dt
			charge_mult = 1.0 + 0.6 * clampf(charge_t / 0.9, 0.0, 1.0)
			vel.x = move_toward(vel.x, 0.0, 3000 * dt)
			if not on_ground and not is_flier:
				vel.y = minf(vel.y, 80.0)
			if int(charge_t * 20.0) != int((charge_t - dt) * 20.0):
				fx().charge_spark(center_pos(), fx_color, charge_t / 0.9)
			if charge_t >= 0.9 and charge_t - dt < 0.9:
				flash_t = 0.1
				flash_color = Color(1, 0.9, 0.5)
				snd("counter", -6, 1.4)
				armor_hits = 1
			if int(charge_t * 4.0) != int((charge_t - dt) * 4.0):
				snd("charge", -10, 0.8 + charge_t * 0.5)
			return
		elif move_t >= su * 0.85:
			charging = false
			if charge_t > 0.05 and m["sfx"] != "":
				snd(m["sfx"], 0, 0.9)
	var prev_t := move_t
	move_t += dt
	# sfx at strike for slower moves
	if float(m["startup"]) >= 0.12 and prev_t < su - 0.06 and move_t >= su - 0.06 and m["sfx"] != "" and charge_t <= 0.05:
		snd(m["sfx"], -1)
	# slash vfx on entering active
	if prev_t <= su and move_t > su:
		_on_active_start(m)
	var sls = m["slash"]
	if sls is Dictionary:
		if not sls.is_empty() and prev_t <= su and move_t > su:
			fx().slash(self, sls)
	elif sls is Array:
		for sl in sls:
			var ts: float = su + float(sl.get("t", 0.0))
			if prev_t <= ts and move_t > ts:
				fx().slash(self, sl)
	# lunge
	var lg: Vector2 = m["lunge"]
	if lg != Vector2.ZERO and move_t >= float(m["lunge_t0"]) and move_t < float(m["lunge_t1"]):
		vel.x = lg.x * facing
		if lg.y != 0.0:
			vel.y = -lg.y
	elif on_ground:
		vel.x = move_toward(vel.x, 0.0, 3200 * dt)
	elif bool(m["hover"]) or (is_flier and not exhausted):
		vel = vel.move_toward(Vector2.ZERO, 1800 * dt)
	# custom spawn
	var st: float = m["spawn_t"]
	if st >= 0.0 and not move_spawned and move_t >= st:
		move_spawned = true
		if m["spawn"] != "":
			call(m["spawn"])
			if state != S.ATTACK or cur_move != m:
				return
	if m["update"] != "":
		call(m["update"], dt)
		if state != S.ATTACK or cur_move != m:
			return
	# cancels
	if _try_cancel():
		return
	if move_t >= move_total(m):
		_end_move()


func _move_landed(_m: Dictionary) -> void:
	pass


func _on_active_start(m: Dictionary) -> void:
	if bool(m["hover"]) == false and not on_ground and float(m["air_stall"]) > 0.0:
		vel.y = minf(vel.y, 60.0)
	arena.petals.impulse(center_pos() + Vector2(facing * 50, 0), 120.0, Vector2(facing * 300, -80))


func _try_cancel() -> bool:
	var m := cur_move
	var su: float = m["startup"]
	var ac: float = m["active"]
	var whiff_ok := move_t >= su + ac
	var hit_ok := move_connected
	if not (whiff_ok or hit_ok):
		# throw input converts a fresh normal into a throw
		if move_t < 0.07 and has_buf("throw") and on_ground and m["kind"] in ["light", "heavy"] and moves.has("throw"):
			take("throw")
			take("light")
			take("heavy")
			start_move("throw")
			return true
		return false
	# ult cancel
	if hit_ok and has_buf("f") and ki >= Cfg.KI_MAX and moves.has("ult") and not bool(m["ult"]):
		take("f")
		start_move("ult")
		return true
	# ability cancel (special cancel)
	if hit_ok and bool(m["cancel_special"]) and m["kind"] in ["light", "heavy"]:
		for k in ["q", "e", "r"]:
			if has_buf(k) and cooldowns[k] <= 0.0 and _ability_ok(k):
				take(k)
				start_move(_ability_move(k))
				return true
	# rush cancel (dash on hit)
	if hit_ok and has_buf("dashdir") and ki >= Cfg.RUSH_CANCEL_COST and m["kind"] in ["light", "heavy", "special"]:
		take("dashdir")
		gain_ki(-Cfg.RUSH_CANCEL_COST)
		fx().ring(center_pos(), Color(fx_color, 0.9), 20, 90, 0.25, 5)
		fx().text(head_pos() + Vector2(0, -30), "RUSH", fx_color, 1)
		_end_move_cleanup()
		if not start_dash(buffered_dash):
			go_neutral()
		return true
	# jump cancel
	if hit_ok and bool(m["jump_cancel"]) and has_buf("jump"):
		_end_move_cleanup()
		if _try_jump():
			take("jump")
			return true
	# chains
	if m["kind"] == "light" and has_buf("light"):
		var nxt := ""
		var up := inp.move.y < -0.5
		var down := inp.move.y > 0.5
		var pre := "air_" if not on_ground else ""
		if bool(m["chain_dir"]) and (up or down):
			var cand := pre + ("up_l" if up else "down_l")
			if moves.has(cand) and cand != move_name:
				nxt = cand
		if nxt == "":
			nxt = m["next"]
		if nxt != "" and moves.has(nxt):
			take("light")
			start_move(nxt)
			return true
	if m["kind"] == "light" and has_buf("heavy"):
		take("heavy")
		start_move(normal_name("heavy"))
		return true
	return false


func _end_move() -> void:
	var m := cur_move
	_end_move_cleanup()
	cur_move = {}
	move_name = ""
	if on_ground and m.get("kind", "") != "":
		if run_active and absf(inp.move.x) > 0.4:
			set_state(S.RUN)
			return
	go_neutral()
	if state == S.IDLE and inp.h("guard"):
		set_state(S.GUARD)


func _end_move_cleanup() -> void:
	charging = false
	armor_hits = 0


func interrupt_move() -> void:
	_end_move_cleanup()
	cur_move = {}
	move_name = ""


func active_hitboxes() -> Array:
	var res := []
	if in_active():
		var m := cur_move
		var idx := 0
		if int(m["hits"]) > 1:
			idx = mini(int((move_t - float(m["startup"])) / float(m["hit_every"])), int(m["hits"]) - 1)
		if not bool(m["throw"]):
			res.append({"rect": box_world(m["box"]), "mv": m, "key": idx})
	_extra_hitboxes(res)
	return res


func _extra_hitboxes(_res: Array) -> void:
	pass


func throw_box() -> Rect2:
	if in_active() and bool(cur_move["throw"]):
		return box_world(cur_move["box"])
	return Rect2()


func throwable() -> bool:
	return alive and on_ground and invuln <= 0.0 and state in [S.IDLE, S.WALK, S.RUN, S.CROUCH, S.GUARD, S.PARRY, S.ATTACK, S.STAGGER, S.DASH] and not dash_iframes()


func on_attack_result(res: int, def: Fighter, m: Dictionary) -> void:
	move_connected = true
	if res == R.HIT:
		gain_ki(float(m["dmg"]) * 0.075 * charge_mult)
		if not on_ground and float(m["air_stall"]) > 0.0:
			vel.y = minf(vel.y, -float(m["air_stall"]))
			if is_flier:
				vel.y = 0.0
	elif res == R.BLOCK:
		gain_ki(2.0)
	if m["on_hit"] != "" and res == R.HIT:
		call(m["on_hit"], def)


func get_parried() -> void:
	interrupt_move()
	set_state(S.STAGGER)
	stun_time = 0.62
	vel = Vector2(-facing * 180.0, 0.0 if on_ground else -120.0)


# ================================================================ receiving
func is_invulnerable(m: Dictionary) -> bool:
	if invuln > 0.0 or not alive:
		return true
	if dash_iframes():
		return true
	match state:
		S.KNOCKDOWN:
			return not bool(m["otg"])
		S.GETUP, S.GRABBED, S.INTRO, S.WIN, S.KO:
			return true
		S.LOCKED:
			return not bool(m["ult_hit"])
		S.ATTACK:
			var iv: Vector2 = cur_move.get("invuln", Vector2(-1, -1))
			if iv.x >= 0.0 and move_t >= iv.x and move_t < iv.y:
				return true
	return false


func counter_ready(_m: Dictionary, _from_proj: bool) -> bool:
	return false


func can_block() -> bool:
	if state == S.GUARD or state == S.BLOCKSTUN:
		return true
	return false


## Returns an R.* result. `dir` is the direction the hit pushes (+1 right).
func receive_hit(atk: Fighter, m: Dictionary, dir: int, from_proj := false, mult := 1.0) -> int:
	if is_invulnerable(m):
		if (state == S.DASH or state == S.DODGE) and dash_t < Cfg.PERFECT_DODGE_WINDOW and not perfect_used and alive:
			perfect_used = true
			arena.on_perfect_dodge(self, atk)
		return R.WHIFF
	if counter_ready(m, from_proj) and not bool(m["unblockable"]):
		return R.COUNTERED
	if state == S.PARRY and state_t <= Cfg.PARRY_WINDOW and bool(m["parryable"]):
		return R.PARRY
	if can_block() and not bool(m["unblockable"]):
		_apply_block(m, dir, mult)
		return R.BLOCK
	if armor_hits > 0 and not bool(m["unblockable"]) and not bool(m["ult_hit"]):
		armor_hits -= 1
		var d := float(m["dmg"]) * mult * 0.5
		hp = maxf(1.0, hp - d)
		flash_t = 0.1
		flash_color = Color(1, 0.8, 0.4)
		return R.ARMOR
	_apply_hit(atk, m, dir, mult)
	return R.HIT


func _apply_block(m: Dictionary, dir: int, mult: float) -> void:
	var chip := float(m["dmg"]) * float(m["chip"]) * mult
	hp = maxf(1.0, hp - chip)
	var gd := float(m["guard_dmg"]) * mult
	if is_flier and not on_ground:
		gd *= 1.5
	guard_hp -= gd
	gain_ki(3.0)
	var kbx: float = Vector2(m["kb"]).x
	vel.x = dir * (kbx * 0.55 + 140.0)
	if guard_hp <= 0.0:
		guard_hp = 0.0
		set_state(S.GUARDBREAK)
		stun_time = 1.05
		vel.x = dir * 260.0
		arena.on_guard_break(self)
	else:
		set_state(S.BLOCKSTUN)
		stun_time = float(m["blockstun"]) * (1.0 + 0.3 * (mult - 1.0))


func _apply_hit(atk: Fighter, m: Dictionary, dir: int, mult: float) -> void:
	var was_air := not on_ground
	var counter := false
	if state == S.ATTACK and not cur_move.is_empty():
		counter = move_t < float(cur_move["startup"]) + float(cur_move["active"])
	elif state == S.STAGGER or (state == S.PARRY and state_t > Cfg.PARRY_WINDOW):
		counter = true
	interrupt_move()
	boosting = false
	combo_hits += 1
	var scale := maxf(0.28, 1.0 - 0.085 * maxf(0.0, combo_hits - 2.0))
	if bool(m["ult_hit"]):
		scale = maxf(scale, 0.55)
	var dmg := float(m["dmg"]) * mult * scale * DAMAGE_SCALE
	if counter:
		dmg *= 1.2
	if is_flier and was_air:
		dmg *= 1.1
	if bool(m["anti_air"]) and was_air:
		dmg *= 1.15
	hp -= dmg
	combo_damage += dmg
	gain_ki(dmg * 0.045)
	last_hit_by_move = m
	# knockback
	var kbm := weight
	if is_flier and was_air:
		kbm *= 1.15
	var launch := bool(m["launch"])
	var kb: Vector2 = m["air_kb"] if (was_air or launch) else m["kb"]
	kb *= kbm * (1.0 + 0.35 * (mult - 1.0))
	if bool(m["kb_along_aim"]) and atk != null:
		var a: Vector2 = atk.vel.normalized() if atk.vel.length() > 10.0 else Vector2(dir, 0)
		vel = a * kb.length()
	else:
		vel.x = kb.x * dir
		if was_air or launch:
			vel.y = -kb.y
			on_ground = on_ground and kb.y <= 0.0
		else:
			vel.y = 0.0
	if vel.y < -1.0:
		on_ground = false
	# hitstun
	var hs := float(m["hitstun"]) * (1.3 if counter else 1.0)
	hs *= maxf(0.5, 1.0 - 0.035 * (combo_hits - 1))
	if not on_ground:
		juggle += 1
		hs *= maxf(0.45, 1.0 - 0.055 * juggle)
	hitstun = hs
	knockdown_pending = knockdown_pending or bool(m["knockdown"]) or launch
	if bool(m["wall_bounce"]) and not wall_bounced:
		wall_bounce_pending = true
	if bool(m["ground_bounce"]) and not ground_bounced:
		ground_bounce_pending = true
	if hp <= 0.0:
		hp = 0.0
		alive = false
		knockdown_pending = true
		if on_ground:
			vel = Vector2(dir * 520.0, -700.0)
			on_ground = false
	facing = -dir if dir != 0 else facing
	flash_t = 0.07
	flash_color = Color.WHITE
	tumble_rot = 0.0
	set_state(S.HITSTUN)
	if counter:
		arena.on_counter_hit(atk, self)
	# combo limit: automatic burst out of absurdly long combos
	if combo_hits >= 32 and alive:
		hitstun = 0.05
		invuln = 0.6


# ================================================================ physics
func uses_gravity() -> bool:
	if on_ground:
		return false
	match state:
		S.FLY, S.GRAB, S.GRABBED, S.LOCKED, S.WALL:
			return false
		S.DASH:
			return not (is_flier and dash_t < dash_time) and dash_dir == Vector2.DOWN
		S.DODGE, S.PARRY, S.GUARD, S.BLOCKSTUN:
			return not is_flier or exhausted
		S.STAGGER, S.GUARDBREAK:
			return not is_flier or exhausted or state == S.GUARDBREAK
		S.ATTACK:
			if is_flier:
				if not exhausted:
					return false
			elif bool(cur_move.get("hover", false)):
				return false
			if charging:
				return false
			var lg: Vector2 = cur_move["lunge"]
			if lg.y != 0.0 and move_t >= float(cur_move["lunge_t0"]) and move_t < float(cur_move["lunge_t1"]):
				return false
	return true


func _physics(dt: float) -> void:
	if uses_gravity():
		var g := gravity
		if vel.y > 0.0:
			g *= fall_mult
		if state in [S.HITSTUN, S.TUMBLE]:
			g *= 1.0 + 0.05 * juggle
		if fastfall and state == S.AIR:
			g *= 1.9
		var mf := max_fall * (1.45 if fastfall else 1.0)
		vel.y = minf(vel.y + g * dt, mf)
	elif state == S.ATTACK and is_flier and not exhausted and not on_ground:
		pass
	position += vel * dt
	# floor
	if position.y >= Cfg.FLOOR_Y:
		position.y = Cfg.FLOOR_Y
		if not on_ground:
			var impact := vel.y
			on_ground = true
			_on_land(impact)
		if vel.y > 0.0:
			vel.y = 0.0
	elif on_ground:
		if position.y < Cfg.FLOOR_Y - 0.5:
			on_ground = false
	# ceiling
	var top := position.y - body_h * PX
	if top < Cfg.CEIL_Y:
		position.y = Cfg.CEIL_Y + body_h * PX
		if vel.y < 0.0:
			if state in [S.HITSTUN, S.TUMBLE] and vel.y < -500.0:
				vel.y = -vel.y * 0.35
				arena.on_barrier_hit(Vector2(position.x, Cfg.CEIL_Y), Vector2.DOWN, 1.0)
			else:
				if vel.y < -600.0:
					arena.on_barrier_hit(Vector2(position.x, Cfg.CEIL_Y), Vector2.DOWN, 0.4)
				vel.y = 0.0
	# walls
	var hw := body_w * PX * 0.5
	wall_side = 0
	if position.x - hw <= Cfg.WALL_L:
		position.x = Cfg.WALL_L + hw
		wall_side = -1
		_on_wall(-1)
	elif position.x + hw >= Cfg.WALL_R:
		position.x = Cfg.WALL_R - hw
		wall_side = 1
		_on_wall(1)


func _on_wall(side: int) -> void:
	if state in [S.HITSTUN, S.TUMBLE] and wall_bounce_pending and absf(vel.x) > 250.0 and signf(vel.x) == side:
		wall_bounce_pending = false
		wall_bounced = true
		vel.x = -vel.x * 0.42
		vel.y = minf(vel.y, -520.0)
		hitstun = maxf(hitstun, 0.5)
		on_ground = false
		arena.on_barrier_hit(Vector2(position.x + side * body_w * PX * 0.5, center_pos().y), Vector2(-side, 0), 1.0)
		snd("wall")
		return
	if signf(vel.x) == side:
		if state in [S.HITSTUN, S.TUMBLE] and absf(vel.x) > 700.0:
			arena.on_barrier_hit(Vector2(position.x + side * body_w * PX * 0.5, center_pos().y), Vector2(-side, 0), 0.5)
		vel.x = 0.0


func _land() -> void:
	on_ground = true
	vel.y = 0.0
	_on_land(0.0)


func _on_land(impact: float) -> void:
	fastfall = false
	jumps_left = extra_jumps
	air_dashes_left = air_dashes_max
	jump_cut = false
	match state:
		S.HITSTUN, S.TUMBLE:
			if ground_bounce_pending:
				ground_bounce_pending = false
				ground_bounced = true
				vel.y = -maxf(700.0, absf(impact) * 0.55)
				vel.x *= 0.6
				on_ground = false
				hitstun = maxf(hitstun, 0.45)
				set_state(S.HITSTUN)
				arena.on_ground_bounce(self)
				return
			if knockdown_pending or not alive:
				var tech: bool = alive and (clock - last_press["guard"] < 0.25 or clock - last_press["jump"] < 0.25)
				if tech and combo_hits < 30:
					_tech_roll()
				else:
					_knockdown(impact)
				return
			if state == S.TUMBLE:
				_combo_reset()
				go_neutral()
			fx().dust(position, 5, 0, 1.0)
		S.ATTACK:
			if bool(cur_move.get("end_on_land", true)) and bool(cur_move.get("air", false)) and not bool(cur_move.get("hover", false)):
				var lag: float = cur_move.get("landing_lag", 0.06)
				_move_landed(cur_move)
				interrupt_move()
				set_state(S.IDLE)
				landing_lag = lag
				squash = 0.8
				fx().dust(position, 6, 0, 1.0)
				snd("land", -6)
		S.AIR, S.WALL, S.DODGE:
			squash = 0.78 if impact > 900.0 else 0.88
			fx().dust(position, 8 if impact > 1100.0 else 4, 0, 1.2 if impact > 1100.0 else 0.8)
			snd("land", -3 if impact > 900.0 else -9)
			if impact > 1300.0:
				arena.petals.impulse(position, 180.0, Vector2(0, -300))
				arena.cam_shake(2.0)
			if run_active and absf(inp.move.x) > 0.4:
				facing = 1 if inp.move.x > 0 else -1
				set_state(S.RUN)
			else:
				run_active = false
				go_neutral()
		S.FLY:
			squash = 0.9
			fx().dust(position, 4, 0, 0.8)
			snd("land", -9)
			boosting = false
			go_neutral()
		S.DASH:
			if not is_flier:
				pass
			elif dash_dir.y > 0.3:
				fx().dust(position, 6, 0, 1.0)
				set_state(S.IDLE)
		S.STAGGER, S.GUARDBREAK, S.BLOCKSTUN, S.GUARD, S.PARRY:
			pass
		_:
			pass


func _knockdown(impact: float) -> void:
	set_state(S.KNOCKDOWN)
	vel.x *= 0.5
	squash = 0.85
	fx().dust(position, 12, 0, 1.6)
	arena.petals.impulse(position, 200.0, Vector2(0, -380))
	snd("land", 0, 0.8)
	if absf(impact) > 900.0:
		arena.cam_shake(4.0)
	if not alive:
		set_state(S.KO)
		emit_signal("ko")


func _tech_roll() -> void:
	_combo_reset()
	set_state(S.GETUP)
	invuln = 0.4
	var d := signf(inp.move.x) if absf(inp.move.x) > 0.4 else float(-facing)
	vel = Vector2(d * 560.0, 0)
	fx().text(head_pos() + Vector2(0, -10), "ТЕХ!", Color(0.8, 1, 0.9), 1)
	fx().dust(position, 6, -d, 1.0)
	snd("dash", -4, 1.2)


# ================================================================ animation
func neutral_pose() -> Dictionary:
	if on_ground:
		return P["idle"]
	if is_flier and not exhausted:
		return P.get("fly", P["idle"])
	return P["fall"]


func _pose_idle() -> Dictionary:
	var p: Dictionary = P["idle"].duplicate()
	var b := sin(anim_t * 3.2)
	p["hy"] += 0.6 + b * 0.6
	p["tor"] += b * 0.02
	p["uf"] += b * 0.04
	p["ub"] -= b * 0.04
	return p


func _pose_walk(back: bool) -> Dictionary:
	var p: Dictionary = P["idle"].duplicate()
	var a := walk_phase * (-1.0 if back else 1.0)
	var s := 5.0
	var lift := 3.0
	p["flx"] = 2.0 + s * sin(a)
	p["fly"] = -lift * maxf(0.0, cos(a))
	p["blx"] = -2.0 + s * sin(a + PI)
	p["bly"] = -lift * maxf(0.0, cos(a + PI))
	p["hy"] += 1.2 + 0.8 * absf(sin(a))
	p["uf"] += 0.3 * sin(a + PI)
	p["ub"] += 0.3 * sin(a)
	return p


func _pose_run() -> Dictionary:
	var p: Dictionary = P.get("run", P["idle"]).duplicate()
	var a := walk_phase
	var s := 8.0
	var lift := 6.0
	p["ik"] = 1.0
	p["flx"] = 3.0 + s * sin(a)
	p["fly"] = -lift * maxf(0.0, cos(a))
	p["blx"] = -1.0 + s * sin(a + PI)
	p["bly"] = -lift * maxf(0.0, cos(a + PI))
	p["hy"] += 2.5 + 1.5 * absf(sin(a))
	return p


func _pose_air() -> Dictionary:
	var k := clampf((vel.y + 300.0) / 800.0, 0.0, 1.0)
	return Pose.blend(P["jump"], P["fall"], k)


func _pose_fly() -> Dictionary:
	return P.get("fly", P["fall"])


func _target_pose() -> Dictionary:
	match state:
		S.IDLE, S.INTRO:
			if state == S.INTRO and P.has("intro"):
				return P["intro"]
			return _pose_idle()
		S.WALK:
			var back := signf(vel.x) != float(facing) and absf(vel.x) > 20.0
			return _pose_walk(back)
		S.RUN:
			return _pose_run()
		S.CROUCH:
			return P["crouch"]
		S.AIR, S.WALL:
			if state == S.WALL and P.has("wall"):
				return P["wall"]
			return _pose_air()
		S.FLY:
			return _pose_fly()
		S.DASH:
			if not on_ground and P.has("airdash"):
				return P["airdash"]
			return P["dash"]
		S.DODGE:
			return P.get("dodge", P["dash"])
		S.ATTACK:
			return _attack_pose()
		S.GUARD, S.BLOCKSTUN:
			return P["guard"]
		S.PARRY:
			return P.get("parry", P["guard"])
		S.HITSTUN, S.LOCKED, S.GRABBED:
			return P["hit"] if on_ground else P["hit_air"]
		S.TUMBLE:
			return P["tumble"]
		S.KNOCKDOWN, S.KO:
			return P["down"]
		S.GETUP:
			return Pose.blend(P["down"], P["crouch"], Pose.ease_out(state_t / 0.3))
		S.STAGGER, S.GUARDBREAK:
			var p: Dictionary = P["hit"].duplicate()
			p["tor"] += sin(anim_t * 9.0) * 0.12
			p["hd"] += sin(anim_t * 9.0 + 1.0) * 0.2
			return p
		S.GRAB:
			return P.get("grab", P["idle"])
		S.WIN:
			return P.get("win", P["idle"])
	return P["idle"]


func _attack_pose() -> Dictionary:
	var m := cur_move
	if m.is_empty():
		return P["idle"]
	if m["pose_fn"] != "":
		return call(m["pose_fn"])
	var names: Array = m["poses"]
	if names.is_empty():
		return P["idle"]
	var windup: Dictionary = P[names[0]]
	var strikes: Array = []
	if names.size() == 1:
		strikes = [windup]
	elif names.size() == 2:
		strikes = [P[names[1]]]
	else:
		for i in range(1, names.size() - 1):
			strikes.append(P[names[i]])
	var follow: Dictionary = P[names[names.size() - 1]] if names.size() >= 3 else strikes[strikes.size() - 1]
	var su: float = m["startup"]
	var ac: float = m["active"]
	var rc: float = m["recovery"]
	var t := move_t
	if charging:
		var p: Dictionary = windup.duplicate()
		p["hx"] += sin(anim_t * 60.0) * 0.5 * clampf(charge_t / 0.9, 0.0, 1.0)
		return p
	if t < su:
		return Pose.blend(move_from_pose, windup, Pose.ease_out(t / maxf(su, 0.001), 2.0))
	if t < su + ac:
		var k := (t - su) / maxf(ac, 0.001)
		var n := strikes.size()
		var i := mini(int(k * n), n - 1)
		var from: Dictionary = windup if i == 0 else strikes[i - 1]
		var lk := k * n - i
		return Pose.blend(from, strikes[i], Pose.ease_out(lk * 1.8, 3.0))
	var kr := (t - su - ac) / maxf(rc, 0.001)
	var last: Dictionary = strikes[strikes.size() - 1]
	var p2 := Pose.blend(last, follow, Pose.ease_out(kr * 1.6, 2.0))
	if kr > 0.6:
		p2 = Pose.blend(p2, neutral_pose(), Pose.ease_in_out((kr - 0.6) / 0.4))
	return p2


func _update_anim(dt: float) -> void:
	var target := _target_pose()
	var rate := 26.0
	if state == S.ATTACK:
		rate = 60.0
	elif state in [S.HITSTUN, S.DASH, S.PARRY]:
		rate = 45.0
	if state == S.TUMBLE or (state == S.HITSTUN and not on_ground and knockdown_pending):
		tumble_rot += dt * clampf(vel.length() / 60.0, 4.0, 16.0) * -1.0
		target = target.duplicate()
		target["rot"] = tumble_rot
		pose["rot"] = tumble_rot
	elif flip_t > 0.0 and state == S.AIR:
		flip_t -= dt
		var k := 1.0 - clampf(flip_t / 0.34, 0.0, 1.0)
		target = target.duplicate()
		target["rot"] = TAU * Pose.ease_in_out(k)
		target["tf"] = 1.6
		target["sf"] = -0.6
		target["tb"] = 1.3
		target["sb"] = -0.8
		target["ik"] = 0.0
		pose["rot"] = target["rot"]
		if flip_t <= 0.0:
			pose["rot"] = 0.0
	else:
		flip_t = 0.0
		pose["rot"] = wrapf(pose.get("rot", 0.0), -PI, PI)
		tumble_rot = 0.0
	Pose.blend_into(pose, target, 1.0 - exp(-dt * rate))
	joints = compute_joints(pose)


func compute_joints(p: Dictionary) -> Dictionary:
	var j := {}
	var hip := Vector2(p["hx"], -HIP_H + p["hy"])
	var tor: float = p["tor"]
	var td := Vector2(sin(tor), -cos(tor))
	var neck := hip + td * TORSO
	var hdir := Vector2(sin(tor + p["hd"]), -cos(tor + p["hd"]))
	var head := neck + hdir * (NECK + HEAD_R)
	var sh := neck - td * SH_DROP
	var tf: float = p["tf"]
	var sf: float = p["sf"]
	var tb: float = p["tb"]
	var sb: float = p["sb"]
	if p["ik"] > 0.5:
		var a := Pose.ik2(hip, Vector2(p["flx"], p["fly"]), THIGH, SHIN)
		tf = a.x
		sf = a.y
		var b := Pose.ik2(hip, Vector2(p["blx"], p["bly"]), THIGH, SHIN)
		tb = b.x
		sb = b.y
	var kf := hip + Pose.dir(tf) * THIGH
	var ff := kf + Pose.dir(sf) * SHIN
	var kb := hip + Pose.dir(tb) * THIGH
	var fb := kb + Pose.dir(sb) * SHIN
	var ef := sh + Pose.dir(p["uf"]) * UARM
	var hf := ef + Pose.dir(p["lf"]) * LARM
	var eb := sh + Pose.dir(p["ub"]) * UARM
	var hb := eb + Pose.dir(p["lb"]) * LARM
	j["hip"] = hip
	j["neck"] = neck
	j["head"] = head
	j["sh"] = sh
	j["kf"] = kf
	j["ff"] = ff
	j["kb"] = kb
	j["fb"] = fb
	j["ef"] = ef
	j["hf"] = hf
	j["eb"] = eb
	j["hb"] = hb
	j["tf"] = tf
	j["sf"] = sf
	j["tb"] = tb
	j["sb"] = sb
	j["tor"] = tor
	j["hdang"] = tor + p["hd"]
	var rot: float = p["rot"]
	var sq: float = p["sq"] * squash
	if absf(rot) > 0.001 or absf(sq - 1.0) > 0.001:
		var pivot := hip
		var sx := 1.0 / sqrt(maxf(sq, 0.2))
		for k in ["hip", "neck", "head", "sh", "kf", "ff", "kb", "fb", "ef", "hf", "eb", "hb"]:
			var v: Vector2 = j[k]
			if absf(rot) > 0.001:
				v = pivot + (v - pivot).rotated(rot)
			v = Vector2(v.x * sx, v.y * sq)
			j[k] = v
		j["rot"] = rot
	else:
		j["rot"] = 0.0
	return j


# ================================================================ secondary motion
class Chain:
	extends RefCounted
	var pts: PackedVector2Array = PackedVector2Array()
	var prev: PackedVector2Array = PackedVector2Array()
	var seg := 6.0
	var grav := 900.0
	var damp := 0.9
	var anchor_key := "neck"
	var anchor_off := Vector2.ZERO
	var width := 2.0
	var width_end := 1.0

	func _init(n: int, p_seg: float) -> void:
		seg = p_seg
		pts.resize(n)
		prev.resize(n)

	func reset(at: Vector2) -> void:
		for i in pts.size():
			pts[i] = at + Vector2(0, i * seg)
			prev[i] = pts[i]

	func step(anchor: Vector2, dt: float, wind: Vector2) -> void:
		if pts.size() == 0:
			return
		pts[0] = anchor
		prev[0] = anchor
		var acc := Vector2(wind.x, grav + wind.y)
		for i in range(1, pts.size()):
			var cur := pts[i]
			var v := (cur - prev[i]) * damp
			prev[i] = cur
			pts[i] = cur + v + acc * dt * dt
		for _it in 3:
			for i in range(1, pts.size()):
				var a := pts[i - 1]
				var b := pts[i]
				var d := b - a
				var l := d.length()
				if l > 0.0001:
					pts[i] = a + d * (seg / l)


func _update_chains(dt: float) -> void:
	if chains.is_empty():
		return
	var wind := Vector2(-vel.x * 0.8 - facing * 150.0 + sin(clock * 1.7) * 90.0 - 40.0, -vel.y * 0.3 - 60.0)
	for c in chains:
		var jp: Vector2 = joints.get(c.anchor_key, Vector2.ZERO)
		var anchor := local_to_world(jp + c.anchor_off)
		if c.pts.size() > 0 and c.pts[0].distance_to(anchor) > 200.0:
			c.reset(anchor)
		c.step(anchor, dt, wind)


func chain_local(c) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in c.pts:
		var d: Vector2 = (p - position - shake_off) / PX
		out.append(Vector2(d.x * facing, d.y))
	return out


# ================================================================ drawing
func _draw() -> void:
	if vanished:
		return
	draw_set_transform(shake_off, 0.0, Vector2(PX * facing, PX))
	var use_sil := flash_t > 0.0
	draw_body(self, pose, joints, flash_color, use_sil)


## Shape group drawing: prims is an Array of [type, ...] entries.
##   ["cap", a, b, w0, w1]  tapered capsule
##   ["poly", PackedVector2Array]
##   ["circ", c, r]
## Drawn with a 1px inner outline (line colour) then the fill.
func draw_group(ci: CanvasItem, prims: Array, fill: Color, line: Color, sil: Color, use_sil: bool) -> void:
	if use_sil:
		fill = sil
		line = sil
		if sil.a < 0.99:
			_draw_prims(ci, prims, sil, Vector2.ZERO)
			return
	for off in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
		_draw_prims(ci, prims, line, off)
	_draw_prims(ci, prims, fill, Vector2.ZERO)


func _draw_prims(ci: CanvasItem, prims: Array, col: Color, off: Vector2) -> void:
	for pr in prims:
		match pr[0]:
			"cap":
				draw_cap(ci, pr[1] + off, pr[2] + off, pr[3], pr[4], col)
			"poly":
				var pts: PackedVector2Array = pr[1]
				if off != Vector2.ZERO:
					var moved := PackedVector2Array()
					for p in pts:
						moved.append(p + off)
					pts = moved
				safe_poly(ci, pts, col)
			"circ":
				ci.draw_circle(pr[1] + off, pr[2], col)


func draw_cap(ci: CanvasItem, a: Vector2, b: Vector2, w0: float, w1: float, col: Color) -> void:
	var d := b - a
	var l := d.length()
	if l > 0.01:
		var n := Vector2(-d.y, d.x) / l
		var pts := PackedVector2Array([a + n * w0 * 0.5, b + n * w1 * 0.5, b - n * w1 * 0.5, a - n * w0 * 0.5])
		ci.draw_colored_polygon(pts, col)
	ci.draw_circle(a, w0 * 0.5, col)
	ci.draw_circle(b, w1 * 0.5, col)


func safe_poly(ci: CanvasItem, pts: PackedVector2Array, col: Color) -> void:
	if pts.size() < 3:
		return
	# reject degenerate polygons (triangulation would fail)
	var area := 0.0
	for i in pts.size():
		var p1 := pts[i]
		var p2 := pts[(i + 1) % pts.size()]
		area += p1.x * p2.y - p2.x * p1.y
	if absf(area) < 0.05:
		return
	if Geometry2D.triangulate_polygon(pts).is_empty():
		ci.draw_polyline(pts, col, 1.0)
		return
	ci.draw_colored_polygon(pts, col)


func draw_chain(ci: CanvasItem, c, col: Color, line: Color, sil: Color, use_sil: bool) -> void:
	if ghost_draw or c == null:
		return
	var pts := chain_local(c)
	if pts.size() < 2:
		return
	var prims := []
	for i in range(pts.size() - 1):
		var t := float(i) / float(pts.size() - 1)
		var w0: float = lerpf(c.width, c.width_end, t)
		var w1: float = lerpf(c.width, c.width_end, t + 1.0 / float(pts.size() - 1))
		prims.append(["cap", pts[i], pts[i + 1], w0, w1])
	draw_group(ci, prims, col, line, sil, use_sil)
