class_name Pose
extends RefCounted
## Pose helpers for the procedural skeletal rig.
##
## Angles are absolute, measured from "straight down", positive values rotate
## towards the facing direction: 0 = down, PI/2 = forward, PI = up.
## Torso lean (tor) is measured from "straight up", positive = lean forward.
## When ik > 0.5 the legs are solved from foot targets (flx/fly, blx/bly),
## which keeps feet planted on the ground.

const KEYS := [
	"hx", "hy", "rot", "tor", "hd",
	"tf", "sf", "tb", "sb",
	"uf", "lf", "ub", "lb",
	"wpn", "wing", "flap", "sq", "ik",
	"flx", "fly", "blx", "bly", "aux",
]

const DEFAULT := {
	"hx": 0.0, "hy": 0.0, "rot": 0.0, "tor": 0.08, "hd": 0.0,
	"tf": 0.12, "sf": -0.04, "tb": -0.12, "sb": -0.2,
	"uf": 0.3, "lf": 1.0, "ub": -0.15, "lb": 0.35,
	"wpn": 1.1, "wing": 0.25, "flap": 0.0, "sq": 1.0, "ik": 1.0,
	"flx": 4.0, "fly": 0.0, "blx": -4.0, "bly": 0.0, "aux": 0.0,
}


static func make(overrides: Dictionary, base: Dictionary = DEFAULT) -> Dictionary:
	var p := base.duplicate()
	for k in overrides:
		p[k] = float(overrides[k])
	return p


static func blend(a: Dictionary, b: Dictionary, t: float) -> Dictionary:
	var p := {}
	for k in KEYS:
		var va: float = a.get(k, DEFAULT[k])
		var vb: float = b.get(k, DEFAULT[k])
		p[k] = va + (vb - va) * t
	return p


static func blend_into(a: Dictionary, b: Dictionary, t: float) -> void:
	for k in KEYS:
		var va: float = a.get(k, DEFAULT[k])
		var vb: float = b.get(k, DEFAULT[k])
		a[k] = va + (vb - va) * t


static func dir(angle: float) -> Vector2:
	return Vector2(sin(angle), cos(angle))


## Two-bone IK. Returns (thigh_angle, shin_angle) so the knee bends forward.
static func ik2(hip: Vector2, target: Vector2, a: float, b: float) -> Vector2:
	var d := target - hip
	var dist := clampf(d.length(), 0.01, a + b - 0.01)
	var base := atan2(d.x, d.y)
	var cos_al := clampf((a * a + dist * dist - b * b) / (2.0 * a * dist), -1.0, 1.0)
	var th := base + acos(cos_al)
	var knee := hip + dir(th) * a
	var foot := hip + d.normalized() * dist if d.length() > 0.001 else hip + Vector2(0, dist)
	var e := foot - knee
	return Vector2(th, atan2(e.x, e.y))


static func ease_out(t: float, power := 2.0) -> float:
	t = clampf(t, 0.0, 1.0)
	return 1.0 - pow(1.0 - t, power)


static func ease_in_out(t: float) -> float:
	t = clampf(t, 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)
