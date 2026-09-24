extends Node
## Scene flow: title -> character select -> fight. Also handles automated
## test flags (--autotest, --shot=...).

var current: Node = null
var _shot_i := 0


func _ready() -> void:
	Game.main = self
	randomize()
	match Game.start_scene:
		"gallery":
			_swap(load("res://tools/gallery.gd").new())
		"help":
			var l := CanvasLayer.new()
			l.add_child(ControlsHelp.new())
			_swap(l)
		"inputtest":
			_swap(load("res://tools/input_test.gd").new())
		"fight":
			start_fight()
		"select":
			goto_select()
		_:
			if Game.autotest:
				start_fight()
			else:
				goto_title()
	if Game.screenshot_path != "":
		_schedule_shots()
	if Game.autotest:
		get_tree().create_timer(Game.autotest_time, true, true).timeout.connect(func():
			print("AUTOTEST DONE")
			get_tree().quit())


func _schedule_shots() -> void:
	var count := 1
	var interval := 0.5
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot-count="):
			count = int(a.split("=")[1])
		elif a.begins_with("--shot-interval="):
			interval = float(a.split("=")[1])
	for i in count:
		get_tree().create_timer(Game.screenshot_time + i * interval, true, true).timeout.connect(_take_shot.bind(i, count))


func _take_shot(i: int, count: int) -> void:
	var img := get_viewport().get_texture().get_image()
	var path := Game.screenshot_path
	if count > 1:
		path = path.get_basename() + "_%02d.png" % i
	img.save_png(path)
	print("saved ", path)
	if i == count - 1 and not Game.autotest:
		get_tree().quit()


func _swap(n: Node) -> void:
	if current != null:
		current.queue_free()
	current = n
	add_child(n)


func goto_title() -> void:
	_swap(TitleScreen.new())


func goto_select() -> void:
	_swap(SelectScreen.new())


func start_fight() -> void:
	var a := Arena.new()
	_swap(a)
