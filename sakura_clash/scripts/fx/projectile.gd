class_name Projectile
extends Node2D
## Projectiles: crescent wave, feathers, tornado, lightning bolt.
## Hit detection is done by the Arena; this class moves and draws.

const PX := Cfg.PX

var kind := ""
var owner_f: Fighter = null
var arena = null
var vel := Vector2.ZERO
var data: Dictionary = {}
var life := 1.0
var age := 0.0
var size := Vector2(40, 40)
var hit_every := 0.0
var hit_cd := 0.0
var max_hits := 1
var hits_done := 0
var alive := true
var reflected := false
var width := 64.0
var telegraph := 0.34
var col := Color.WHITE
var col2 := Color.WHITE
var _trail_t := 0.0
var _bolt_pts := PackedVector2Array()


func setup(p_kind: String, owner: Fighter, pos: Vector2, v: Vector2, d: Dictionary) -> void:
	kind = p_kind
	owner_f = owner
	position = pos
	vel = v
	data = d
	col = owner.fx_color
	col2 = owner.fx_color2
	match kind:
		"crescent":
			life = 1.8
			size = Vector2(42, 96)
		"feather":
			life = 0.95
			size = Vector2(26, 26)
			col = owner.palette.get("wing", Color(0.15, 0.1, 0.2))
			col2 = owner.palette.get("fan_rim", Color(1, 0.8, 0.3))
		"tornado":
			life = 2.3
			size = Vector2(96, 170)
			hit_every = 0.13
			max_hits = 16
			col = owner.fx_color2
		"bolt":
			life = 0.9
			width = 70.0


func hitbox() -> Rect2:
	if not alive:
		return Rect2()
	match kind:
		"bolt":
			if age >= telegraph and age < telegraph + 0.14:
				return Rect2(position.x - width * 0.5, Cfg.CEIL_Y, width, Cfg.FLOOR_Y - Cfg.CEIL_Y)
			return Rect2()
		"tornado":
			return Rect2(position.x - size.x * 0.5, position.y - size.y * 0.5, size.x, size.y)
	return Rect2(position - size * 0.5, size)


func can_hit_now() -> bool:
	return alive and hit_cd <= 0.0 and hits_done < max_hits


func clashable() -> bool:
	return alive and kind in ["crescent", "feather"]


func tick(dt: float) -> void:
	age += dt
	hit_cd = maxf(0.0, hit_cd - dt)
	match kind:
		"tornado":
			position += vel * dt
			if position.y > Cfg.FLOOR_Y - size.y * 0.5:
				position.y = Cfg.FLOOR_Y - size.y * 0.5
				vel.y = 0.0
			if position.y < Cfg.CEIL_Y + size.y * 0.5:
				position.y = Cfg.CEIL_Y + size.y * 0.5
				vel.y = 0.0
			if position.x < Cfg.WALL_L + 40 or position.x > Cfg.WALL_R - 40:
				vel.x = -vel.x * 0.5
			if arena != null:
				arena.petals.attract(position, 260.0, 900.0 * dt)
			_pull_victim(dt)
		"bolt":
			if age >= telegraph and age - dt < telegraph:
				_bolt_pts = PackedVector2Array()
				Sfx.play("thunder" if width > 100 else "zap", -4 if width > 100 else -2)
				if arena != null:
					arena.cam_shake(6.0 if width > 100 else 2.5)
					arena.fx.shockwave(Vector2(position.x, Cfg.FLOOR_Y), col)
					arena.petals.impulse(Vector2(position.x, Cfg.FLOOR_Y), 200.0, Vector2(0, -400))
					if width > 100:
						arena.screen_flash(Color(1, 1, 0.9), 0.25)
		_:
			position += vel * dt
			_trail_t -= dt
			if _trail_t <= 0.0 and arena != null:
				_trail_t = 0.03
				if kind == "crescent":
					arena.fx.spark(position + Vector2(randf_range(-10, 10), randf_range(-40, 40)), -vel * 0.2, Color(col, 0.8), 3.0, 0.3)
					arena.petals.impulse(position, 90.0, vel * 0.3)
	if kind != "bolt" and kind != "tornado":
		if position.x < Cfg.WALL_L - 10 or position.x > Cfg.WALL_R + 10 or position.y < Cfg.CEIL_Y - 10 or position.y > Cfg.FLOOR_Y + 10:
			if arena != null:
				arena.fx.hit_spark(position, int(signf(vel.x)) if vel.x != 0.0 else 1, "normal", col, 0)
				if position.x < Cfg.WALL_L or position.x > Cfg.WALL_R:
					arena.fx.barrier_hit(Vector2(clampf(position.x, Cfg.WALL_L, Cfg.WALL_R), position.y), Vector2(-signf(vel.x), 0), 0.4)
			destroy()
	if age >= life:
		if kind == "tornado" and arena != null:
			arena.fx.ring(position, Color(col, 0.8), 20, 120, 0.3, 4)
		destroy()
	queue_redraw()


func _pull_victim(dt: float) -> void:
	if owner_f == null or owner_f.opponent == null:
		return
	var v: Fighter = owner_f.opponent
	if v.state in [Fighter.S.HITSTUN, Fighter.S.TUMBLE] and v.alive:
		var d := position - v.center_pos()
		if d.length() < 170.0:
			v.position += d * minf(1.0, 6.0 * dt)
			v.vel.y = minf(v.vel.y, -80.0)


func on_hit_result(res: int) -> void:
	hits_done += 1
	hit_cd = hit_every
	if kind == "tornado":
		if res == Fighter.R.BLOCK:
			hit_cd = hit_every * 1.6
		return
	if kind == "bolt":
		return
	destroy()


func reflect(new_owner: Fighter) -> void:
	owner_f = new_owner
	vel = -vel * 1.15
	reflected = true
	age = 0.0
	hits_done = 0
	col = new_owner.fx_color
	if kind == "tornado":
		vel = -vel


func destroy() -> void:
	if not alive:
		return
	alive = false
	queue_free()


# ================================================================ drawing
func _draw() -> void:
	match kind:
		"crescent":
			_draw_crescent()
		"feather":
			_draw_feather()
		"tornado":
			_draw_tornado()
		"bolt":
			_draw_bolt()


func _draw_crescent() -> void:
	var ang := vel.angle()
	var pts := PackedVector2Array()
	var inner := PackedVector2Array()
	var r := 48.0
	var n := 14
	for i in n + 1:
		var t := float(i) / float(n)
		var a := ang - 1.25 + 2.5 * t
		pts.append(Vector2.from_angle(a) * r)
		var th := sin(t * PI)
		inner.append(Vector2.from_angle(a) * (r - 6.0 - th * 22.0) + Vector2.from_angle(ang) * (-4.0))
	var poly := PackedVector2Array(pts)
	for i in range(inner.size() - 1, -1, -1):
		poly.append(inner[i])
	var glow := PackedVector2Array()
	for p in poly:
		glow.append(p * 1.18)
	var fl := 0.85 + 0.15 * sin(age * 40.0)
	if not Geometry2D.triangulate_polygon(glow).is_empty():
		draw_colored_polygon(glow, Color(col, 0.25))
	if not Geometry2D.triangulate_polygon(poly).is_empty():
		draw_colored_polygon(poly, Color(col, 0.85 * fl))
	var core := PackedVector2Array()
	for i in range(2, n - 1):
		core.append(pts[i] * 0.97)
	draw_polyline(core, Color(1, 1, 1, fl), 4.0)


func _draw_feather() -> void:
	var d := vel.normalized()
	var nrm := Vector2(-d.y, d.x)
	var pts := PackedVector2Array([-d * 16.0, nrm * 5.0 - d * 2.0, d * 14.0, -nrm * 4.0 - d * 2.0])
	draw_colored_polygon(pts, col)
	draw_line(-d * 22.0, d * 14.0, col2, 3.0)
	draw_line(-d * 34.0, -d * 18.0, Color(col2, 0.4), 3.0)


func _draw_tornado() -> void:
	var fade := clampf(minf(age * 4.0, (life - age) * 3.0), 0.0, 1.0)
	var h := size.y
	for i in 9:
		var t := float(i) / 8.0
		var y := h * 0.5 - t * h
		var rx := 16.0 + t * 44.0
		var ph := age * 14.0 + i * 0.9
		var pts := PackedVector2Array()
		for j in 11:
			var u := float(j) / 10.0
			var a := ph + u * PI * 1.3
			pts.append(Vector2(cos(a) * rx, y + sin(a) * rx * 0.22))
		var c := Color(col, 0.75 * fade) if i % 2 == 0 else Color(1, 1, 1, 0.65 * fade)
		draw_polyline(pts, c, 6.0 if i % 3 == 0 else 3.0)
	for k in 6:
		var a := age * 9.0 + k * 1.1
		var t := fmod(age * 0.7 + k * 0.17, 1.0)
		var p := Vector2(cos(a) * (18.0 + t * 44.0), h * 0.5 - t * h)
		draw_rect(Rect2(p - Vector2(3, 3), Vector2(6, 6)), Color(1, 0.75, 0.88, fade))


func _draw_bolt() -> void:
	var x := 0.0
	var floor_y := Cfg.FLOOR_Y - position.y
	var top := Cfg.CEIL_Y - position.y - 40.0
	if age < telegraph:
		var k := age / telegraph
		var blink := 0.5 + 0.5 * sin(age * 50.0)
		draw_line(Vector2(x, top), Vector2(x, floor_y), Color(col, 0.18 + 0.2 * k * blink), 3.0)
		var rx := width * 0.5 * (1.2 - 0.4 * k)
		var pts := PackedVector2Array()
		for i in 17:
			var a := TAU * i / 16.0
			pts.append(Vector2(x + cos(a) * rx, floor_y + sin(a) * rx * 0.2))
		draw_polyline(pts, Color(col, 0.5 + 0.5 * blink), 3.0)
		return
	var st := age - telegraph
	if st > 0.3:
		return
	if _bolt_pts.is_empty() or int(st * 30.0) != int((st - 0.016) * 30.0):
		_bolt_pts = PackedVector2Array()
		var n := 14
		for i in n + 1:
			var t := float(i) / float(n)
			var jx := 0.0 if (i == 0 or i == n) else randf_range(-width * 0.35, width * 0.35)
			_bolt_pts.append(Vector2(x + jx, lerpf(top, floor_y, t)))
	var k := 1.0 - st / 0.3
	var w := width * 0.22
	draw_polyline(_bolt_pts, Color(col, 0.3 * k), w * 3.0)
	draw_polyline(_bolt_pts, Color(col, k), w)
	draw_polyline(_bolt_pts, Color(1, 1, 1, k), maxf(3.0, w * 0.4))
	draw_circle(Vector2(x, floor_y), width * 0.5 * k, Color(1, 1, 0.9, 0.6 * k))
