extends Node
## Debug: renders every pose of a character in a grid (used for art tuning).
## Run: godot --path . -- --scene=gallery --p1=ronin --shot=out.png

var vp: SubViewport
var fighters: Array = []
var names: Array = []
const COLS := 7
const CW := 96
const CH := 110


func _ready() -> void:
	var id: String = Game.p1_char
	var info: Dictionary = Game.char_info(id)
	var script: Script = load(info["script"])
	var probe: Fighter = script.new()
	probe.setup_preview(false)
	names = probe.P.keys()
	probe.free()
	var rows := int(ceil(names.size() / float(COLS)))
	vp = SubViewport.new()
	vp.size = Vector2i(COLS * CW, rows * CH)
	vp.transparent_bg = true
	vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var root := Node2D.new()
	root.scale = Vector2.ONE / Cfg.PX
	vp.add_child(root)
	for i in names.size():
		var f: Fighter = script.new()
		f.position = Vector2((i % COLS) * CW + CW * 0.5, (i / COLS) * CH + CH - 22) * Cfg.PX
		root.add_child(f)
		f.setup_preview(false)
		f.pose = f.P[names[i]].duplicate()
		f.joints = f.compute_joints(f.pose)
		for c in f.chains:
			c.reset(f.local_to_world(f.joints.get(c.anchor_key, Vector2.ZERO)))
		for k in 90:
			f._update_chains(0.016)
		f.queue_redraw()
		fighters.append(f)
	var bg := ColorRect.new()
	bg.color = Color(0.35, 0.3, 0.4)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var tr := TextureRect.new()
	tr.texture = vp.get_texture()
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	tr.size = Vector2(1280, 1280.0 * vp.size.y / vp.size.x)
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/actor_outline.gdshader")
	tr.material = m
	add_child(tr)
	var sc := 1280.0 / vp.size.x
	for i in names.size():
		var l := Label.new()
		l.text = names[i]
		l.add_theme_font_size_override("font_size", 12)
		l.position = Vector2((i % COLS) * CW, (i / COLS) * CH) * sc
		add_child(l)
