class_name SelectScreen
extends Node
## Character select: P1 picks, then P2 / CPU / dummy, then CPU difficulty.

const IDS := ["ronin", "tengu"]
const DIFF := ["ЛЕГКО", "НОРМАЛЬНО", "СЛОЖНО"]

var demo: Arena
var layer: CanvasLayer
var ui: SelectUI
var step := 0
var sel := [0, 1]
var diff := 1
var big: Array = []  # FighterPreview per side
var big_rects: Array = []
var cards: Array = []  # FighterPreview per character
var card_rects: Array = []
var shown := [-1, -1]
var shown_alt := [false, false]


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	diff = Game.cpu_level
	sel = [IDS.find(Game.p1_char), IDS.find(Game.p2_char)]
	for i in 2:
		if sel[i] < 0:
			sel[i] = i
	demo = Arena.new()
	demo.demo = true
	add_child(demo)
	layer = CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.02, 0.08, 0.74)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(dim)
	for i in 2:
		var p := FighterPreview.new()
		add_child(p)
		big.append(p)
		var tr := p.make_rect(Vector2(330, 288))
		tr.position = Vector2(40 if i == 0 else 910, 92)
		layer.add_child(tr)
		big_rects.append(Rect2(tr.position, tr.size))
	for c in 2:
		var p := FighterPreview.new()
		p.animate_showcase = false
		add_child(p)
		p.set_char(IDS[c], false, 1 if c == 0 else -1)
		cards.append(p)
		var r := Rect2(470 + c * 190, 150, 150, 200)
		var cbg := ColorRect.new()
		cbg.color = Color(0.16, 0.08, 0.2, 0.92)
		cbg.position = r.position
		cbg.size = r.size
		cbg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layer.add_child(cbg)
		var tr := p.make_rect(r.size - Vector2(10, 40))
		tr.position = r.position + Vector2(5, 8)
		card_rects.append(r)
		ui_card_holder(tr)
	ui = SelectUI.new()
	ui.scr = self
	ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_PASS
	layer.add_child(ui)
	_refresh()


var _card_nodes: Array = []


func ui_card_holder(tr: TextureRect) -> void:
	_card_nodes.append(tr)
	layer.add_child(tr)


func _refresh() -> void:
	for i in 2:
		var alt: bool = i == 1 and sel[0] == sel[1]
		if shown[i] != sel[i] or shown_alt[i] != alt:
			shown[i] = sel[i]
			shown_alt[i] = alt
			big[i].set_char(IDS[sel[i]], alt, 1 if i == 0 else -1)


func _cur_player() -> int:
	return 0 if step == 0 else 1


func _move_sel(d: int) -> void:
	var p := _cur_player()
	if step >= 2:
		diff = clampi(diff + d, 0, 2)
	else:
		sel[p] = (sel[p] + d + IDS.size()) % IDS.size()
	Sfx.play("ui_move", -4)
	_refresh()


func _confirm() -> void:
	Sfx.play("ui_ok")
	if step == 0:
		step = 1
	elif step == 1:
		if Game.mode == Game.Mode.VS_CPU:
			step = 2
		else:
			_start()
	else:
		_start()


func _back() -> void:
	Sfx.play("ui_back")
	if step == 0:
		Game.main.goto_title()
	else:
		step -= 1


func _start() -> void:
	Game.p1_char = IDS[sel[0]]
	Game.p2_char = IDS[sel[1]]
	Game.cpu_level = diff
	Game.main.start_fight()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var k: int = event.physical_keycode
		var pvp := Game.mode == Game.Mode.VS_PLAYER
		var p2_turn := step == 1 and pvp
		if k == KEY_ESCAPE:
			_back()
		elif p2_turn:
			if k == KEY_LEFT:
				_move_sel(-1)
			elif k == KEY_RIGHT:
				_move_sel(1)
			elif k in [KEY_KP_ENTER, KEY_KP_4, KEY_ENTER]:
				_confirm()
		else:
			if k in [KEY_A, KEY_LEFT]:
				_move_sel(-1)
			elif k in [KEY_D, KEY_RIGHT]:
				_move_sel(1)
			elif k in [KEY_ENTER, KEY_SPACE, KEY_KP_ENTER]:
				_confirm()
	elif event.is_action_pressed("ui_cancel"):
		_back()
	elif event is InputEventJoypadButton and event.pressed:
		if event.button_index == JOY_BUTTON_DPAD_LEFT:
			_move_sel(-1)
		elif event.button_index == JOY_BUTTON_DPAD_RIGHT:
			_move_sel(1)
		elif event.button_index == JOY_BUTTON_A:
			_confirm()
		elif event.button_index == JOY_BUTTON_B:
			_back()


func on_mouse(event: InputEvent) -> void:
	if event is InputEventMouseMotion and step < 2:
		for c in card_rects.size():
			if card_rects[c].has_point(event.position) and sel[_cur_player()] != c:
				sel[_cur_player()] = c
				Sfx.play("ui_move", -6)
				_refresh()
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			_back()
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if step >= 2:
				if Rect2(470, 520, 60, 50).has_point(event.position):
					_move_sel(-1)
				elif Rect2(750, 520, 60, 50).has_point(event.position):
					_move_sel(1)
				else:
					_confirm()
				return
			for c in card_rects.size():
				if card_rects[c].has_point(event.position):
					sel[_cur_player()] = c
					_refresh()
					_confirm()
					return


class SelectUI:
	extends Control
	var scr = null
	var t := 0.0

	func _process(dt: float) -> void:
		t += dt
		queue_redraw()

	func _gui_input(event: InputEvent) -> void:
		scr.on_mouse(event)

	func _txt(pos: Vector2, s: String, sz: int, col: Color, align := HORIZONTAL_ALIGNMENT_LEFT, w := -1.0, o := 6) -> void:
		var font: Font = Game.font_bold
		if o > 0:
			draw_string_outline(font, pos, s, align, w, sz, o, Color(0.08, 0.03, 0.12, col.a))
		draw_string(font, pos, s, align, w, sz, col)

	func _draw() -> void:
		var modes := {Game.Mode.VS_CPU: "БОЙ С ИИ", Game.Mode.VS_PLAYER: "ДВА ИГРОКА", Game.Mode.TRAINING: "ТРЕНИРОВКА"}
		_txt(Vector2(0, 58), "ВЫБОР БОЙЦА", 44, Color(1, 0.85, 0.92), HORIZONTAL_ALIGNMENT_CENTER, 1280, 10)
		_txt(Vector2(0, 86), modes.get(Game.mode, ""), 18, Color(1, 0.6, 0.8), HORIZONTAL_ALIGNMENT_CENTER, 1280, 5)
		for i in 2:
			_side(i)
		# center cards
		for c in scr.card_rects.size():
			var r: Rect2 = scr.card_rects[c]
			draw_rect(r.grow(2), Color(0.08, 0.03, 0.12), false, 3.0)
			var info: Dictionary = Game.char_info(scr.IDS[c])
			_txt(Vector2(r.position.x, r.end.y - 12), info["name"], 20, Color(1, 1, 1), HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 5)
			for p in 2:
				if scr.sel[p] == c and (p == 0 or scr.step >= 1):
					var col := Color(0.5, 0.95, 1.0) if p == 0 else Color(1, 0.5, 0.75)
					var active: bool = scr._cur_player() == p and scr.step < 2
					var g := 3.0 + (2.0 if active else 0.0) + (sin(t * 8.0) * 1.5 if active else 0.0)
					draw_rect(r.grow(g + p * 6), col, false, 3.0)
					var tag := "P1" if p == 0 else _p2_tag()
					_txt(Vector2(r.position.x + (0 if p == 0 else r.size.x - 60), r.position.y - 10 - p * 6), tag, 18, col, HORIZONTAL_ALIGNMENT_LEFT if p == 0 else HORIZONTAL_ALIGNMENT_RIGHT, 60, 5)
		# prompt
		var prompt := ""
		match scr.step:
			0:
				prompt = "ИГРОК 1: ВЫБЕРИ БОЙЦА"
			1:
				if Game.mode == Game.Mode.VS_PLAYER:
					prompt = "ИГРОК 2: ВЫБЕРИ БОЙЦА  (стрелки + NUM ENTER)"
				elif Game.mode == Game.Mode.TRAINING:
					prompt = "ВЫБЕРИ МАНЕКЕН"
				else:
					prompt = "ВЫБЕРИ ПРОТИВНИКА"
			2:
				prompt = "СЛОЖНОСТЬ ИИ"
		_txt(Vector2(0, 420), prompt, 24, Color(1, 0.92, 0.6, 0.75 + 0.25 * sin(t * 4.0)), HORIZONTAL_ALIGNMENT_CENTER, 1280, 6)
		if scr.step >= 2:
			var cols := [Color(0.6, 1, 0.7), Color(1, 0.9, 0.5), Color(1, 0.45, 0.45)]
			_txt(Vector2(470, 556), "<", 40, Color(1, 1, 1), HORIZONTAL_ALIGNMENT_CENTER, 60, 6)
			_txt(Vector2(750, 556), ">", 40, Color(1, 1, 1), HORIZONTAL_ALIGNMENT_CENTER, 60, 6)
			_txt(Vector2(530, 556), scr.DIFF[scr.diff], 34, cols[scr.diff], HORIZONTAL_ALIGNMENT_CENTER, 220, 8)
			_txt(Vector2(0, 620), "ENTER / ЛКМ - В БОЙ!", 26, Color(1, 0.6, 0.8, 0.7 + 0.3 * sin(t * 6.0)), HORIZONTAL_ALIGNMENT_CENTER, 1280, 6)
		_txt(Vector2(0, 706), "A/D или мышь - выбор    ENTER / ЛКМ - подтвердить    ESC / ПКМ - назад", 15, Color(0.85, 0.8, 0.95, 0.8), HORIZONTAL_ALIGNMENT_CENTER, 1280, 4)

	func _p2_tag() -> String:
		match Game.mode:
			Game.Mode.VS_PLAYER:
				return "P2"
			Game.Mode.TRAINING:
				return "МАНЕКЕН"
		return "ИИ"

	func _side(i: int) -> void:
		var id: String = scr.IDS[scr.sel[i]]
		var info: Dictionary = Game.char_info(id)
		var x := 40.0 if i == 0 else 910.0
		var w := 330.0
		var r: Rect2 = scr.big_rects[i]
		var col := Color(0.5, 0.95, 1.0) if i == 0 else Color(1, 0.5, 0.75)
		var active: bool = (i == 0 and scr.step == 0) or (i == 1 and scr.step == 1)
		var dim := 1.0 if (i == 0 or scr.step >= 1) else 0.45
		draw_rect(Rect2(r.position.x, r.end.y - 30, r.size.x, 34), Color(0.08, 0.03, 0.12, 0.5))
		draw_rect(Rect2(r.position.x, r.end.y + 2, r.size.x, 3), Color(col, dim))
		var y := r.end.y + 34.0
		var al := HORIZONTAL_ALIGNMENT_LEFT if i == 0 else HORIZONTAL_ALIGNMENT_RIGHT
		_txt(Vector2(x, y), info["name"], 36, Color(col, dim), al, w, 8)
		y += 24
		_txt(Vector2(x, y), info["title"] + "  -  " + info["type"], 17, Color(1, 0.9, 0.95, dim), al, w, 5)
		y += 22
		_txt(Vector2(x, y), "ЗДОРОВЬЕ: %d" % info["hp"], 16, Color(1, 0.85, 0.5, dim), al, w, 4)
		y += 22
		for p in info["pros"]:
			_txt(Vector2(x, y), "+ " + p, 14, Color(0.6, 1, 0.7, dim), al, w, 4)
			y += 18
		for c in info["cons"]:
			_txt(Vector2(x, y), "- " + c, 14, Color(1, 0.55, 0.55, dim), al, w, 4)
			y += 18
		y += 6
		for s in info["skills"]:
			_txt(Vector2(x, y), s[0] + "  " + s[1], 14, Color(1, 0.92, 0.6, dim), al, w, 4)
			y += 17
		if active:
			var pulse := 0.5 + 0.5 * sin(t * 6.0)
			draw_rect(r.grow(4), Color(col, 0.4 + 0.4 * pulse), false, 2.0)
