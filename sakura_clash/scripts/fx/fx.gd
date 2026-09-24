class_name FX
extends Node2D
## Pixel-layer visual effects. This node lives in the FRONT pixel layer and
## owns a second drawer (`back`) for effects behind the fighters.
## All coordinates are world units; the layer is rendered at 1/PX scale.

const PX := Cfg.PX

var arena = null
var back: Node2D = null
var pixel_font: Font

var sparks: Array = []
var rings: Array = []
var stars: Array = []
var slashes: Array = []
var lines: Array = []
var texts: Array = []
var bolts: Array = []
var gusts: Array = []
var shocks: Array = []
var feathers: Array = []
var barrier: Array = []
# back layer
var dusts: Array = []
var afters: Array = []
var back_rings: Array = []


class BackDrawer:
	extends Node2D
	var fx = null

	func _draw() -> void:
		if fx != null:
			fx.draw_back(self)


func _ready() -> void:
	pixel_font = Game.font_bold.duplicate()
	pixel_font.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	pixel_font.hinting = TextServer.HINTING_NONE
	pixel_font.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED


func make_back() -> Node2D:
	back = BackDrawer.new()
	back.fx = self
	return back


# ================================================================ spawning API
func dust(p: Vector2, n: int, dirx: float, scale := 1.0) -> void:
	for i in n:
		var v := Vector2(randf_range(40, 160) * dirx + randf_range(-60, 60), randf_range(-90, -20)) * scale
		dusts.append({"p": p + Vector2(randf_range(-14, 14), randf_range(-6, 0)), "v": v, "r": randf_range(6, 12) * scale,
			"life": randf_range(0.35, 0.6), "max": 0.6, "col": Color(0.62, 0.5, 0.62)})


func ring(p: Vector2, col: Color, r0: float, r1: float, life: float, w: float, _unused := 0.0) -> void:
	rings.append({"p": p, "col": col, "r0": r0, "r1": r1, "life": life, "max": life, "w": w})


func text(p: Vector2, t: String, col: Color, size_kind: int) -> void:
	var sz := 11
	match size_kind:
		1:
			sz = 13
		2:
			sz = 16
		3:
			sz = 20
	texts.append({"p": p, "t": t, "col": col, "sz": sz, "life": 0.9 if size_kind < 2 else 1.2, "max": 1.0, "v": Vector2(randf_range(-20, 20), -110)})


func damage_number(p: Vector2, dmg: float, col: Color) -> void:
	var sz := 11 if dmg < 40 else (13 if dmg < 90 else 16)
	texts.append({"p": p + Vector2(randf_range(-20, 20), 0), "t": str(int(round(dmg))), "col": col, "sz": sz, "life": 0.7, "max": 0.7, "v": Vector2(randf_range(-40, 40), -220), "g": 500.0})


func afterimage(f, col: Color, life: float, at = null) -> void:
	if afters.size() > 40:
		afters.pop_front()
	afters.append({"f": f, "pose": f.pose.duplicate(), "joints": f.joints.duplicate(), "pos": f.position if at == null else at,
		"facing": f.facing, "col": col, "life": life, "max": life})


func slash(f, sl: Dictionary) -> void:
	var life: float = sl.get("life", 0.16)
	var c: Vector2 = sl.get("c", Vector2(0, -40))
	slashes.append({"f": f, "sl": sl, "life": life, "max": life, "facing": f.facing,
		"origin": f.position + Vector2(c.x * f.facing, c.y) * PX, "col": sl.get("col", f.fx_color)})
	if sl.get("wind", false):
		for i in 4:
			var a := deg_to_rad(randf_range(float(sl.get("a0", -90)), float(sl.get("a1", 90))))
			var d := Vector2(cos(a) * f.facing, sin(a))
			spark(f.position + Vector2(c.x * f.facing, c.y) * PX + d * float(sl.get("r", 24)) * PX, d * 300.0, Color(1, 1, 1, 0.8), 3.0, 0.25, true)


func spark(p: Vector2, v: Vector2, col: Color, size: float, life: float, streak := false, grav := 0.0) -> void:
	if sparks.size() > 400:
		return
	sparks.append({"p": p, "v": v, "col": col, "size": size, "life": life, "max": life, "streak": streak, "g": grav})


func hit_spark(p: Vector2, dir: int, kind: String, col: Color, strength: int) -> void:
	var s := 1.0 + 0.35 * strength
	match kind:
		"slash":
			var a := randf_range(-0.9, -0.3) if randf() < 0.5 else randf_range(0.3, 0.9)
			var d := Vector2(cos(a) * dir, sin(a))
			lines.append({"a": p - d * 60 * s, "b": p + d * 60 * s, "col": col, "life": 0.14, "max": 0.14, "w": 9.0 * s})
			_burst(p, dir, col, int(6 * s), 520.0 * s, true)
			stars.append({"p": p, "col": Color.WHITE, "size": 26 * s, "life": 0.1, "max": 0.1, "rot": randf() * PI})
		"wind":
			ring(p, Color(col, 0.9), 12, 70 * s, 0.25, 4)
			ring(p, Color(1, 1, 1, 0.7), 6, 44 * s, 0.18, 3)
			_burst(p, dir, Color(1, 1, 1), int(5 * s), 420.0 * s, true)
			stars.append({"p": p, "col": Color.WHITE, "size": 22 * s, "life": 0.09, "max": 0.09, "rot": 0.0})
		"lightning":
			for i in 4:
				zap(p, col, 70.0 * s)
			stars.append({"p": p, "col": Color(1, 1, 0.9), "size": 36 * s, "life": 0.12, "max": 0.12, "rot": randf() * PI})
			_burst(p, dir, col, int(8 * s), 600.0, true)
			ring(p, Color(col, 0.9), 10, 90 * s, 0.25, 5)
		"heavy":
			stars.append({"p": p, "col": Color.WHITE, "size": 44 * s, "life": 0.13, "max": 0.13, "rot": randf() * PI})
			ring(p, Color(col, 0.95), 16, 120 * s, 0.3, 7)
			ring(p, Color(1, 1, 1, 0.8), 8, 70 * s, 0.2, 4)
			_burst(p, dir, col, int(10 * s), 700.0, true)
			_burst(p, dir, Color(1, 0.95, 0.9), 6, 420.0, false)
		"ult":
			stars.append({"p": p, "col": Color.WHITE, "size": 90, "life": 0.25, "max": 0.25, "rot": 0.0})
			for i in 3:
				ring(p, Color(col, 0.9), 20 + i * 20, 220 + i * 80, 0.4 + i * 0.12, 8 - i * 2)
			_burst(p, dir, col, 24, 900.0, true)
		_:
			stars.append({"p": p, "col": Color.WHITE, "size": 28 * s, "life": 0.1, "max": 0.1, "rot": randf() * PI})
			ring(p, Color(col, 0.8), 8, 50 * s, 0.16, 3)
			_burst(p, dir, col, int(6 * s), 460.0 * s, true)


func _burst(p: Vector2, dir: int, col: Color, n: int, speed: float, streak: bool) -> void:
	for i in n:
		var a := randf_range(-1.1, 1.1)
		var d := Vector2(cos(a) * dir, sin(a))
		if randf() < 0.3:
			d = Vector2.from_angle(randf() * TAU)
		spark(p, d * speed * randf_range(0.4, 1.0), col if randf() < 0.7 else Color.WHITE, randf_range(3, 6), randf_range(0.18, 0.34), streak, 600.0)


func block_spark(p: Vector2, dir: int) -> void:
	var col := Color(0.6, 0.85, 1.0)
	shocks.append({"type": "hex", "p": p, "col": col, "life": 0.22, "max": 0.22, "dir": dir})
	_burst(p, -dir, col, 5, 380.0, true)


func parry_flash(p: Vector2, col: Color) -> void:
	stars.append({"p": p, "col": Color(1, 1, 0.85), "size": 70, "life": 0.2, "max": 0.2, "rot": PI * 0.25})
	ring(p, Color(1, 0.9, 0.5, 1.0), 10, 150, 0.35, 7)
	ring(p, Color(col, 0.9), 6, 90, 0.25, 4)
	for i in 14:
		var d := Vector2.from_angle(TAU * i / 14.0)
		spark(p, d * 700.0, Color(1, 0.92, 0.6), 4.0, 0.3, true)


func guard_break_fx(p: Vector2) -> void:
	for i in 18:
		var d := Vector2.from_angle(randf() * TAU)
		spark(p, d * randf_range(200, 700), Color(0.6, 0.85, 1.0), randf_range(4, 8), randf_range(0.3, 0.6), false, 900.0)
	ring(p, Color(0.6, 0.85, 1.0, 1.0), 20, 160, 0.4, 6)
	stars.append({"p": p, "col": Color.WHITE, "size": 60, "life": 0.18, "max": 0.18, "rot": 0.0})


func line_flash(a: Vector2, b: Vector2, col: Color, life: float) -> void:
	lines.append({"a": a, "b": b, "col": col, "life": life, "max": life, "w": 12.0})


func lightning(a: Vector2, b: Vector2, col: Color, life: float, w := 3.0) -> void:
	bolts.append({"a": a, "b": b, "col": col, "life": life, "max": life, "w": w, "pts": _jagged(a, b, 12, 26.0), "t": 0.0})


func zap(p: Vector2, col: Color, radius: float) -> void:
	var a := p + Vector2.from_angle(randf() * TAU) * radius * randf_range(0.3, 1.0)
	var b := p + Vector2.from_angle(randf() * TAU) * radius * randf_range(0.3, 1.0)
	bolts.append({"a": a, "b": b, "col": col, "life": 0.08, "max": 0.08, "w": 3.0, "pts": _jagged(a, b, 4, 10.0), "t": 0.0})


func _jagged(a: Vector2, b: Vector2, n: int, amp: float) -> PackedVector2Array:
	var pts := PackedVector2Array([a])
	var d := b - a
	var nrm := Vector2(-d.y, d.x).normalized()
	for i in range(1, n):
		var t := float(i) / float(n)
		pts.append(a + d * t + nrm * randf_range(-amp, amp))
	pts.append(b)
	return pts


func speed_burst(p: Vector2, d: Vector2, col: Color) -> void:
	for i in 5:
		var off := Vector2(-d.y, d.x) * randf_range(-50, 50)
		spark(p + off - d * randf_range(0, 40), -d * randf_range(300, 600), Color(col, 0.8) if i % 2 else Color(1, 1, 1, 0.7), 3.0, 0.18, true)


func charge_spark(p: Vector2, col: Color, k: float) -> void:
	for i in 3:
		var d := Vector2.from_angle(randf() * TAU)
		var start := p + d * randf_range(60, 100)
		spark(start, -d * 360.0, col if randf() < 0.6 else Color(1, 1, 1), 3.0 + k * 2.0, 0.22, true)


func aura_spark(f, col: Color) -> void:
	var p: Vector2 = f.position + Vector2(randf_range(-30, 30), -randf_range(10, f.body_h * PX))
	spark(p, Vector2(randf_range(-20, 20), randf_range(-160, -80)), col, 3.0, 0.5, false, -50.0)


func petal_burst(p: Vector2, n: int, v: Vector2) -> void:
	if arena != null and arena.petals != null:
		arena.petals.burst(p, n, v)


func shockwave(p: Vector2, col: Color) -> void:
	shocks.append({"type": "ground", "p": p, "col": col, "life": 0.45, "max": 0.45, "dir": 1})
	for i in 14:
		var d := Vector2(randf_range(-1, 1), randf_range(-1.4, -0.3)).normalized()
		spark(p, d * randf_range(250, 650), Color(0.6, 0.5, 0.6) if i % 2 else Color(col, 0.9), randf_range(4, 7), randf_range(0.4, 0.7), false, 1600.0)
	dust(p, 10, 0, 1.6)


func gust(p: Vector2, dir: int, col: Color, power: float) -> void:
	gusts.append({"type": "gust", "p": p, "dir": dir, "col": col, "life": 0.35, "max": 0.35, "pow": power})
	for i in int(8 * power):
		spark(p + Vector2(0, randf_range(-60, 60)), Vector2(dir * randf_range(500, 1000), randf_range(-60, 60)), Color(1, 1, 1, 0.8), 3.0, 0.3, true)


func updraft(p: Vector2, col: Color) -> void:
	gusts.append({"type": "updraft", "p": p, "dir": 1, "col": col, "life": 0.45, "max": 0.45, "pow": 1.0})


func feather(p: Vector2, col: Color) -> void:
	if feathers.size() > 30:
		return
	feathers.append({"p": p, "v": Vector2(randf_range(-40, 40), 30), "rot": randf() * TAU, "ph": randf() * TAU, "life": 2.5, "max": 2.5, "col": col})


func barrier_hit(p: Vector2, normal: Vector2, strength: float) -> void:
	barrier.append({"p": p, "n": normal, "life": 0.5, "max": 0.5, "s": strength})


# ================================================================ update
func tick(dt: float) -> void:
	_age(sparks, dt)
	for s in sparks:
		s["v"] = (s["v"] as Vector2) * pow(0.02, dt) + Vector2(0, s["g"] * dt)
		s["p"] = (s["p"] as Vector2) + (s["v"] as Vector2) * dt
	_age(rings, dt)
	_age(stars, dt)
	_age(slashes, dt)
	_age(lines, dt)
	_age(texts, dt)
	for t in texts:
		t["p"] = (t["p"] as Vector2) + (t["v"] as Vector2) * dt
		t["v"] = (t["v"] as Vector2) * pow(0.1, dt) + Vector2(0, t.get("g", 0.0) * dt)
	_age(bolts, dt)
	for b in bolts:
		b["t"] += dt
		if b["t"] > 0.04:
			b["t"] = 0.0
			b["pts"] = _jagged(b["a"], b["b"], (b["pts"] as PackedVector2Array).size() - 1, 22.0 if b["max"] > 0.1 else 10.0)
	_age(gusts, dt)
	_age(shocks, dt)
	_age(feathers, dt)
	for f in feathers:
		f["ph"] += dt * 3.0
		f["p"] = (f["p"] as Vector2) + Vector2(sin(f["ph"]) * 50.0 - 20.0, 45.0) * dt
		f["rot"] = sin(f["ph"]) * 0.8
	_age(barrier, dt)
	_age(dusts, dt)
	for d in dusts:
		d["v"] = (d["v"] as Vector2) * pow(0.05, dt)
		d["p"] = (d["p"] as Vector2) + (d["v"] as Vector2) * dt
	_age(afters, dt)
	queue_redraw()
	if back != null:
		back.queue_redraw()


func _age(arr: Array, dt: float) -> void:
	var i := arr.size() - 1
	while i >= 0:
		arr[i]["life"] -= dt
		if arr[i]["life"] <= 0.0:
			arr.remove_at(i)
		i -= 1


# ================================================================ drawing
func _draw() -> void:
	for g in gusts:
		_draw_gust(g)
	for s in slashes:
		_draw_slash(s)
	for l in lines:
		var k: float = l["life"] / l["max"]
		var col: Color = l["col"]
		var w: float = l["w"] * (0.4 + 0.6 * k)
		draw_line(l["a"], l["b"], Color(col, 0.45 * k), w * 1.8)
		draw_line(l["a"], l["b"], Color(col, 0.95 * k), w)
		draw_line(l["a"], l["b"], Color(1, 1, 1, k), maxf(3.0, w * 0.35))
	for b in bolts:
		var k: float = b["life"] / b["max"]
		var col: Color = b["col"]
		draw_polyline(b["pts"], Color(col, 0.35 * k), b["w"] * 4.0)
		draw_polyline(b["pts"], Color(col, k), b["w"] * 1.6)
		draw_polyline(b["pts"], Color(1, 1, 1, k), maxf(3.0, b["w"]))
	for r in rings:
		var k: float = 1.0 - r["life"] / r["max"]
		var rad: float = lerpf(r["r0"], r["r1"], Pose.ease_out(k, 2.5))
		var col: Color = r["col"]
		var w: float = maxf(3.0, r["w"] * PX * 0.5 * (1.0 - k))
		draw_arc(r["p"], rad, 0, TAU, 28, Color(col, col.a * (1.0 - k)), w)
	for s in shocks:
		_draw_shock(s)
	for s in stars:
		var k: float = s["life"] / s["max"]
		_star(s["p"], s["size"] * (0.6 + 0.6 * k), s["rot"], Color(s["col"], k))
	for s in sparks:
		var k: float = s["life"] / s["max"]
		var col: Color = s["col"]
		col.a *= minf(1.0, k * 1.5)
		var p: Vector2 = s["p"]
		var sz: float = s["size"] * PX * 0.5
		if s["streak"]:
			var v: Vector2 = s["v"]
			draw_line(p, p - v * 0.04, col, maxf(3.0, sz * 0.8))
		else:
			draw_rect(Rect2(p - Vector2(sz, sz) * 0.5, Vector2(sz, sz)), col)
	for f in feathers:
		_draw_feather(f)
	for b in barrier:
		_draw_barrier(b)
	for t in texts:
		var k: float = t["life"] / t["max"]
		var col: Color = t["col"]
		col.a = clampf(k * 2.0, 0.0, 1.0)
		var sz: int = t["sz"]
		var p: Vector2 = t["p"]
		draw_set_transform(p, 0.0, Vector2(PX, PX))
		var w := pixel_font.get_string_size(t["t"], HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x
		var o := Vector2(-w * 0.5, 0)
		for off in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
			draw_string(pixel_font, o + off, t["t"], HORIZONTAL_ALIGNMENT_LEFT, -1, sz, Color(0.08, 0.03, 0.12, col.a))
		draw_string(pixel_font, o, t["t"], HORIZONTAL_ALIGNMENT_LEFT, -1, sz, col)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if Game.show_hitboxes and arena != null:
		arena.draw_debug(self)


func _star(p: Vector2, size: float, rot: float, col: Color) -> void:
	var pts := PackedVector2Array()
	var n := 8
	for i in n * 2:
		var r := size if i % 2 == 0 else size * 0.18
		if i % 4 == 2:
			r = size * 0.55
		pts.append(p + Vector2.from_angle(rot + PI * i / n) * r)
	draw_colored_polygon(pts, col)
	draw_circle(p, size * 0.22, Color(1, 1, 1, col.a))


func _draw_slash(s: Dictionary) -> void:
	var sl: Dictionary = s["sl"]
	var f = s["f"]
	var k: float = 1.0 - s["life"] / s["max"]
	var col: Color = s["col"]
	var facing: int = s["facing"]
	var c: Vector2 = sl.get("c", Vector2(0, -40))
	var origin: Vector2 = s["origin"]
	if is_instance_valid(f) and sl.get("follow", true):
		origin = f.position + Vector2(c.x * facing, c.y) * PX
	var typ: String = sl.get("type", "arc")
	var w: float = float(sl.get("w", 6)) * PX
	var fade := 1.0 - Pose.ease_in_out(clampf((k - 0.35) / 0.65, 0.0, 1.0))
	if typ == "thrust":
		var ln: float = float(sl.get("len", 50)) * PX
		var head := origin + Vector2(facing * ln * Pose.ease_out(minf(1.0, k * 3.0), 2.0), 0)
		var tail := origin + Vector2(facing * ln * maxf(0.0, k * 1.6 - 0.4), 0)
		var nrm := Vector2(0, w * 0.5 * fade)
		var poly := PackedVector2Array([tail, head.lerp(tail, 0.3) + nrm, head + Vector2(facing * 20, 0), head.lerp(tail, 0.3) - nrm])
		if (head - tail).length() > 6.0:
			draw_colored_polygon(poly, Color(col, 0.85 * fade))
			draw_line(tail, head + Vector2(facing * 14, 0), Color(1, 1, 1, fade), maxf(3.0, w * 0.3))
		return
	var r: float = float(sl.get("r", 26)) * PX
	var a0: float
	var a1: float
	if typ == "circle":
		a0 = -90.0
		a1 = 270.0
	else:
		a0 = float(sl.get("a0", -90))
		a1 = float(sl.get("a1", 60))
	var sweep := Pose.ease_out(minf(1.0, k * 2.6), 2.0)
	var head_a := lerpf(a0, a1, sweep)
	var tail_a := lerpf(a0, a1, clampf(k * 2.6 - 0.9, 0.0, 1.0) * 0.85)
	if absf(head_a - tail_a) < 2.0:
		return
	var n := 16
	var outer := PackedVector2Array()
	var inner := PackedVector2Array()
	for i in n + 1:
		var t := float(i) / float(n)
		var a := deg_to_rad(lerpf(tail_a, head_a, t))
		var d := Vector2(cos(a) * facing, sin(a))
		var th := w * (0.15 + 0.85 * t) * fade
		outer.append(origin + d * (r + th * 0.5))
		inner.append(origin + d * (r - th * 0.5))
	var poly := PackedVector2Array(outer)
	for i in range(inner.size() - 1, -1, -1):
		poly.append(inner[i])
	var glow := PackedVector2Array()
	for i in n + 1:
		var t := float(i) / float(n)
		var a := deg_to_rad(lerpf(tail_a, head_a, t))
		var d := Vector2(cos(a) * facing, sin(a))
		glow.append(origin + d * (r + w * 0.9 * t * fade))
	for i in range(n, -1, -1):
		var t := float(i) / float(n)
		var a := deg_to_rad(lerpf(tail_a, head_a, t))
		var d := Vector2(cos(a) * facing, sin(a))
		glow.append(origin + d * (r - w * 0.7 * t * fade))
	_poly(glow, Color(col, 0.28 * fade))
	_poly(poly, Color(col, 0.9 * fade))
	# bright core line near the outer edge
	var core := PackedVector2Array()
	for i in range(n / 3, n + 1):
		var t := float(i) / float(n)
		var a := deg_to_rad(lerpf(tail_a, head_a, t))
		var d := Vector2(cos(a) * facing, sin(a))
		core.append(origin + d * (r + w * 0.25 * t * fade))
	if core.size() >= 2:
		draw_polyline(core, Color(1, 1, 1, fade), 3.0)


func _poly(pts: PackedVector2Array, col: Color) -> void:
	if pts.size() < 3:
		return
	if Geometry2D.triangulate_polygon(pts).is_empty():
		return
	draw_colored_polygon(pts, col)


func _draw_shock(s: Dictionary) -> void:
	var k: float = 1.0 - s["life"] / s["max"]
	var p: Vector2 = s["p"]
	var col: Color = s["col"]
	if s["type"] == "ground":
		var rx := lerpf(20, 260, Pose.ease_out(k, 2.0))
		var ry := rx * 0.16
		var pts := PackedVector2Array()
		for i in 25:
			var a := TAU * i / 24.0
			pts.append(p + Vector2(cos(a) * rx, sin(a) * ry))
		draw_polyline(pts, Color(col, 1.0 - k), maxf(3.0, 12.0 * (1.0 - k)))
		draw_polyline(pts, Color(1, 1, 1, (1.0 - k) * 0.8), 3.0)
	elif s["type"] == "hex":
		var dir: int = s["dir"]
		var c := p + Vector2(-dir * 10, 0)
		var r := 36.0 + 20.0 * k
		var pts := PackedVector2Array()
		for i in 7:
			var a := TAU * i / 6.0 + PI / 6.0
			pts.append(c + Vector2(cos(a) * r * 0.55, sin(a) * r))
		draw_colored_polygon(pts, Color(col, 0.25 * (1.0 - k)))
		draw_polyline(pts, Color(col, 1.0 - k), 3.0)
		draw_polyline(pts, Color(1, 1, 1, (1.0 - k) * 0.8), 3.0 if k < 0.5 else 0.0)


func _draw_gust(g: Dictionary) -> void:
	var k: float = 1.0 - g["life"] / g["max"]
	var p: Vector2 = g["p"]
	var col: Color = g["col"]
	var a := 1.0 - k
	if g["type"] == "gust":
		var dir: int = g["dir"]
		var pw: float = g["pow"]
		for i in 5:
			var yo := (i - 2) * 28.0 * pw
			var x0 := p.x + dir * (k * 260.0 * pw - 20.0 + absf(i - 2) * 12.0)
			var ln := 110.0 * pw * (1.0 - k * 0.5)
			var pts := PackedVector2Array()
			for j in 9:
				var t := float(j) / 8.0
				pts.append(Vector2(x0 - dir * ln * (1.0 - t), p.y + yo + sin(t * PI * 2.0 + i) * 10.0 * pw))
			draw_polyline(pts, Color(col, 0.8 * a), 6.0 if i == 2 else 3.0)
		draw_arc(p + Vector2(dir * k * 160.0 * pw, 0), 50.0 * pw + 60.0 * k, -PI / 3 if dir > 0 else PI * 2 / 3, PI / 3 if dir > 0 else PI * 4 / 3, 12, Color(1, 1, 1, 0.7 * a), 6.0)
	else:
		for i in 7:
			var h := i * 50.0
			var rx := 26.0 + i * 9.0
			var ph := k * 20.0 + i
			var pts := PackedVector2Array()
			for j in 13:
				var t := float(j) / 12.0
				var aa := ph + t * PI * 1.4
				pts.append(p + Vector2(cos(aa) * rx, -h - 20.0 + sin(aa) * rx * 0.25 - k * 60.0))
			draw_polyline(pts, Color(col, 0.85 * a) if i % 2 == 0 else Color(1, 1, 1, 0.7 * a), 3.0)


func _draw_feather(f: Dictionary) -> void:
	var p: Vector2 = f["p"]
	var k: float = f["life"] / f["max"]
	var col: Color = f["col"]
	col.a = minf(1.0, k * 3.0)
	var d := Vector2.from_angle(f["rot"] + PI * 0.5)
	var n := Vector2(-d.y, d.x)
	var pts := PackedVector2Array([p - d * 12.0, p + n * 4.0, p + d * 12.0, p - n * 3.0])
	draw_colored_polygon(pts, col)
	draw_line(p - d * 12.0, p + d * 12.0, Color(col.lightened(0.35), col.a), 3.0)


func _draw_barrier(b: Dictionary) -> void:
	var k: float = 1.0 - b["life"] / b["max"]
	var p: Vector2 = b["p"]
	var nrm: Vector2 = b["n"]
	var tang := Vector2(-nrm.y, nrm.x)
	var s: float = b["s"]
	var col := Color(1.0, 0.75, 0.9, (1.0 - k) * (0.5 + 0.5 * s))
	var gold := Color(1.0, 0.85, 0.5, (1.0 - k))
	for i in range(-3, 4):
		var c := p + tang * (i * 42.0) * (0.6 + k * 0.6)
		var r := 20.0 * (1.0 - absf(i) * 0.15)
		var pts := PackedVector2Array()
		for j in 7:
			var a := TAU * j / 6.0
			pts.append(c + Vector2(cos(a), sin(a)) * r)
		draw_polyline(pts, col if i % 2 else gold, 3.0)
	draw_line(p - tang * 220.0 * (0.4 + k), p + tang * 220.0 * (0.4 + k), Color(1, 0.8, 0.95, (1.0 - k) * 0.6), 6.0)


# ================================================================ back layer
func draw_back(ci: Node2D) -> void:
	# fighter shadows
	if arena != null:
		for f in arena.fighters:
			if f.vanished:
				continue
			var h: float = Cfg.FLOOR_Y - f.position.y
			var s := clampf(1.0 - h / 700.0, 0.25, 1.0)
			var pts := PackedVector2Array()
			var rx := 42.0 * s
			var ry := 8.0 * s
			for i in 16:
				var a := TAU * i / 16.0
				pts.append(Vector2(f.position.x + cos(a) * rx, Cfg.FLOOR_Y + 3 + sin(a) * ry))
			ci.draw_colored_polygon(pts, Color(0.06, 0.02, 0.1, 0.42 * s))
	for d in dusts:
		var k: float = d["life"] / d["max"]
		var col: Color = d["col"]
		col.a = 0.55 * k
		ci.draw_circle(d["p"], d["r"] * (1.6 - k * 0.6), col)
	for a in afters:
		var f = a["f"]
		if not is_instance_valid(f):
			continue
		var k: float = a["life"] / a["max"]
		var col: Color = a["col"]
		col.a *= k
		ci.draw_set_transform(a["pos"], 0.0, Vector2(PX * a["facing"], PX))
		f.ghost_draw = true
		f.draw_body(ci, a["pose"], a["joints"], col, true)
		f.ghost_draw = false
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
