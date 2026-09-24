class_name Petals
extends Node2D
## One layer of falling sakura petals (world coordinates, pixel layer).
## depth 0: far layer behind the fighters, lands on the back of the terrace.
## depth 1: near layer in front of the fighters, lands on the front edge.
## depth 2: big foreground petals with camera parallax, never land.

const PX := Cfg.PX
const COLORS := [Color("ffc6df"), Color("ff9fcd"), Color("ffb3d6"), Color("f8d7e8"), Color("ff86bf"), Color("ffe3ef")]

var depth := 0
var petals: Array = []
var cam_center := Vector2(836, 470)
var clock := 0.0


func setup(p_depth: int, count: int) -> void:
	depth = p_depth
	for i in count:
		var pt := _new_petal()
		pt["p"] = Vector2(randf_range(-50, Cfg.WORLD_W + 150), randf_range(-40, Cfg.FLOOR_Y))
		petals.append(pt)


func _new_petal(burst := false) -> Dictionary:
	var sz := 2.0
	var fall := randf_range(38, 70)
	match depth:
		0:
			sz = randf_range(1.6, 2.4)
			fall = randf_range(30, 55)
		1:
			sz = randf_range(2.4, 3.4)
			fall = randf_range(45, 80)
		2:
			sz = randf_range(6.0, 9.0)
			fall = randf_range(90, 150)
	var land := Cfg.FLOOR_Y
	if depth == 0:
		land = randf_range(712, Cfg.FLOOR_Y - 8)
	elif depth == 1:
		land = randf_range(Cfg.FLOOR_Y + 6, 905)
	return {
		"p": Vector2(randf_range(0, Cfg.WORLD_W + 250), randf_range(-60, -10)),
		"v": Vector2(randf_range(-20, 10), fall), "fall": fall,
		"ph": randf() * TAU, "spd": randf_range(2.0, 4.5), "rot": randf() * TAU, "vr": randf_range(-1.5, 1.5),
		"sz": sz, "c": COLORS[randi() % COLORS.size()], "land": land, "t": 0.0, "st": 0,
		"burst": burst, "life": randf_range(1.5, 3.0) if burst else 999.0,
	}


func tick(dt: float, wind: float) -> void:
	clock += dt
	var i := petals.size() - 1
	while i >= 0:
		var pt: Dictionary = petals[i]
		if pt["st"] == 1:
			pt["t"] -= dt
			if pt["t"] <= 0.0:
				if pt["burst"]:
					petals.remove_at(i)
				else:
					petals[i] = _new_petal()
			i -= 1
			continue
		pt["ph"] += dt * pt["spd"]
		pt["rot"] += dt * pt["vr"]
		var v: Vector2 = pt["v"]
		var target := Vector2(wind * (0.6 + 0.4 * depth) + sin(pt["ph"]) * 40.0, pt["fall"] + cos(pt["ph"] * 0.7) * 12.0)
		v = v.lerp(target, 1.0 - exp(-dt * 1.6))
		pt["v"] = v
		pt["p"] = (pt["p"] as Vector2) + v * dt
		var p: Vector2 = pt["p"]
		if pt["burst"]:
			pt["life"] -= dt
			if pt["life"] <= 0.0:
				petals.remove_at(i)
				i -= 1
				continue
		if depth < 2 and p.y >= pt["land"] and v.y > 0.0:
			pt["st"] = 1
			pt["t"] = randf_range(2.5, 6.0) if not pt["burst"] else 1.0
			pt["p"] = Vector2(p.x, pt["land"])
		elif p.x < -60 or p.x > Cfg.WORLD_W + 300 or p.y > Cfg.WORLD_H + 60 or p.y < -300:
			if pt["burst"]:
				petals.remove_at(i)
			else:
				petals[i] = _new_petal()
		i -= 1
	queue_redraw()


func impulse(pos: Vector2, radius: float, v: Vector2) -> void:
	var s := 1.0 if depth < 2 else 0.4
	for pt in petals:
		var d: float = (pt["p"] as Vector2).distance_to(pos)
		if d < radius:
			var k := (1.0 - d / radius) * s
			var add := v * k + Vector2(randf_range(-60, 60), randf_range(-60, 20)) * k
			pt["v"] = (pt["v"] as Vector2) + add
			pt["vr"] += randf_range(-6, 6) * k
			if pt["st"] == 1 and add.length() > 60.0:
				pt["st"] = 0
				pt["v"] = Vector2(add.x, -absf(add.y) - 120.0 * k)


func attract(pos: Vector2, radius: float, strength: float) -> void:
	for pt in petals:
		var p: Vector2 = pt["p"]
		var d := pos - p
		var l := d.length()
		if l < radius and l > 1.0:
			var k := 1.0 - l / radius
			var tang := Vector2(-d.y, d.x) / l
			pt["v"] = (pt["v"] as Vector2) + (d / l * strength * 0.6 + tang * strength + Vector2(0, -strength * 0.8)) * k
			if pt["st"] == 1:
				pt["st"] = 0


func burst(pos: Vector2, n: int, v: Vector2) -> void:
	for i in n:
		var pt := _new_petal(true)
		pt["p"] = pos + Vector2(randf_range(-20, 20), randf_range(-20, 20))
		var d := Vector2.from_angle(randf() * TAU)
		pt["v"] = v + d * randf_range(150, 520)
		pt["vr"] = randf_range(-8, 8)
		petals.append(pt)


func _draw() -> void:
	var par := 0.35 if depth == 2 else 0.0
	for pt in petals:
		var p: Vector2 = pt["p"]
		if par > 0.0:
			p += (p - cam_center) * par
		var c: Color = pt["c"]
		var sz: float = pt["sz"] * PX
		var flip: float
		if pt["st"] == 1:
			flip = 0.45
			var tl: float = pt["t"]
			if tl < 1.0:
				c.a = tl
		else:
			flip = absf(cos(pt["ph"]))
		var d := Vector2.from_angle(pt["rot"])
		var n := Vector2(-d.y, d.x)
		var w := maxf(PX * 0.9, sz * 0.62 * flip)
		var pts := PackedVector2Array([p - d * sz * 0.5, p + n * w * 0.5, p + d * sz * 0.5, p - n * w * 0.5])
		if pt["st"] == 1:
			pts = PackedVector2Array([p - Vector2(sz * 0.5, 0), p + Vector2(0, -PX * 0.5), p + Vector2(sz * 0.5, 0), p + Vector2(0, PX * 0.6)])
		draw_colored_polygon(pts, c)
		if depth >= 1 and flip > 0.5:
			draw_rect(Rect2(p - Vector2(PX, PX) * 0.5, Vector2(PX, PX)), Color(1, 1, 1, 0.5 * c.a))


class Field:
	extends RefCounted
	var layers: Array = []

	func impulse(pos: Vector2, radius: float, v: Vector2) -> void:
		for l in layers:
			l.impulse(pos, radius, v)

	func attract(pos: Vector2, radius: float, strength: float) -> void:
		for l in layers:
			if l.depth < 2:
				l.attract(pos, radius, strength)

	func burst(pos: Vector2, n: int, v: Vector2) -> void:
		if layers.size() >= 2:
			layers[1].burst(pos, n, v)

	func tick(dt: float, wind: float, cam: Vector2) -> void:
		for l in layers:
			l.cam_center = cam
			l.tick(dt, wind)
