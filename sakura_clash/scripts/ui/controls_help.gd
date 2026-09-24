class_name ControlsHelp
extends Control
## Full-screen controls reference (Russian).

const LEFT := [
	["ДВИЖЕНИЕ", ""],
	["A / D", "ходьба влево / вправо"],
	["W / S", "вверх / вниз (полёт), S - присесть"],
	["ПРОБЕЛ", "прыжок, двойной прыжок, от стены"],
	["SHIFT + WASD", "рывок в сторону (у летуна - в 8 сторон)"],
	["2x НАЖАТЬ", "двойное нажатие направления = рывок"],
	["ДЕРЖАТЬ", "после рывка держи - бег/ускорение"],
	["SHIFT", "без направления - уклонение назад"],
	["SHIFT + W", "наземный: высокий прыжок"],
	["ЗАЩИТА", ""],
	["C / CTRL / КОЛЕСО", "держать - блок"],
	["ТАП ЗАЩИТЫ", "перед ударом - ПАРИРОВАНИЕ"],
	["РЫВОК В МОМЕНТ", "удара - ИДЕАЛЬНОЕ УКЛОНЕНИЕ"],
]
const RIGHT := [
	["АТАКА", ""],
	["ЛКМ", "лёгкий удар (цепочка до 4 ударов)"],
	["ПКМ", "тяжёлый удар (держи - заряд)"],
	["W / S + УДАР", "удар вверх (подброс) / вниз"],
	["БЕГ + ЛКМ", "атака на бегу / с ускорения"],
	["ЛКМ + ПКМ, V", "бросок (пробивает блок)"],
	["Q  E  R", "способности (прицел - мышью)"],
	["F", "ультимейт (шкала Ки 100%)"],
	["ПОПАЛ + SHIFT", "RUSH-отмена за 20 Ки"],
	["ПОДБРОС + ПРОБЕЛ", "прыжок-преследование"],
	["СИСТЕМА", ""],
	["ESC", "пауза"],
	["F1", "показать хитбоксы"],
	["F11", "полный экран"],
]
const P2 := "Игрок 2 (клавиатура): стрелки, NUM4 лёгкий, NUM5 тяжёлый, NUM6 блок, NUM8 прыжок, NUM0 рывок, NUM7/9/1 - Q/E/R, NUM3 - ульта"
const PAD := "Геймпад: стик/крестовина, A прыжок, X лёгкий, Y тяжёлый, B блок, RB рывок, LB/LT/RT - Q/E/R, R3 ульта, L3 бросок"

var t := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(dt: float) -> void:
	t += dt
	queue_redraw()


func _draw() -> void:
	var font: Font = Game.font_bold
	var fr: Font = Game.font_regular
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.05, 0.02, 0.08, 0.86))
	var panel := Rect2(70, 50, size.x - 140, size.y - 120)
	draw_rect(panel, Color(0.12, 0.06, 0.16, 0.95))
	draw_rect(panel, Color(1, 0.55, 0.75), false, 3.0)
	draw_string_outline(font, Vector2(panel.position.x, 100), "УПРАВЛЕНИЕ", HORIZONTAL_ALIGNMENT_CENTER, panel.size.x, 40, 8, Color(0.08, 0.03, 0.12))
	draw_string(font, Vector2(panel.position.x, 100), "УПРАВЛЕНИЕ", HORIZONTAL_ALIGNMENT_CENTER, panel.size.x, 40, Color(1, 0.8, 0.9))
	_col(LEFT, Vector2(panel.position.x + 30, 150), font, fr)
	_col(RIGHT, Vector2(panel.position.x + panel.size.x * 0.5 + 10, 150), font, fr)
	draw_string(fr, Vector2(panel.position.x + 30, panel.end.y - 52), P2, HORIZONTAL_ALIGNMENT_LEFT, panel.size.x - 60, 14, Color(0.75, 0.7, 0.85))
	draw_string(fr, Vector2(panel.position.x + 30, panel.end.y - 30), PAD, HORIZONTAL_ALIGNMENT_LEFT, panel.size.x - 60, 14, Color(0.75, 0.7, 0.85))
	draw_string(font, Vector2(0, size.y - 30), "ESC / ПРАВЫЙ КЛИК - назад", HORIZONTAL_ALIGNMENT_CENTER, size.x, 18, Color(0.9, 0.8, 0.95, 0.6 + 0.4 * sin(t * 4.0)))


func _col(rows: Array, at: Vector2, font: Font, fr: Font) -> void:
	var y := at.y
	for row in rows:
		if row[1] == "":
			y += 6
			draw_string(font, Vector2(at.x, y + 16), row[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(1, 0.6, 0.8))
			y += 30
			continue
		draw_string(font, Vector2(at.x, y + 14), row[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 0.92, 0.6))
		draw_string(fr, Vector2(at.x + 190, y + 14), row[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.92, 0.9, 0.96))
		y += 25
