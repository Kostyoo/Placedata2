class_name MenuList
extends Control
## Small keyboard / mouse / gamepad menu drawn in the game's pixel style.

signal chosen(idx: int)

var items: Array = []
var sel := 0
var font_size := 30
var item_h := 48.0
var active := true
var accent := Color(1.0, 0.55, 0.75)
var t := 0.0
var _hover := -1


func _init(p_items: Array = [], p_size := 30) -> void:
	items = p_items
	font_size = p_size
	item_h = p_size * 1.6
	mouse_filter = Control.MOUSE_FILTER_STOP


func _ready() -> void:
	custom_minimum_size = Vector2(420, item_h * items.size())
	size = custom_minimum_size


func set_items(p_items: Array) -> void:
	items = p_items
	sel = clampi(sel, 0, items.size() - 1)
	custom_minimum_size = Vector2(size.x, item_h * items.size())
	size = custom_minimum_size


func _process(dt: float) -> void:
	t += dt
	queue_redraw()


func _item_rect(i: int) -> Rect2:
	return Rect2(0, i * item_h, size.x, item_h)


func _gui_input(event: InputEvent) -> void:
	if not active:
		return
	if event is InputEventMouseMotion:
		for i in items.size():
			if _item_rect(i).has_point(event.position):
				if sel != i:
					sel = i
					Sfx.play("ui_move", -6)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		for i in items.size():
			if _item_rect(i).has_point(event.position):
				sel = i
				_choose()
				accept_event()


func _unhandled_input(event: InputEvent) -> void:
	if not active or not is_visible_in_tree():
		return
	var up := event.is_action_pressed("ui_up")
	var down := event.is_action_pressed("ui_down")
	var ok := event.is_action_pressed("ui_accept")
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_W:
				up = true
			KEY_S:
				down = true
			KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
				ok = true
	if up:
		sel = (sel - 1 + items.size()) % items.size()
		Sfx.play("ui_move", -6)
		get_viewport().set_input_as_handled()
	elif down:
		sel = (sel + 1) % items.size()
		Sfx.play("ui_move", -6)
		get_viewport().set_input_as_handled()
	elif ok:
		get_viewport().set_input_as_handled()
		_choose()


func _choose() -> void:
	Sfx.play("ui_ok", -4)
	emit_signal("chosen", sel)


func _draw() -> void:
	var font: Font = Game.font_bold
	for i in items.size():
		var r := _item_rect(i)
		var s: bool = i == sel and active
		var txt: String = items[i]
		var tw := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		var x := (r.size.x - tw) * 0.5
		var y := r.position.y + r.size.y * 0.5 + font_size * 0.35
		if s:
			var pulse := 0.5 + 0.5 * sin(t * 6.0)
			var bw := tw + 60.0
			var bx := (r.size.x - bw) * 0.5
			var br := Rect2(bx, r.position.y + 6, bw, r.size.y - 12)
			draw_rect(br, Color(0.08, 0.03, 0.12, 0.75))
			draw_rect(Rect2(br.position, Vector2(br.size.x, 3)), accent)
			draw_rect(Rect2(br.position + Vector2(0, br.size.y - 3), Vector2(br.size.x, 3)), accent)
			var ax := bx - 6.0 - pulse * 6.0
			var cy := r.position.y + r.size.y * 0.5
			draw_colored_polygon(PackedVector2Array([Vector2(ax, cy - 8), Vector2(ax + 10, cy), Vector2(ax, cy + 8)]), accent)
			draw_colored_polygon(PackedVector2Array([Vector2(bx + bw + 6 + pulse * 6.0, cy - 8), Vector2(bx + bw - 4 + pulse * 6.0, cy), Vector2(bx + bw + 6 + pulse * 6.0, cy + 8)]), accent)
		draw_string_outline(font, Vector2(x, y), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 8, Color(0.08, 0.03, 0.12, 0.9))
		draw_string(font, Vector2(x, y), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(1, 1, 1) if s else Color(0.8, 0.74, 0.86))
