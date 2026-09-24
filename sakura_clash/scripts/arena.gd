class_name Arena
extends Node2D
## The fight: builds the layered pixel renderer, spawns fighters, runs rounds,
## resolves hits, drives the dynamic camera and global effects
## (hitstop, slow motion, super freeze, flashes).

const PX := Cfg.PX
const VIEW := Vector2(1280, 720)
const ZOOM_MIN := 0.7656
const ZOOM_MAX := 1.14

var demo := false  # attract mode behind menus

var fighters: Array = []
var projectiles: Array = []
var fx: FX
var petals: Petals.Field
var hud: HUD
var cam: Camera2D
var bg: Sprite2D
var bg_mat: ShaderMaterial
var glows: Node2D
var world_vp: SubViewport
var actors_vp: SubViewport
var actors_root: Node2D
var back_root: Node2D
var front_root: Node2D

var round_num := 1
var wins := [0, 0]
var timer := Cfg.ROUND_TIME
var phase := "intro"
var phase_t := 0.0
var announced := 0
var ko_loser: Fighter = null
var match_winner := -1

var freeze_t := 0.0
var freeze_user: Fighter = null
var slow_t := 0.0
var slow_scale := 1.0
var slow_exempt: Fighter = null
var shake := 0.0
var punch := 0.0
var cam_zoom := 0.9
var cam_pos := Vector2(836, 520)
var darken := 0.0
var darken_target := 0.0
var paused := false
var clock := 0.0
var wind := -40.0
var training_idle := 0.0
var dummy_mode := 0


# ================================================================ build
func _ready() -> void:
	_build_world()
	_spawn_fighters()
	_start_round()
	Sfx.quiet = demo
	Sfx.set_muffled(demo)
	Sfx.play_music()


func _build_world() -> void:
	bg = Sprite2D.new()
	bg.texture = load("res://assets/bg/arena.webp")
	bg.centered = false
	bg.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	bg_mat = ShaderMaterial.new()
	bg_mat.shader = load("res://shaders/background.gdshader")
	bg.material = bg_mat
	add_child(bg)

	glows = Glows.new()
	glows.arena = self
	add_child(glows)

	world_vp = _make_vp()
	add_child(world_vp)
	actors_vp = _make_vp()
	world_vp.add_child(actors_vp)

	fx = FX.new()
	fx.arena = self
	petals = Petals.Field.new()

	back_root = Node2D.new()
	back_root.scale = Vector2.ONE / PX
	world_vp.add_child(back_root)
	var pb := Petals.new()
	pb.setup(0, 90)
	back_root.add_child(pb)
	back_root.add_child(fx.make_back())

	var actors_sprite := Sprite2D.new()
	actors_sprite.texture = actors_vp.get_texture()
	actors_sprite.centered = false
	actors_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var om := ShaderMaterial.new()
	om.shader = load("res://shaders/actor_outline.gdshader")
	actors_sprite.material = om
	world_vp.add_child(actors_sprite)

	actors_root = Node2D.new()
	actors_root.scale = Vector2.ONE / PX
	actors_vp.add_child(actors_root)

	front_root = Node2D.new()
	front_root.scale = Vector2.ONE / PX
	world_vp.add_child(front_root)
	front_root.add_child(fx)
	var pf := Petals.new()
	pf.setup(1, 45)
	front_root.add_child(pf)
	var pg := Petals.new()
	pg.setup(2, 9)
	front_root.add_child(pg)
	petals.layers = [pb, pf, pg]

	var ws := Sprite2D.new()
	ws.texture = world_vp.get_texture()
	ws.centered = false
	ws.scale = Vector2(PX, PX)
	ws.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var sm := ShaderMaterial.new()
	sm.shader = load("res://shaders/pixel_sharp.gdshader")
	ws.material = sm
	add_child(ws)

	cam = Camera2D.new()
	cam.position = cam_pos
	add_child(cam)
	cam.make_current()

	hud = HUD.new()
	hud.arena = self
	hud.demo = demo
	add_child(hud)


func _make_vp() -> SubViewport:
	var vp := SubViewport.new()
	vp.size = Vector2i(Cfg.PV_W, Cfg.PV_H)
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	vp.snap_2d_transforms_to_pixel = true
	vp.disable_3d = true
	return vp


func _spawn_fighters() -> void:
	var ids := [Game.p1_char, Game.p2_char]
	var mode: int = Game.mode
	if demo:
		ids = ["ronin", "tengu"] if randf() < 0.5 else ["tengu", "ronin"]
		mode = Game.Mode.CPU_VS_CPU
	var ctrls: Array = []
	match mode:
		Game.Mode.VS_CPU:
			ctrls = [HumanController.new(["p1", "pad"], true), AIController.new(Game.cpu_level)]
		Game.Mode.VS_PLAYER:
			ctrls = [HumanController.new(["p1"], true), HumanController.new(["p2", "pad"], false)]
		Game.Mode.TRAINING:
			ctrls = [HumanController.new(["p1", "pad"], true), AIController.new(1)]
			ctrls[1].dummy = 1
			dummy_mode = 1
		_:
			ctrls = [AIController.new(randi_range(1, 2)), AIController.new(randi_range(1, 2))]
	for i in 2:
		var info: Dictionary = Game.char_info(ids[i])
		var script: Script = load(info["script"])
		var f: Fighter = script.new()
		f.setup(self, i, ctrls[i], i == 1 and ids[0] == ids[1])
		fighters.append(f)
		actors_root.add_child(f)
	fighters[0].opponent = fighters[1]
	fighters[1].opponent = fighters[0]
	for i in 2:
		fighters[i].ko.connect(_on_fighter_ko.bind(fighters[i]))
		if ctrls[i] is AIController:
			ctrls[i].attach(fighters[i], self)


func is_training() -> bool:
	return Game.mode == Game.Mode.TRAINING and not demo


# ================================================================ rounds
func _start_round() -> void:
	phase = "intro"
	phase_t = 0.0
	announced = 0
	timer = Cfg.ROUND_TIME
	ko_loser = null
	freeze_t = 0.0
	slow_t = 0.0
	slow_scale = 1.0
	darken_target = 0.0
	for p in projectiles:
		if is_instance_valid(p):
			p.queue_free()
	projectiles.clear()
	fighters[0].reset_for_round(560.0, 1)
	fighters[1].reset_for_round(1112.0, -1)
	for f in fighters:
		f.input_enabled = false
	cam_pos = Vector2(836, 560)
	if hud != null:
		hud.on_round_start()


func _update_round(dt: float) -> void:
	phase_t += dt
	match phase:
		"intro":
			var t_ann := 0.35 if not demo else 0.1
			if announced == 0 and phase_t > t_ann:
				announced = 1
				if not demo:
					hud.announce("РАУНД %d" % round_num if not is_training() else "ТРЕНИРОВКА", Color(1, 0.9, 0.95), 1.1)
					Sfx.play("round")
			if announced == 1 and phase_t > (1.45 if not demo else 0.4):
				announced = 2
				if not demo:
					hud.announce("БОЙ!", Color(1, 0.55, 0.7), 0.9, true)
					Sfx.play("fight")
				for f in fighters:
					f.input_enabled = true
					f.set_state(Fighter.S.IDLE)
				phase = "fight"
				phase_t = 0.0
		"fight":
			if is_training():
				_training_tick(dt)
			elif not demo:
				timer -= dt
				if timer <= 0.0:
					timer = 0.0
					_time_over()
		"ko":
			if ko_loser != null and phase_t > 1.3 and (ko_loser.state == Fighter.S.KO or phase_t > 4.0):
				_round_end()
		"timeup":
			if phase_t > 1.6:
				_round_end()
		"roundend":
			if phase_t > (2.8 if not demo else 1.5):
				if demo:
					wins = [0, 0]
					round_num = 1
					_start_round()
					return
				if wins[0] >= Cfg.ROUNDS_TO_WIN or wins[1] >= Cfg.ROUNDS_TO_WIN:
					_match_end()
				else:
					round_num += 1
					_start_round()
		"matchend":
			if Game.autotest and phase_t > 2.0:
				wins = [0, 0]
				round_num = 1
				_start_round()


func on_ko_hit(loser: Fighter, killer: Fighter) -> void:
	if phase != "fight":
		return
	phase = "ko"
	phase_t = 0.0
	ko_loser = loser
	var both_dead := not killer.alive
	if not both_dead:
		wins[killer.player_idx] += 1
	for f in fighters:
		f.input_enabled = false
	slowmo(0.25, 1.1)
	screen_flash(Color(1, 1, 1), 0.3)
	cam_punch(0.15)
	cam_shake(10.0)
	Sfx.play("ko")
	if not demo:
		hud.announce("K.O." if not both_dead else "ДВОЙНОЙ K.O.", Color(1, 0.3, 0.4), 1.6, true)


func _time_over() -> void:
	phase = "timeup"
	phase_t = 0.0
	for f in fighters:
		f.input_enabled = false
	var r0: float = fighters[0].hp_ratio()
	var r1: float = fighters[1].hp_ratio()
	if absf(r0 - r1) > 0.001:
		var w := 0 if r0 > r1 else 1
		wins[w] += 1
		ko_loser = fighters[1 - w]
	hud.announce("ВРЕМЯ ВЫШЛО", Color(1, 0.85, 0.5), 1.4, true)
	Sfx.play("ko", -4)


func _round_end() -> void:
	phase = "roundend"
	phase_t = 0.0
	slow_t = 0.0
	slow_scale = 1.0
	var winner: Fighter = null
	if ko_loser != null:
		winner = ko_loser.opponent
	if winner != null and winner.alive:
		if winner.on_ground and winner.state in [Fighter.S.IDLE, Fighter.S.WALK, Fighter.S.RUN, Fighter.S.CROUCH, Fighter.S.GUARD, Fighter.S.ATTACK, Fighter.S.FLY]:
			winner.interrupt_move()
			winner.set_state(Fighter.S.WIN)
		elif winner.is_flier and winner.state in [Fighter.S.FLY, Fighter.S.ATTACK, Fighter.S.IDLE]:
			winner.interrupt_move()
			winner.set_state(Fighter.S.WIN)
		if not demo:
			hud.announce("%s ПОБЕЖДАЕТ" % winner.display_name, winner.fx_color, 2.2)
	elif not demo:
		hud.announce("НИЧЬЯ", Color(0.9, 0.9, 1), 2.0)


func _match_end() -> void:
	phase = "matchend"
	phase_t = 0.0
	match_winner = 0 if wins[0] > wins[1] else 1
	hud.show_results(match_winner)


func _on_fighter_ko(_f: Fighter) -> void:
	cam_shake(6.0)


func _training_tick(dt: float) -> void:
	var d: Fighter = fighters[1]
	var p: Fighter = fighters[0]
	for f in fighters:
		f.gain_ki(10.0 * dt)
	if d.combo_hits > 0 or d.state in [Fighter.S.HITSTUN, Fighter.S.TUMBLE, Fighter.S.KNOCKDOWN, Fighter.S.GETUP]:
		training_idle = 0.0
	else:
		training_idle += dt
	if training_idle > 1.0:
		d.hp = move_toward(d.hp, d.max_hp, d.max_hp * 2.0 * dt)
		p.hp = move_toward(p.hp, p.max_hp, p.max_hp * 2.0 * dt)
	if d.hp <= 1.0:
		d.hp = 1.0
	if p.hp <= 1.0:
		p.hp = 1.0
	d.alive = true
	p.alive = true


func set_dummy_mode(m: int) -> void:
	dummy_mode = m
	var c = fighters[1].controller
	if c is AIController:
		c.dummy = m
	var names := ["ИИ сражается", "Манекен стоит", "Манекен блокирует", "Манекен прыгает"]
	hud.side_text(1, names[m], Color(0.8, 0.9, 1))


# ================================================================ main loop
func _physics_process(delta: float) -> void:
	if paused:
		return
	clock += delta
	darken = move_toward(darken, darken_target, delta * 3.0)
	bg_mat.set_shader_parameter("darken", darken)
	bg_mat.set_shader_parameter("blur_dim", 0.35 if demo else 0.0)
	wind = -40.0 + sin(clock * 0.35) * 30.0 + sin(clock * 1.3) * 10.0
	if freeze_t > 0.0:
		freeze_t -= delta
		fx.tick(delta * 0.25)
		petals.tick(delta * 0.3, wind, cam_pos)
		if freeze_t <= 0.0:
			darken_target = 0.0
			freeze_user = null
		_update_camera(delta)
		hud.tick(delta)
		return
	if slow_t > 0.0:
		slow_t -= delta
		if slow_t <= 0.0:
			slow_scale = 1.0
			slow_exempt = null
	var gdt := delta * slow_scale
	for f in fighters:
		var fdt := delta if (f == slow_exempt and slow_t > 0.0) else gdt
		f.tick(fdt)
	for p in projectiles.duplicate():
		if is_instance_valid(p) and p.alive:
			p.tick(gdt)
	projectiles = projectiles.filter(func(p): return is_instance_valid(p) and p.alive)
	_resolve_push()
	_resolve_hits()
	_clash_projectiles()
	fx.tick(gdt)
	petals.tick(gdt, wind, cam_pos)
	_update_round(delta)
	_update_camera(delta)
	hud.tick(delta)
	if Game.autotest and int(clock * 0.5) != int((clock - delta) * 0.5):
		_autotest_log()


func _autotest_log() -> void:
	var parts := []
	for f in fighters:
		parts.append("%s hp=%d ki=%d st=%s mv=%s pos=(%d,%d) combo=%d" % [f.char_id, f.hp, f.ki, Fighter.S.keys()[f.state], f.move_name, f.position.x, f.position.y, f.combo_hits])
	print("[t=%.1f r%d %s %d:%d] %s | %s" % [clock, round_num, phase, wins[0], wins[1], parts[0], parts[1]])


func _unhandled_input(event: InputEvent) -> void:
	if demo:
		return
	if event.is_action_pressed("pause") and phase != "matchend":
		set_paused(not paused)
		get_viewport().set_input_as_handled()
	elif is_training() and event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_1:
				set_dummy_mode(1)
			KEY_2:
				set_dummy_mode(2)
			KEY_3:
				set_dummy_mode(3)
			KEY_4:
				set_dummy_mode(0)


func set_paused(on: bool) -> void:
	paused = on
	hud.show_pause(on)
	Sfx.set_muffled(on)


func _process(_dt: float) -> void:
	if demo:
		return
	var want := Input.MOUSE_MODE_VISIBLE
	if not paused and phase != "matchend" and uses_mouse_aim():
		want = Input.MOUSE_MODE_CONFINED_HIDDEN
	if Input.mouse_mode != want:
		Input.mouse_mode = want


func _exit_tree() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func uses_mouse_aim() -> bool:
	var c = fighters[0].controller if fighters.size() > 0 else null
	return c is HumanController and c.use_mouse


func get_mouse_world() -> Vector2:
	return get_global_mouse_position()


# ================================================================ combat
func _resolve_push() -> void:
	var a: Fighter = fighters[0]
	var b: Fighter = fighters[1]
	for f in [a, b]:
		if f.vanished or f.state in [Fighter.S.GRAB, Fighter.S.GRABBED, Fighter.S.KNOCKDOWN, Fighter.S.KO, Fighter.S.LOCKED] or f.dash_iframes():
			return
	var ra := a.pushbox()
	var rb := b.pushbox()
	if not ra.intersects(rb):
		return
	var overlap := minf(ra.end.x, rb.end.x) - maxf(ra.position.x, rb.position.x)
	if overlap <= 0.0:
		return
	var dir := signf(a.position.x - b.position.x)
	if dir == 0.0:
		dir = -float(a.facing)
	var pa := overlap * 0.5
	var pb := overlap * 0.5
	if a.wall_side != 0 and signf(dir) == float(a.wall_side):
		pa = 0.0
		pb = overlap
	elif b.wall_side != 0 and -signf(dir) == float(b.wall_side):
		pb = 0.0
		pa = overlap
	a.position.x += dir * pa
	b.position.x -= dir * pb
	var hw := a.body_w * PX * 0.5
	a.position.x = clampf(a.position.x, Cfg.WALL_L + hw, Cfg.WALL_R - hw)
	b.position.x = clampf(b.position.x, Cfg.WALL_L + hw, Cfg.WALL_R - hw)


func _resolve_hits() -> void:
	# throws
	for atk in fighters:
		var tb: Rect2 = atk.throw_box()
		if tb.size != Vector2.ZERO and not atk.move_connected:
			var def: Fighter = atk.opponent
			if tb.intersects(def.hurtbox()) and def.throwable():
				atk.move_connected = true
				atk.begin_grab(def)
				fx.hit_spark(def.center_pos(), atk.facing, "normal", Color(1, 1, 1), 0)
	# melee (collect first so simultaneous hits trade)
	var events := []
	for atk in fighters:
		var def: Fighter = atk.opponent
		for hb in atk.active_hitboxes():
			if atk.move_hit_keys.has(hb["key"]):
				continue
			var r: Rect2 = hb["rect"]
			var hr := def.hurtbox()
			if r.intersects(hr):
				events.append([atk, def, hb, r.intersection(hr).get_center()])
	for e in events:
		var atk: Fighter = e[0]
		var hb: Dictionary = e[2]
		atk.move_hit_keys[hb["key"]] = true
		_process_hit(atk, e[1], hb["mv"], atk.facing, false, null, e[3], 0.0)
	# projectiles
	for p in projectiles:
		if not is_instance_valid(p) or not p.alive or not p.can_hit_now():
			continue
		var def: Fighter = p.owner_f.opponent
		var r: Rect2 = p.hitbox()
		if r.size == Vector2.ZERO:
			continue
		var hr := def.hurtbox()
		if r.intersects(hr):
			var dir := int(signf(p.vel.x)) if absf(p.vel.x) > 1.0 else (1 if def.position.x > p.position.x else -1)
			var res := _process_hit(p.owner_f, def, p.data, dir, true, p, r.intersection(hr).get_center(), 0.0)
			if res != Fighter.R.PARRY and res != Fighter.R.WHIFF and is_instance_valid(p):
				p.on_hit_result(res)


func resolve_direct_hit(atk: Fighter, def: Fighter, m: Dictionary, dir: int, extra_stop := 0.0) -> int:
	return _process_hit(atk, def, m, dir, false, null, def.center_pos(), extra_stop)


func _process_hit(atk: Fighter, def: Fighter, m: Dictionary, dir: int, from_proj: bool, proj, pos: Vector2, extra_stop: float) -> int:
	var mult := 1.0
	if not from_proj and atk.cur_move == m:
		mult = atk.charge_mult
	var hp_before := def.hp
	var res: int = def.receive_hit(atk, m, dir, from_proj, mult)
	var strength: int = m["strength"]
	match res:
		Fighter.R.HIT, Fighter.R.ARMOR:
			var hs: float = m["hitstop"] * (1.0 + 0.4 * (mult - 1.0))
			if def.last_hit_by_move == m and def.combo_hits == 1:
				pass
			if not from_proj:
				atk.hitstop = maxf(atk.hitstop, hs)
			def.hitstop = maxf(def.hitstop, hs + extra_stop)
			fx.hit_spark(pos, dir, m["spark"], atk.fx_color, strength + (1 if mult > 1.4 else 0))
			Sfx.play(m["hit_sfx"], _vol(0.0), randf_range(0.95, 1.08) - 0.05 * strength)
			cam_shake(float(m["shake"]) * (1.0 + 0.5 * (mult - 1.0)))
			if float(m["zoom"]) > 0.0:
				cam_punch(float(m["zoom"]))
			var dealt := hp_before - def.hp
			if dealt > 0.5:
				fx.damage_number(pos + Vector2(0, -30), dealt, Color(1, 0.95, 0.7) if strength < 2 else Color(1, 0.6, 0.5))
			petals.impulse(pos, 160.0 + 60.0 * strength, Vector2(dir * (300 + 200 * strength), -150))
			if res == Fighter.R.ARMOR:
				fx.text(def.head_pos() + Vector2(0, -20), "БРОНЯ", Color(1, 0.8, 0.4), 1)
			if strength >= 2:
				fx.petal_burst(pos, 6 + strength * 3, Vector2(dir * 200, -100))
			if not def.alive:
				on_ko_hit(def, atk)
		Fighter.R.BLOCK:
			if not from_proj:
				atk.hitstop = maxf(atk.hitstop, 0.05)
			def.hitstop = maxf(def.hitstop, 0.05)
			fx.block_spark(pos, dir)
			Sfx.play("block", _vol(-2.0))
			cam_shake(1.5)
		Fighter.R.PARRY:
			if not from_proj:
				atk.hitstop = 0.16
			def.hitstop = 0.1
			fx.parry_flash(pos, def.fx_color)
			Sfx.play("parry", _vol(0.0))
			slowmo(0.35, 0.3, def)
			cam_punch(0.06)
			cam_shake(4.0)
			hud.side_text(def.player_idx, "ПАРИРОВАНИЕ!", Color(1, 0.9, 0.5))
			def.gain_ki(14.0)
			def.invuln = maxf(def.invuln, 0.12)
			def.go_neutral()
			if from_proj and proj != null:
				proj.reflect(def)
			elif not from_proj:
				atk.get_parried()
			petals.impulse(pos, 240.0, Vector2(0, -300))
		Fighter.R.COUNTERED:
			if proj != null:
				proj.destroy()
			def.on_countered(atk, from_proj)
	if not from_proj:
		atk.on_attack_result(res, def, m)
	return res


func _clash_projectiles() -> void:
	for i in projectiles.size():
		var a = projectiles[i]
		if not is_instance_valid(a) or not a.alive:
			continue
		for j in range(i + 1, projectiles.size()):
			var b = projectiles[j]
			if not is_instance_valid(b) or not b.alive or a.owner_f == b.owner_f:
				continue
			if not a.hitbox().intersects(b.hitbox()):
				continue
			if a.kind == "tornado" and b.clashable():
				fx.hit_spark(b.position, 1, "wind", a.col, 0)
				b.destroy()
			elif b.kind == "tornado" and a.clashable():
				fx.hit_spark(a.position, 1, "wind", b.col, 0)
				a.destroy()
			elif a.clashable() and b.clashable():
				var mid: Vector2 = (a.position + b.position) * 0.5
				fx.hit_spark(mid, 1, "heavy", Color(1, 0.9, 0.9), 0)
				Sfx.play("block", _vol(0.0), 1.3)
				if a.kind == "crescent" and b.kind == "feather":
					b.destroy()
				elif b.kind == "crescent" and a.kind == "feather":
					a.destroy()
				else:
					a.destroy()
					b.destroy()


func spawn_projectile(kind: String, owner: Fighter, pos: Vector2, v: Vector2, data: Dictionary) -> Projectile:
	var p := Projectile.new()
	p.arena = self
	p.setup(kind, owner, pos, v, data)
	if kind == "feather":
		actors_root.add_child(p)
	else:
		front_root.add_child(p)
	projectiles.append(p)
	return p


func throw_break(atk: Fighter, def: Fighter) -> void:
	for f in [atk, def]:
		f.grab_partner = null
		f.interrupt_move()
		f.set_state(Fighter.S.BLOCKSTUN)
		f.stun_time = 0.28
	atk.vel.x = -atk.facing * 420.0
	def.vel.x = -def.facing * 420.0
	var mid: Vector2 = (atk.center_pos() + def.center_pos()) * 0.5
	fx.parry_flash(mid, Color(1, 1, 1))
	Sfx.play("parry", _vol(-4.0), 1.3)
	hud.side_text(def.player_idx, "ЗАХВАТ СОРВАН", Color(0.8, 1, 0.9))


# ================================================================ event hooks
func on_perfect_dodge(f: Fighter, _atk: Fighter) -> void:
	slowmo(0.3, 0.75, f)
	f.gain_ki(12.0)
	f.invuln = maxf(f.invuln, 0.25)
	Sfx.play("perfect", _vol(0.0))
	hud.side_text(f.player_idx, "ИДЕАЛЬНОЕ УКЛОНЕНИЕ", Color(0.6, 0.95, 1))
	fx.ring(f.center_pos(), Color(0.6, 0.95, 1, 0.9), 20, 140, 0.4, 4)
	for i in 3:
		fx.afterimage(f, Color(0.6, 0.95, 1, 0.6 - i * 0.15), 0.5)
	screen_flash(Color(0.6, 0.9, 1, 0.5), 0.2)


func on_counter_hit(atk: Fighter, def: Fighter) -> void:
	if atk == null:
		return
	hud.side_text(atk.player_idx, "КОНТРУДАР!", Color(1, 0.55, 0.4))
	fx.ring(def.center_pos(), Color(1, 0.5, 0.35, 0.9), 16, 110, 0.3, 5)
	Sfx.play("counter", _vol(-8.0), 1.3)


func on_guard_break(f: Fighter) -> void:
	fx.guard_break_fx(f.center_pos())
	Sfx.play("guard_break", _vol(0.0))
	cam_shake(6.0)
	cam_punch(0.06)
	hud.side_text(f.opponent.player_idx, "ПРОБИТИЕ БЛОКА!", Color(0.6, 0.85, 1))


func on_barrier_hit(p: Vector2, normal: Vector2, strength: float) -> void:
	fx.barrier_hit(p, normal, strength)
	cam_shake(3.0 + 5.0 * strength)
	if strength >= 0.9:
		Sfx.play("wall", _vol(-2.0))
		petals.impulse(p, 260.0, normal * 500.0)


func on_ground_bounce(f: Fighter) -> void:
	fx.shockwave(f.position, f.opponent.fx_color if f.opponent else Color.WHITE)
	Sfx.play("wall", _vol(-3.0), 0.9)
	cam_shake(5.0)


func super_freeze(user: Fighter, dur: float, title: String, sub: String) -> void:
	freeze_t = dur
	freeze_user = user
	darken_target = 0.72
	Sfx.play("ult_start", _vol(0.0))
	hud.cutin(user, title, sub)
	fx.ring(user.center_pos(), Color(user.fx_color, 1.0), 200, 10, 0.6, 6)
	fx.petal_burst(user.center_pos(), 30, Vector2(0, -150))
	user.flash_t = 0.12
	user.flash_color = user.fx_color


func slowmo(scale: float, dur: float, exempt: Fighter = null) -> void:
	slow_scale = scale
	slow_t = dur
	slow_exempt = exempt


func screen_flash(col: Color, dur: float) -> void:
	hud.flash(col, dur)


func cam_shake(amount: float) -> void:
	shake = maxf(shake, amount)


func cam_punch(z: float) -> void:
	punch = maxf(punch, z)


func _vol(db: float) -> float:
	return db


# ================================================================ camera
func _update_camera(dt: float) -> void:
	var a: Fighter = fighters[0]
	var b: Fighter = fighters[1]
	var target: Vector2
	var z: float
	if freeze_t > 0.0 and freeze_user != null:
		target = freeze_user.center_pos()
		z = 1.3
	else:
		var ca := a.center_pos() if not a.vanished else b.center_pos()
		var cb := b.center_pos() if not b.vanished else a.center_pos()
		target = (ca + cb) * 0.5 + Vector2(0, -20)
		var need := Vector2(absf(ca.x - cb.x) + 680.0, absf(ca.y - cb.y) + 500.0)
		z = minf(VIEW.x / need.x, VIEW.y / need.y)
		if phase == "ko" and ko_loser != null and slow_t > 0.0:
			target = ko_loser.center_pos().lerp(target, 0.4)
			z = maxf(z, 1.05)
		if phase == "intro":
			z = minf(z, 1.0)
	z = clampf(z, ZOOM_MIN, ZOOM_MAX)
	var rate := 7.0 if freeze_t > 0.0 else 3.2
	cam_zoom = lerpf(cam_zoom, z, 1.0 - exp(-dt * rate))
	cam_pos = cam_pos.lerp(target, 1.0 - exp(-dt * (8.0 if freeze_t > 0.0 else 5.5)))
	var zz := clampf(cam_zoom * (1.0 + punch), ZOOM_MIN, 1.6)
	punch = move_toward(punch, 0.0, dt * 0.5)
	var half := VIEW / zz * 0.5
	var p := cam_pos
	shake = move_toward(shake, 0.0, dt * (18.0 + shake * 4.0))
	if shake > 0.05:
		p += Vector2(randf_range(-1, 1), randf_range(-1, 1)) * shake * 1.6
	p.x = clampf(p.x, half.x, Cfg.WORLD_W - half.x) if half.x * 2.0 < Cfg.WORLD_W else Cfg.WORLD_W * 0.5
	p.y = clampf(p.y, half.y, Cfg.WORLD_H - half.y) if half.y * 2.0 < Cfg.WORLD_H else Cfg.WORLD_H * 0.5
	cam.position = p
	cam.zoom = Vector2(zz, zz)


# ================================================================ debug
func draw_debug(ci: CanvasItem) -> void:
	for f in fighters:
		ci.draw_rect(f.hurtbox(), Color(0.3, 1, 0.4, 0.8), false, 3.0)
		for hb in f.active_hitboxes():
			ci.draw_rect(hb["rect"], Color(1, 0.2, 0.2, 0.8), false, 3.0)
		var tb: Rect2 = f.throw_box()
		if tb.size != Vector2.ZERO:
			ci.draw_rect(tb, Color(1, 1, 0.2, 0.8), false, 3.0)
	for p in projectiles:
		if is_instance_valid(p):
			var r: Rect2 = p.hitbox()
			if r.size != Vector2.ZERO:
				ci.draw_rect(r, Color(1, 0.5, 0.1, 0.8), false, 3.0)


# ================================================================ glows
class Glows:
	extends Node2D
	var arena = null
	var tex: GradientTexture2D
	var t := 0.0

	func _ready() -> void:
		var g := Gradient.new()
		g.set_color(0, Color(1, 0.75, 0.4, 0.55))
		g.set_color(1, Color(1, 0.5, 0.3, 0.0))
		tex = GradientTexture2D.new()
		tex.gradient = g
		tex.fill = GradientTexture2D.FILL_RADIAL
		tex.fill_from = Vector2(0.5, 0.5)
		tex.fill_to = Vector2(1.0, 0.5)
		tex.width = 128
		tex.height = 128
		var m := CanvasItemMaterial.new()
		m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		material = m

	func _process(dt: float) -> void:
		t += dt
		queue_redraw()

	func _draw() -> void:
		var dim := 1.0
		if arena != null:
			dim = 1.0 - arena.darken * 0.7
		var i := 0
		for p in Cfg.LANTERNS:
			var fl := 0.8 + 0.12 * sin(t * 7.3 + i * 1.7) + 0.08 * sin(t * 17.0 + i)
			var big := 1.0 if i < 2 else 0.55
			var s := 170.0 * big * (0.95 + 0.05 * sin(t * 3.0 + i))
			draw_texture_rect(tex, Rect2(p - Vector2(s, s) * 0.5, Vector2(s, s)), false, Color(1, 1, 1, fl * dim))
			i += 1
		var sun := Vector2(1305, 345)
		var ss := 360.0 + sin(t * 0.8) * 12.0
		draw_texture_rect(tex, Rect2(sun - Vector2(ss, ss) * 0.5, Vector2(ss, ss)), false, Color(1, 0.8, 0.6, 0.35 * dim))
