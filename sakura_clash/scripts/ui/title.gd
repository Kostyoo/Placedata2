class_name TitleScreen
extends Node
## Main menu over an AI-vs-AI attract-mode fight.

var demo: Arena
var layer: CanvasLayer
var logo: Control
var menu: MenuList
var help: ControlsHelp
var t := 0.0

const MUSIC_STEPS := [0.0, 0.35, 0.7, 1.0]


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	demo = Arena.new()
	demo.demo = true
	add_child(demo)
	layer = CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	logo = TitleLogo.new()
	logo.set_anchors_preset(Control.PRESET_FULL_RECT)
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(logo)
	var panel := ColorRect.new()
	panel.color = Color(0.06, 0.02, 0.1, 0.62)
	panel.position = Vector2(640 - 250, 302)
	panel.size = Vector2(500, 340)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(panel)
	var edge := ColorRect.new()
	edge.color = Color(1, 0.55, 0.75, 0.8)
	edge.position = Vector2(640 - 250, 302)
	edge.size = Vector2(500, 3)
	edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(edge)
	var edge2 := edge.duplicate()
	edge2.position = Vector2(640 - 250, 639)
	layer.add_child(edge2)
	menu = MenuList.new([], 28)
	menu.position = Vector2(640 - 230, 318)
	menu.size = Vector2(460, 340)
	menu.chosen.connect(_on_choice)
	layer.add_child(menu)
	_refresh_items()
	help = ControlsHelp.new()
	help.visible = false
	layer.add_child(help)


func _refresh_items() -> void:
	menu.set_items([
		"Бой с ИИ",
		"Два игрока",
		"Тренировка",
		"Управление",
		"Музыка: %d%%" % int(Game.music_volume * 100),
		"Звуки: %d%%" % int(Game.sfx_volume * 100),
		"Выход",
	])
	menu.item_h = 44.0
	menu.size = Vector2(460, 44.0 * 7)


func _on_choice(i: int) -> void:
	match i:
		0:
			Game.mode = Game.Mode.VS_CPU
			Game.main.goto_select()
		1:
			Game.mode = Game.Mode.VS_PLAYER
			Game.main.goto_select()
		2:
			Game.mode = Game.Mode.TRAINING
			Game.main.goto_select()
		3:
			help.visible = true
			menu.active = false
		4:
			Game.music_volume = _next_step(Game.music_volume)
			Sfx.apply_volumes()
			_refresh_items()
		5:
			Game.sfx_volume = _next_step(Game.sfx_volume)
			Sfx.apply_volumes()
			_refresh_items()
		6:
			get_tree().quit()


func _next_step(v: float) -> float:
	for s in MUSIC_STEPS:
		if s > v + 0.01:
			return s
	return 0.0


func _unhandled_input(event: InputEvent) -> void:
	if help.visible:
		var back := event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel")
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
			back = true
		if back:
			help.visible = false
			menu.active = true
			Sfx.play("ui_back")
			get_viewport().set_input_as_handled()


class TitleLogo:
	extends Control
	var t := 0.0

	func _process(dt: float) -> void:
		t += dt
		queue_redraw()

	func _draw() -> void:
		var font: Font = Game.font_bold
		var out := Color(0.08, 0.03, 0.12)
		var k := Pose.ease_out(minf(1.0, t * 1.5), 3.0)
		# rising sun disc
		var c := Vector2(640, 170)
		draw_circle(c, 118.0 * k, Color(0.85, 0.2, 0.32, 0.85))
		draw_circle(c, 104.0 * k, Color(0.95, 0.3, 0.4, 0.9))
		for i in 7:
			draw_rect(Rect2(c.x - 130, c.y + 20 + i * 14, 260, 5), Color(0.08, 0.03, 0.12, 0.35 + i * 0.05))
		# katana slash through the title
		var sl := Pose.ease_out(clampf((t - 0.3) * 3.0, 0.0, 1.0), 2.0)
		var a := Vector2(300, 250)
		var b := Vector2(980, 90)
		draw_line(a, a.lerp(b, sl), Color(0.55, 0.95, 1.0, 0.5), 10)
		draw_line(a, a.lerp(b, sl), Color(1, 1, 1, 0.95), 3)
		var y := 175.0 + (1.0 - k) * -60.0
		var title := "SAKURA CLASH"
		for off in [Vector2(6, 6)]:
			draw_string(font, Vector2(0, y) + off, title, HORIZONTAL_ALIGNMENT_CENTER, 1280, 104, Color(0.08, 0.03, 0.12, 0.7 * k))
		draw_string_outline(font, Vector2(0, y), title, HORIZONTAL_ALIGNMENT_CENTER, 1280, 104, 16, Color(out, k))
		draw_string(font, Vector2(0, y), title, HORIZONTAL_ALIGNMENT_CENTER, 1280, 104, Color(1, 0.86, 0.93, k))
		draw_string(font, Vector2(0, y - 4), title, HORIZONTAL_ALIGNMENT_CENTER, 1280, 104, Color(1, 1, 1, 0.25 * k))
		var sub := "ПИКСЕЛЬНЫЙ АНИМЕ-ФАЙТИНГ  -  ДУЭЛЬ ПОД САКУРОЙ"
		draw_string_outline(font, Vector2(0, 232), sub, HORIZONTAL_ALIGNMENT_CENTER, 1280, 22, 8, Color(out, k))
		draw_string(font, Vector2(0, 232), sub, HORIZONTAL_ALIGNMENT_CENTER, 1280, 22, Color(1, 0.65, 0.8, k))
		draw_string_outline(font, Vector2(0, 704), "W/S или мышь - выбор   ENTER / ЛКМ - подтвердить", HORIZONTAL_ALIGNMENT_CENTER, 1280, 16, 6, out)
		draw_string(font, Vector2(0, 704), "W/S или мышь - выбор   ENTER / ЛКМ - подтвердить", HORIZONTAL_ALIGNMENT_CENTER, 1280, 16, Color(0.9, 0.85, 1, 0.6 + 0.3 * sin(t * 3.0)))
