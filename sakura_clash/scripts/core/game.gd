extends Node
## Autoload "Game": match settings, character registry, input map, fonts.

enum Mode { VS_CPU, VS_PLAYER, TRAINING, CPU_VS_CPU }

const CHARACTERS := {
	"ronin": {
		"name": "РЭН",
		"title": "Странствующий ронин",
		"script": "res://scripts/fighters/ronin.gd",
		"type": "НАЗЕМНЫЙ",
		"hp": 1100,
		"desc": "Мастер иайдо. Двойной прыжок до самого потолка, прыжок от стен, бег и мощные удары катаной.",
		"pros": ["Больше здоровья", "Двойной прыжок и отскок от стен", "Сильные тяжёлые удары и контратака"],
		"cons": ["Не летает", "Один воздушный рывок за прыжок"],
		"skills": [
			["Q", "Сэнко", "Мгновенный рывок сквозь врага с отложенным разрезом", "Сэнко"],
			["E", "Цукикагэ", "Лунная волна - снаряд-полумесяц (целится мышью)", "Луна"],
			["R", "Кагами", "Стойка-контратака: ловит удар и отвечает разрезом", "Кагами"],
			["F", "Сэнбондзакура", "УЛЬТА: тысяча лепестков - шквал разрезов", "Сэнбон"],
		],
	},
	"tengu": {
		"name": "КАРАСУ",
		"title": "Вороний тэнгу",
		"script": "res://scripts/fighters/tengu.gd",
		"type": "ЛЕТАЮЩИЙ",
		"hp": 900,
		"desc": "Дух-ворон с веером бури. Свободный полёт, рывки в 8 сторон, ветер и молнии.",
		"pros": ["Свободный полёт и рывки во все стороны", "Дальние атаки перьями", "Удары молнией"],
		"cons": ["Меньше здоровья", "Выносливость полёта кончается", "Хрупкий в воздухе: +10% урона"],
		"skills": [
			["Q", "Кадзэ-но-Ханэ", "Веер из трёх перьев в сторону прицела", "Перья"],
			["E", "Ороси", "Смерч, который затягивает и подбрасывает", "Смерч"],
			["R", "Райко", "Громовой нырок в сторону прицела", "Райко"],
			["F", "Буря Райдзина", "УЛЬТА: град молний по противнику", "Буря"],
		],
	},
}

var mode: int = Mode.VS_CPU
var p1_char := "ronin"
var p2_char := "tengu"
var cpu_level := 1  # 0 easy, 1 normal, 2 hard
var music_volume := 0.7
var sfx_volume := 0.9
var show_hitboxes := false

var font_regular: Font
var font_bold: Font

## Command line flags used for automated testing.
var autotest := false
var autotest_time := 40.0
var screenshot_path := ""
var screenshot_time := 3.0
var start_scene := ""

var main = null  # scripts/main.gd instance


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	font_regular = load("res://assets/fonts/PixelifySans-500.ttf")
	font_bold = load("res://assets/fonts/PixelifySans-700.ttf")
	_setup_input()
	_parse_args()


func _parse_args() -> void:
	for a in OS.get_cmdline_user_args():
		if a == "--autotest":
			autotest = true
			mode = Mode.CPU_VS_CPU
		elif a.begins_with("--autotest-time="):
			autotest_time = float(a.split("=")[1])
		elif a.begins_with("--shot="):
			screenshot_path = a.split("=")[1]
		elif a.begins_with("--shot-time="):
			screenshot_time = float(a.split("=")[1])
		elif a.begins_with("--scene="):
			start_scene = a.split("=")[1]
		elif a.begins_with("--p1="):
			p1_char = a.split("=")[1]
		elif a.begins_with("--p2="):
			p2_char = a.split("=")[1]
		elif a == "--cpu":
			mode = Mode.CPU_VS_CPU
		elif a == "--training":
			mode = Mode.TRAINING
		elif a == "--hitboxes":
			show_hitboxes = true


func char_info(id: String) -> Dictionary:
	return CHARACTERS.get(id, CHARACTERS["ronin"])


# ------------------------------------------------------------------ input
func _key(action: String, keys: Array) -> void:
	for k in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		InputMap.action_add_event(action, ev)


func _mouse(action: String, buttons: Array) -> void:
	for b in buttons:
		var ev := InputEventMouseButton.new()
		ev.button_index = b
		InputMap.action_add_event(action, ev)


func _joy_btn(action: String, buttons: Array) -> void:
	for b in buttons:
		var ev := InputEventJoypadButton.new()
		ev.button_index = b
		ev.device = 0
		InputMap.action_add_event(action, ev)


func _joy_axis(action: String, axis: int, value: float) -> void:
	var ev := InputEventJoypadMotion.new()
	ev.axis = axis
	ev.axis_value = value
	ev.device = 0
	InputMap.action_add_event(action, ev)


func _add(action: String, deadzone := 0.4) -> void:
	if InputMap.has_action(action):
		InputMap.erase_action(action)
	InputMap.add_action(action, deadzone)


func _setup_input() -> void:
	# ---- Player 1: keyboard + mouse (physical keys -> layout independent)
	var p1 := {
		"left": [KEY_A], "right": [KEY_D], "up": [KEY_W], "down": [KEY_S],
		"jump": [KEY_SPACE], "dash": [KEY_SHIFT], "guard": [KEY_C, KEY_CTRL],
		"q": [KEY_Q], "e": [KEY_E], "r": [KEY_R], "f": [KEY_F], "throw": [KEY_V],
	}
	for a in p1:
		_add("p1_" + a)
		_key("p1_" + a, p1[a])
	_add("p1_light")
	_mouse("p1_light", [MOUSE_BUTTON_LEFT])
	_add("p1_heavy")
	_mouse("p1_heavy", [MOUSE_BUTTON_RIGHT])
	_mouse("p1_guard", [MOUSE_BUTTON_MIDDLE, MOUSE_BUTTON_XBUTTON1])

	# ---- Player 2: arrows + numpad
	var p2 := {
		"left": [KEY_LEFT], "right": [KEY_RIGHT], "up": [KEY_UP], "down": [KEY_DOWN],
		"jump": [KEY_KP_8, KEY_KP_ENTER], "dash": [KEY_KP_0], "guard": [KEY_KP_6],
		"light": [KEY_KP_4], "heavy": [KEY_KP_5], "throw": [KEY_KP_2],
		"q": [KEY_KP_7], "e": [KEY_KP_9], "r": [KEY_KP_1], "f": [KEY_KP_3],
	}
	for a in p2:
		_add("p2_" + a)
		_key("p2_" + a, p2[a])

	# ---- Gamepad (device 0)
	for a in ["left", "right", "up", "down", "jump", "dash", "guard", "light", "heavy", "throw", "q", "e", "r", "f"]:
		_add("pad_" + a, 0.35)
	_joy_axis("pad_left", JOY_AXIS_LEFT_X, -1.0)
	_joy_axis("pad_right", JOY_AXIS_LEFT_X, 1.0)
	_joy_axis("pad_up", JOY_AXIS_LEFT_Y, -1.0)
	_joy_axis("pad_down", JOY_AXIS_LEFT_Y, 1.0)
	_joy_btn("pad_left", [JOY_BUTTON_DPAD_LEFT])
	_joy_btn("pad_right", [JOY_BUTTON_DPAD_RIGHT])
	_joy_btn("pad_up", [JOY_BUTTON_DPAD_UP])
	_joy_btn("pad_down", [JOY_BUTTON_DPAD_DOWN])
	_joy_btn("pad_jump", [JOY_BUTTON_A])
	_joy_btn("pad_guard", [JOY_BUTTON_B])
	_joy_btn("pad_light", [JOY_BUTTON_X])
	_joy_btn("pad_heavy", [JOY_BUTTON_Y])
	_joy_btn("pad_dash", [JOY_BUTTON_RIGHT_SHOULDER])
	_joy_btn("pad_q", [JOY_BUTTON_LEFT_SHOULDER])
	_joy_axis("pad_e", JOY_AXIS_TRIGGER_LEFT, 1.0)
	_joy_axis("pad_r", JOY_AXIS_TRIGGER_RIGHT, 1.0)
	_joy_btn("pad_f", [JOY_BUTTON_RIGHT_STICK])
	_joy_btn("pad_throw", [JOY_BUTTON_LEFT_STICK])

	# ---- UI / system
	_add("pause")
	_key("pause", [KEY_ESCAPE])
	_joy_btn("pause", [JOY_BUTTON_START])
	_add("debug_hitboxes")
	_key("debug_hitboxes", [KEY_F1])
	_add("fullscreen")
	_key("fullscreen", [KEY_F11])
	_add("ui_confirm_alt")
	_key("ui_confirm_alt", [KEY_ENTER, KEY_SPACE, KEY_KP_ENTER])
	_joy_btn("ui_confirm_alt", [JOY_BUTTON_A])


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_hitboxes"):
		show_hitboxes = not show_hitboxes
	elif event.is_action_pressed("fullscreen"):
		var fs := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if fs else DisplayServer.WINDOW_MODE_FULLSCREEN)
