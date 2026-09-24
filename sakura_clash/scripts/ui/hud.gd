class_name HUD
extends CanvasLayer
## Fight HUD: health / ki / guard / flight bars, timer, round pips,
## ability cooldowns, combo counters, announcer, ultimate cut-in,
## screen flash, vignette, pause and results menus.

var arena = null
var demo := false
var canvas: Control
var t := 0.0

var trail := [1.0, 1.0]
var trail_delay := [0.0, 0.0]
var last_hp := [1.0, 1.0]
var combo_show := [0.0, 0.0]
var combo_val := [0, 0]
var combo_dmg := [0.0, 0.0]
var side_msgs := [[], []]

var ann_text := ""
var ann_col := Color.WHITE
var ann_t := 0.0
var ann_dur := 1.0
var ann_big := false

var cut_t := 0.0
var cut_user = null
var cut_title := ""
var cut_sub := ""

var flash_col := Color(1, 1, 1, 0)
var flash_t := 0.0
var flash_dur := 0.2

var vignette: GradientTexture2D
var pause_root: Control
var pause_menu: MenuList
var results_root: Control
var results_menu: MenuList
var help: ControlsHelp
var results_winner := -1


func _ready() -> void:
	layer = 5
	canvas = HudCanvas.new()
	canvas.hud = self
	canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(canvas)
	var g := Gradient.new()
	g.set_color(0, Color(0, 0, 0, 0))
	g.set_color(1, Color(0.04, 0.0, 0.08, 0.55))
	g.add_point(0.6, Color(0, 0, 0, 0))
	vignette = GradientTexture2D.new()
	vignette.gradient = g
	vignette.fill = GradientTexture2D.FILL_RADIAL
	vignette.fill_from = Vector2(0.5, 0.5)
	vignette.fill_to = Vector2(1.05, 1.05)
	vignette.width = 256
	vignette.height = 256
	_build_pause()
	_build_results()


func _build_pause() -> void:
	pause_root = Control.new()
	pause_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_root.visible = false
	pause_root.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(pause_root)
	var dim := ColorRect.new()
	dim.color = Color(0.04, 0.01, 0.07, 0.7)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pause_root.add_child(dim)
	var title := Label.new()
	title.text = "ПАУЗА"
	title.add_theme_font_override("font", Game.font_bold)
	title.add_theme_font_size_override("font_size", 64)
	title.add_theme_color_override("font_color", Color(1, 0.8, 0.9))
	title.add_theme_constant_override("outline_size", 12)
	title.add_theme_color_override("font_outline_color", Color(0.08, 0.03, 0.12))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0, 150)
	title.size = Vector2(1280, 80)
	pause_root.add_child(title)
	pause_menu = MenuList.new(["Продолжить", "Управление", "Заново", "Выбор бойцов", "Главное меню"], 30)
	pause_menu.position = Vector2(640 - 220, 270)
	pause_menu.size = Vector2(440, 250)
	pause_menu.chosen.connect(_on_pause_choice)
	pause_root.add_child(pause_menu)
	help = ControlsHelp.new()
	help.visible = false
	add_child(help)


func _build_results() -> void:
	results_root = Control.new()
	results_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	results_root.visible = false
	add_child(results_root)
	results_menu = MenuList.new(["Реванш", "Выбор бойцов", "Главное меню"], 30)
	results_menu.position = Vector2(640 - 220, 420)
	results_menu.size = Vector2(440, 150)
	results_menu.chosen.connect(_on_results_choice)
	results_root.add_child(results_menu)


func _unhandled_input(event: InputEvent) -> void:
	if help.visible:
		var back := event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel")
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
			back = true
		if back:
			help.visible = false
			pause_menu.active = true
			get_viewport().set_input_as_handled()


func _on_pause_choice(i: int) -> void:
	match i:
		0:
			arena.set_paused(false)
		1:
			help.visible = true
			pause_menu.active = false
		2:
			Game.main.start_fight()
		3:
			Game.main.goto_select()
		4:
			Game.main.goto_title()


func _on_results_choice(i: int) -> void:
	match i:
		0:
			Game.main.start_fight()
		1:
			Game.main.goto_select()
		2:
			Game.main.goto_title()


func show_pause(on: bool) -> void:
	pause_root.visible = on
	pause_menu.active = on
	pause_menu.sel = 0
	help.visible = false


func show_results(winner: int) -> void:
	results_winner = winner
	results_root.visible = true
	results_menu.active = true
	Sfx.set_muffled(true)


func on_round_start() -> void:
	trail = [1.0, 1.0]
	combo_show = [0.0, 0.0]


func announce(text: String, col: Color, dur: float, big := false) -> void:
	ann_text = text
	ann_col = col
	ann_t = 0.0
	ann_dur = dur
	ann_big = big


func side_text(idx: int, text: String, col: Color) -> void:
	if idx < 0 or idx > 1:
		return
	side_msgs[idx].append({"text": text, "col": col, "t": 0.0})
	if side_msgs[idx].size() > 3:
		side_msgs[idx].pop_front()


func cutin(user, title: String, sub: String) -> void:
	cut_user = user
	cut_title = title
	cut_sub = sub
	cut_t = 0.0


func flash(col: Color, dur: float) -> void:
	flash_col = col
	flash_t = dur
	flash_dur = dur


func tick(dt: float) -> void:
	t += dt
	ann_t += dt
	cut_t += dt
	flash_t = maxf(0.0, flash_t - dt)
	if arena == null:
		return
	for i in 2:
		var f: Fighter = arena.fighters[i]
		var r := f.hp_ratio()
		if r < last_hp[i] - 0.0001:
			trail_delay[i] = 0.55
		last_hp[i] = r
		trail_delay[i] -= dt
		if trail_delay[i] <= 0.0:
			trail[i] = move_toward(trail[i], r, dt * 0.8)
		if trail[i] < r:
			trail[i] = r
		# combo counter shown on the attacker's side
		var victim: Fighter = arena.fighters[1 - i]
		if victim.combo_hits >= 2:
			combo_show[i] = 1.4
			combo_val[i] = victim.combo_hits
			combo_dmg[i] = victim.combo_damage
		else:
			combo_show[i] = maxf(0.0, combo_show[i] - dt)
		for m in side_msgs[i]:
			m["t"] += dt
		side_msgs[i] = side_msgs[i].filter(func(m): return m["t"] < 1.6)
	canvas.queue_redraw()


class HudCanvas:
	extends Control
	var hud = null

	func _draw() -> void:
		if hud != null:
			hud.draw_hud(self)


# ================================================================ drawing
const OUT := Color(0.08, 0.03, 0.12)


func _text(ci: Control, pos: Vector2, s: String, sz: int, col: Color, align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0, outline := 6) -> void:
	var font: Font = Game.font_bold
	if outline > 0:
		ci.draw_string_outline(font, pos, s, align, width, sz, outline, Color(OUT, col.a))
	ci.draw_string(font, pos, s, align, width, sz, col)


func draw_hud(ci: Control) -> void:
	if arena == null:
		return
	ci.draw_texture_rect(vignette, Rect2(Vector2.ZERO, Vector2(1280, 720)), false)
	if not demo:
		for i in 2:
			_draw_player_bars(ci, i)
			_draw_abilities(ci, i)
			_draw_combo(ci, i)
		_draw_timer(ci)
		if arena.is_training():
			_text(ci, Vector2(0, 706), "1 стоять   2 блок   3 прыжки   4 ИИ   |   F1 хитбоксы   |   Esc меню", 16, Color(0.9, 0.85, 1, 0.8), HORIZONTAL_ALIGNMENT_CENTER, 1280, 4)
		elif arena.round_num == 1 and arena.clock < 7.0:
			var a := clampf(7.0 - arena.clock, 0.0, 1.0)
			_text(ci, Vector2(0, 706), "ESC - пауза и управление      ЛКМ / ПКМ - удары      Q E R F - способности      SHIFT - рывок", 16, Color(0.9, 0.85, 1, 0.85 * a), HORIZONTAL_ALIGNMENT_CENTER, 1280, 4)
	_draw_cutin(ci)
	_draw_announce(ci)
	if not demo and arena.uses_mouse_aim() and not arena.paused and not results_root.visible:
		_draw_reticle(ci)
	if flash_t > 0.0:
		var c := flash_col
		c.a *= (flash_t / flash_dur) * 0.85
		ci.draw_rect(Rect2(0, 0, 1280, 720), c)
	if results_root.visible:
		_draw_results(ci)


func _draw_reticle(ci: Control) -> void:
	var m := ci.get_local_mouse_position()
	var f: Fighter = arena.fighters[0]
	var col := f.fx_color
	var g := 5.0
	var l := 9.0
	for d in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]:
		var a: Vector2 = m + d * g
		var b: Vector2 = m + d * (g + l)
		ci.draw_line(a, b, OUT, 6.0)
	for d in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]:
		ci.draw_line(m + d * (g + 1), m + d * (g + l - 1), col, 2.0)
	ci.draw_rect(Rect2(m - Vector2(1.5, 1.5), Vector2(3, 3)), Color.WHITE)


func _bar(ci: Control, r: Rect2, frac: float, col: Color, right: bool, trail_frac := -1.0, trail_col := Color.WHITE) -> void:
	ci.draw_rect(r.grow(3), OUT)
	ci.draw_rect(r, Color(0.17, 0.09, 0.22))
	if trail_frac > frac:
		var tw := r.size.x * trail_frac
		var tr := Rect2(r.end.x - tw if right else r.position.x, r.position.y, tw, r.size.y)
		ci.draw_rect(tr, trail_col)
	var w := r.size.x * clampf(frac, 0.0, 1.0)
	var fr := Rect2(r.end.x - w if right else r.position.x, r.position.y, w, r.size.y)
	ci.draw_rect(fr, col)
	if r.size.y >= 10:
		ci.draw_rect(Rect2(fr.position, Vector2(fr.size.x, maxf(2.0, r.size.y * 0.3))), col.lightened(0.35))
		ci.draw_rect(Rect2(fr.position + Vector2(0, r.size.y - 3), Vector2(fr.size.x, 3)), col.darkened(0.3))


func _draw_player_bars(ci: Control, i: int) -> void:
	var f: Fighter = arena.fighters[i]
	var right := i == 1
	var x0 := 40.0 if not right else 740.0
	var hp_r := Rect2(x0, 42, 500, 26)
	var r := f.hp_ratio()
	var col := Color(1.0, 0.82, 0.36)
	if r < 0.3:
		col = Color(1.0, 0.35 + 0.15 * sin(t * 10.0), 0.3)
	_bar(ci, hp_r, r, col, right, trail[i], Color(1, 0.3, 0.35))
	# name + tag
	var tag := "P%d" % (i + 1)
	if f.controller is AIController:
		tag = "ИИ" if arena.is_training() == false else "МАНЕКЕН"
	var info: Dictionary = Game.char_info(f.char_id)
	if right:
		_text(ci, Vector2(740, 34), tag, 16, Color(0.8, 0.75, 0.9), HORIZONTAL_ALIGNMENT_LEFT, -1, 4)
		_text(ci, Vector2(740, 34), f.display_name + "  " + info["type"], 22, f.fx_color, HORIZONTAL_ALIGNMENT_RIGHT, 500, 6)
	else:
		_text(ci, Vector2(40, 34), f.display_name + "  " + info["type"], 22, f.fx_color, HORIZONTAL_ALIGNMENT_LEFT, -1, 6)
		_text(ci, Vector2(40, 34), tag, 16, Color(0.8, 0.75, 0.9), HORIZONTAL_ALIGNMENT_RIGHT, 500, 4)
	# ki
	var ki_r := Rect2(x0 if not right else 1240 - 320, 76, 320, 12)
	var kf := f.ki / Cfg.KI_MAX
	var kcol := Color(0.75, 0.45, 1.0)
	if kf >= 1.0:
		kcol = Color(1.0, 0.55, 0.85).lerp(Color(1, 1, 1), 0.35 + 0.35 * sin(t * 8.0))
	_bar(ci, ki_r, kf, kcol, right)
	for s in range(1, 4):
		var sx := ki_r.position.x + ki_r.size.x * s / 4.0
		ci.draw_rect(Rect2(sx - 1, ki_r.position.y, 2, ki_r.size.y), OUT)
	var ki_label := "КИ %d" % int(f.ki)
	if kf >= 1.0:
		ki_label = "УЛЬТА ГОТОВА [F]" if i == 0 or not (f.controller is AIController) else "УЛЬТА ГОТОВА"
	if right:
		_text(ci, Vector2(ki_r.position.x - 330, 88), ki_label, 16, kcol, HORIZONTAL_ALIGNMENT_RIGHT, 320, 4)
	else:
		_text(ci, Vector2(ki_r.end.x + 10, 88), ki_label, 16, kcol, HORIZONTAL_ALIGNMENT_LEFT, -1, 4)
	# guard
	var g_r := Rect2(x0 if not right else 1240 - 160, 94, 160, 6)
	_bar(ci, g_r, f.guard_hp / 100.0, Color(0.55, 0.8, 1.0) if f.state != Fighter.S.GUARDBREAK else Color(1, 0.3, 0.3), right)
	# flight stamina
	if f.is_flier:
		var s_r := Rect2(x0 + 170 if not right else 1240 - 330, 94, 150, 6)
		var scol := Color(0.45, 1.0, 0.8) if not f.exhausted else Color(1, 0.4, 0.3, 0.6 + 0.4 * sin(t * 12.0))
		_bar(ci, s_r, f.stamina / f.stamina_max, scol, right)
		_text(ci, Vector2(s_r.position.x if not right else s_r.position.x + s_r.size.x - 50, 114), "ПОЛЁТ", 13, scol, HORIZONTAL_ALIGNMENT_LEFT, -1, 3)
	# round pips
	for k in Cfg.ROUNDS_TO_WIN:
		var px := 640.0 - 58.0 - k * 22.0 if not right else 640.0 + 58.0 + k * 22.0
		var won: bool = arena.wins[i] > k
		var pts := PackedVector2Array([Vector2(px, 94), Vector2(px + 8, 102), Vector2(px, 110), Vector2(px - 8, 102)])
		ci.draw_colored_polygon(pts, OUT)
		var inner := PackedVector2Array([Vector2(px, 97), Vector2(px + 5, 102), Vector2(px, 107), Vector2(px - 5, 102)])
		ci.draw_colored_polygon(inner, Color(1, 0.5, 0.75) if won else Color(0.3, 0.2, 0.35))


func _draw_timer(ci: Control) -> void:
	var r := Rect2(596, 26, 88, 60)
	ci.draw_rect(r.grow(3), OUT)
	ci.draw_rect(r, Color(0.16, 0.08, 0.2))
	ci.draw_rect(Rect2(r.position, Vector2(r.size.x, 3)), Color(1, 0.55, 0.75))
	var s := "∞" if arena.is_training() else str(int(ceil(arena.timer)))
	var col := Color(1, 0.95, 0.9)
	if not arena.is_training() and arena.timer < 10.0:
		col = Color(1, 0.4, 0.4)
	_text(ci, Vector2(r.position.x, r.position.y + 46), s, 42, col, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 6)


func _draw_abilities(ci: Control, i: int) -> void:
	var f: Fighter = arena.fighters[i]
	var info: Dictionary = Game.char_info(f.char_id)
	var skills: Array = info["skills"]
	var keys := ["q", "e", "r", "f"]
	var human := not (f.controller is AIController)
	for k in 4:
		var bx := 40.0 + k * 66.0 if i == 0 else 1240.0 - 56.0 - (3 - k) * 66.0
		var r := Rect2(bx, 636, 56, 56)
		ci.draw_rect(r.grow(3), OUT)
		ci.draw_rect(r, Color(0.2, 0.1, 0.25))
		var key: String = keys[k]
		var ready := true
		var frac := 0.0
		var cd := 0.0
		if key == "f":
			frac = 1.0 - f.ki / Cfg.KI_MAX
			ready = f.ki >= Cfg.KI_MAX
		else:
			cd = f.cooldowns[key]
			var m: String = key
			var total: float = f.moves[m]["cd"] if f.moves.has(m) else 1.0
			frac = clampf(cd / maxf(total, 0.01), 0.0, 1.0)
			ready = cd <= 0.0
		_skill_icon(ci, r, f, k)
		if frac > 0.0:
			ci.draw_rect(Rect2(r.position, Vector2(r.size.x, r.size.y * frac)), Color(0.05, 0.02, 0.08, 0.72))
		if ready:
			var pulse := 0.5 + 0.5 * sin(t * 5.0 + k)
			ci.draw_rect(r, Color(f.fx_color, 0.5 + 0.5 * pulse if key == "f" else 0.9), false, 2.0)
		if cd > 0.0:
			_text(ci, Vector2(r.position.x, r.position.y + 36), "%.1f" % cd if cd < 10.0 else str(int(cd)), 18, Color(1, 1, 1), HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 4)
		var label := key.to_upper()
		if not human or i == 1:
			label = ""
			if f.controller is HumanController and i == 1:
				label = ["N7", "N9", "N1", "N3"][k]
		if label != "":
			_text(ci, Vector2(r.position.x + 4, r.position.y + 16), label, 15, Color(1, 0.92, 0.6), HORIZONTAL_ALIGNMENT_LEFT, -1, 4)
		var sk: Array = skills[k]
		_text(ci, Vector2(r.position.x - 5, r.end.y + 15), sk[3], 12, Color(0.9, 0.85, 1, 0.85), HORIZONTAL_ALIGNMENT_CENTER, r.size.x + 10, 3)


func _skill_icon(ci: Control, r: Rect2, f: Fighter, k: int) -> void:
	var c := r.get_center()
	var col := f.fx_color
	var col2 := f.fx_color2
	if f.char_id == "ronin":
		match k:
			0:
				ci.draw_line(c + Vector2(-18, 10), c + Vector2(18, -10), col, 4)
				ci.draw_line(c + Vector2(-18, 10), c + Vector2(18, -10), Color.WHITE, 2)
				for j in 3:
					ci.draw_rect(Rect2(c + Vector2(-20 + j * 8, 12 + j * 2), Vector2(4, 4)), Color(col, 0.6 - j * 0.15))
			1:
				ci.draw_arc(c + Vector2(-4, 0), 16, -1.2, 1.2, 10, col, 5)
				ci.draw_arc(c + Vector2(-4, 0), 16, -1.0, 1.0, 10, Color.WHITE, 2)
			2:
				ci.draw_line(c + Vector2(-14, 14), c + Vector2(14, -14), Color(0.85, 0.9, 1), 3)
				ci.draw_rect(Rect2(c + Vector2(-8, -8), Vector2(16, 16)), col, false, 2)
				ci.draw_rect(Rect2(c + Vector2(-4, -4), Vector2(8, 8)), col2)
			3:
				for j in 5:
					var a := t * 2.0 + j * TAU / 5.0
					var p := c + Vector2.from_angle(a) * 12.0
					ci.draw_colored_polygon(PackedVector2Array([p + Vector2(0, -5), p + Vector2(4, 0), p + Vector2(0, 5), p + Vector2(-4, 0)]), Color(1, 0.7, 0.85))
				ci.draw_circle(c, 5, Color.WHITE)
	else:
		match k:
			0:
				for j in 3:
					var a := -0.35 + j * 0.35
					var d := Vector2.from_angle(a)
					ci.draw_line(c - d * 14 + Vector2(0, (j - 1) * 6), c + d * 14 + Vector2(0, (j - 1) * 6), Color(0.3, 0.22, 0.4), 4)
					ci.draw_line(c - d * 14 + Vector2(0, (j - 1) * 6), c + d * 10 + Vector2(0, (j - 1) * 6), col, 2)
			1:
				for j in 4:
					ci.draw_arc(c + Vector2(0, 14 - j * 8), 6 + j * 4, t * 4.0 + j, t * 4.0 + j + 4.0, 8, col2 if j % 2 == 0 else Color.WHITE, 2)
			2:
				var pts := PackedVector2Array([c + Vector2(-4, -18), c + Vector2(6, -2), c + Vector2(-2, 0), c + Vector2(6, 18), c + Vector2(-8, -2), c + Vector2(0, -4)])
				ci.draw_polyline(pts, col, 3)
			3:
				ci.draw_circle(c + Vector2(0, -8), 12, Color(0.35, 0.3, 0.45))
				ci.draw_circle(c + Vector2(-9, -4), 8, Color(0.35, 0.3, 0.45))
				ci.draw_polyline(PackedVector2Array([c + Vector2(2, 0), c + Vector2(-4, 10), c + Vector2(2, 10), c + Vector2(-3, 20)]), col, 3)


func _draw_combo(ci: Control, i: int) -> void:
	var x := 44.0 if i == 0 else 1236.0
	var al := HORIZONTAL_ALIGNMENT_LEFT if i == 0 else HORIZONTAL_ALIGNMENT_RIGHT
	var base_x := x if i == 0 else x - 400.0
	var y := 190.0
	if combo_show[i] > 0.0:
		var a := clampf(combo_show[i] / 0.4, 0.0, 1.0)
		var f: Fighter = arena.fighters[i]
		var n: int = combo_val[i]
		var sz := 60 + mini(n, 20)
		_text(ci, Vector2(base_x, y), str(n), sz, Color(f.fx_color, a), al, 400, 10)
		_text(ci, Vector2(base_x, y + 30), "УДАРОВ" if n >= 5 else "УДАРА", 24, Color(1, 1, 1, a), al, 400, 6)
		_text(ci, Vector2(base_x, y + 56), "%d урона" % int(combo_dmg[i]), 18, Color(1, 0.85, 0.6, a), al, 400, 5)
		y += 90.0
	else:
		y += 10.0
	for m in side_msgs[i]:
		var k: float = m["t"]
		var a2 := clampf(1.6 - k, 0.0, 1.0) / 1.0
		var slide := (1.0 - Pose.ease_out(minf(1.0, k * 6.0))) * 60.0
		var px := base_x - slide if i == 0 else base_x + slide
		var col: Color = m["col"]
		_text(ci, Vector2(px, y), m["text"], 24, Color(col, a2), al, 400, 6)
		y += 32.0


func _draw_announce(ci: Control) -> void:
	if ann_text == "" or ann_t > ann_dur + 0.35:
		return
	var k := ann_t
	var sc := 1.0 + 0.8 * (1.0 - Pose.ease_out(minf(1.0, k * 5.0), 3.0))
	var a := 1.0
	if k > ann_dur:
		a = 1.0 - (k - ann_dur) / 0.35
	a *= minf(1.0, k * 8.0)
	var base_sz := 96 if ann_big else 70
	var sz := int(base_sz * sc)
	# backing stripe
	var sh := base_sz * 1.1
	ci.draw_rect(Rect2(0, 330 - sh * 0.75, 1280, sh), Color(0.05, 0.02, 0.08, 0.45 * a))
	ci.draw_rect(Rect2(0, 330 - sh * 0.75, 1280, 3), Color(ann_col, 0.8 * a))
	ci.draw_rect(Rect2(0, 330 + sh * 0.25 - 3, 1280, 3), Color(ann_col, 0.8 * a))
	_text(ci, Vector2(0, 330 + sz * 0.1), ann_text, sz, Color(ann_col, a), HORIZONTAL_ALIGNMENT_CENTER, 1280, 14)


func _draw_cutin(ci: Control) -> void:
	if cut_user == null or cut_t > 1.0:
		return
	var f: Fighter = cut_user
	var k := cut_t
	var from_left := f.player_idx == 0
	var slide := Pose.ease_out(minf(1.0, k * 5.0), 3.0)
	var out := clampf((k - 0.8) / 0.2, 0.0, 1.0)
	var a := 1.0 - out
	var y := 250.0
	var h := 130.0 * (1.0 - out * 0.7)
	var off := (1.0 - slide) * 1280.0 * (-1.0 if from_left else 1.0)
	ci.draw_rect(Rect2(off, y, 1280, h), Color(0.06, 0.02, 0.1, 0.85 * a))
	for j in 6:
		var sx := fmod(k * 1600.0 * (1 if from_left else -1) + j * 260.0, 1560.0) - 140.0
		ci.draw_colored_polygon(PackedVector2Array([Vector2(sx, y), Vector2(sx + 90, y), Vector2(sx + 30, y + h), Vector2(sx - 60, y + h)]), Color(f.fx_color, 0.12 * a))
	ci.draw_rect(Rect2(off, y, 1280, 5), Color(f.fx_color, a))
	ci.draw_rect(Rect2(off, y + h - 5, 1280, 5), Color(f.fx_color2, a))
	var tx := 120.0 + off if from_left else off - 120.0
	var al := HORIZONTAL_ALIGNMENT_LEFT if from_left else HORIZONTAL_ALIGNMENT_RIGHT
	_text(ci, Vector2(tx, y + 70), cut_title, 58, Color(1, 1, 1, a), al, 1280, 10)
	_text(ci, Vector2(tx, y + 106), cut_sub + "  -  " + f.display_name, 24, Color(f.fx_color, a), al, 1280, 6)


func _draw_results(ci: Control) -> void:
	var k := minf(1.0, results_root.get_meta("t", 0.0))
	ci.draw_rect(Rect2(0, 0, 1280, 720), Color(0.04, 0.01, 0.07, 0.55))
	var f: Fighter = arena.fighters[results_winner]
	_text(ci, Vector2(0, 250), "ПОБЕДА", 90, Color(1, 0.85, 0.9), HORIZONTAL_ALIGNMENT_CENTER, 1280, 14)
	_text(ci, Vector2(0, 320), f.display_name + "  (" + ("ИГРОК %d" % (results_winner + 1) if not (f.controller is AIController) else "ИИ") + ")", 40, f.fx_color, HORIZONTAL_ALIGNMENT_CENTER, 1280, 8)
	_text(ci, Vector2(0, 370), "%d : %d" % [arena.wins[0], arena.wins[1]], 32, Color(1, 1, 1), HORIZONTAL_ALIGNMENT_CENTER, 1280, 6)
	results_root.set_meta("t", k + 0.02)
