class_name FighterPreview
extends SubViewport
## Low-res viewport that renders an animated fighter for menus.

const SHOWCASE := {
	"ronin": ["l1_b", "h_b", "upl_b", "l4_b", "win"],
	"tengu": ["palm_b", "l1_b", "upl_b", "buf_b", "storm"],
}

var fighter: Fighter = null
var root: Node2D
var char_id := ""
var t := 0.0
var show_t := 0.0
var show_pose := ""
var show_i := 0
var animate_showcase := true


func _init() -> void:
	size = Vector2i(110, 96)
	transparent_bg = true
	render_target_update_mode = SubViewport.UPDATE_ALWAYS
	canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	snap_2d_transforms_to_pixel = true
	disable_3d = true
	root = Node2D.new()
	root.scale = Vector2.ONE / Cfg.PX
	add_child(root)


func set_char(id: String, alt: bool, face: int) -> void:
	if fighter != null:
		fighter.queue_free()
	char_id = id
	var info: Dictionary = Game.char_info(id)
	var script: Script = load(info["script"])
	fighter = script.new()
	fighter.facing = face
	fighter.position = Vector2(size.x * 0.5, size.y - 6) * Cfg.PX
	if id == "tengu":
		fighter.position.y -= 10 * Cfg.PX
	root.add_child(fighter)
	fighter.setup_preview(alt)
	show_t = 1.5


func _process(dt: float) -> void:
	if fighter == null:
		return
	t += dt
	if animate_showcase:
		show_t -= dt
		if show_t <= 0.0:
			if show_pose == "":
				var arr: Array = SHOWCASE.get(char_id, [])
				if not arr.is_empty():
					show_pose = arr[show_i % arr.size()]
					show_i += 1
				show_t = 0.55
			else:
				show_pose = ""
				show_t = randf_range(1.8, 2.6)
	fighter.preview_tick(dt, show_pose)


func make_rect(px_size: Vector2) -> TextureRect:
	var tr := TextureRect.new()
	tr.texture = get_texture()
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.size = px_size
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/actor_outline.gdshader")
	tr.material = m
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tr
