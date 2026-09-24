extends Fighter
## KARASU - crow tengu. Free flight with stamina, 8-way air dashes,
## wind and lightning. Fragile in the air (+10% damage, +15% knockback,
## gets knocked out of flight when hit) and has less health.

var hair: Chain
var swoop_dir := Vector2.RIGHT
var dive_dir := Vector2.RIGHT
var dive_impacted := false
var storm_strikes := 0
var flap_phase := 0.0
var feather_t := 0.0


func _setup_stats() -> void:
	char_id = "tengu"
	display_name = "КАРАСУ"
	max_hp = 900.0
	walk_speed = 290.0
	run_speed = 600.0
	dash_speed = 1320.0
	dash_time = 0.14
	air_speed = 360.0
	jump_vel = 1100.0
	is_flier = true
	extra_jumps = 0
	air_dashes_max = 0
	weight = 1.0
	fly_speed = 440.0
	boost_speed = 780.0
	fly_accel = 2900.0
	takeoff_vel = 820.0
	stamina_max = 100.0
	drain_hover = 6.5
	drain_move = 9.5
	drain_boost = 21.0
	dash_stamina = 12.0
	stamina_regen = 48.0
	HIP_H = 31.0
	THIGH = 14.5
	SHIN = 14.5
	TORSO = 16.0
	NECK = 2.0
	HEAD_R = 5.3
	UARM = 9.5
	LARM = 9.5
	SH_DROP = 2.3
	body_w = 16.0
	body_h = 62.0
	fx_color = Color(1.0, 0.86, 0.38)
	fx_color2 = Color(0.72, 1.0, 0.95)
	palette = {
		"skin": Color("f6d6bf"), "skin_d": Color("cf9f86"),
		"hair": Color("f1eef9"), "hair_d": Color("aca4c6"),
		"cap": Color("17121f"),
		"wing": Color("231a34"), "wing_d": Color("140e1e"), "wing_hi": Color("4d3c70"), "wing_tip": Color("7462a8"),
		"top": Color("f3eee4"), "top_d": Color("b9ae9c"),
		"pom": Color("f28a2e"), "pom_d": Color("b3561a"),
		"pants": Color("2e2244"), "pants_d": Color("1b142a"),
		"wrap": Color("ddd6c6"), "wrap_d": Color("9b917f"),
		"geta": Color("5a3a2a"), "geta_d": Color("33201a"),
		"fan": Color("261c36"), "fan_d": Color("120c1a"), "fan_rim": Color("e8b54a"),
		"eye": Color("e8364a"), "mark": Color("d62f45"), "sash": Color("5b3f86"),
	}
	palette_alt = palette.duplicate()
	palette_alt.merge({
		"hair": Color("2a2135"), "hair_d": Color("140f1c"),
		"wing": Color("e8e5f2"), "wing_d": Color("a6a1bb"), "wing_hi": Color("ffffff"), "wing_tip": Color("c4bde0"),
		"top": Color("2b2337"), "top_d": Color("17121e"),
		"pom": Color("7fd4ff"), "pom_d": Color("3a86b8"),
		"fan": Color("efeaf7"), "fan_d": Color("a39db8"), "sash": Color("c23a55"),
		"eye": Color("7fd4ff"), "mark": Color("7fd4ff"),
	}, true)


func _on_alt_palette() -> void:
	fx_color = Color(0.78, 0.6, 1.0)
	fx_color2 = Color(0.8, 0.9, 1.0)
	for k in moves:
		var s = moves[k]["slash"]
		if s is Dictionary and not s.is_empty():
			s["col"] = fx_color2
		elif s is Array:
			for e in s:
				e["col"] = fx_color2


func _init_chains() -> void:
	hair = Chain.new(6, 7.0)
	hair.anchor_key = "head"
	hair.anchor_off = Vector2(-4.2, -1.5)
	hair.width = 5.0
	hair.width_end = 1.6
	hair.grav = 800.0
	hair.damp = 0.9
	chains = [hair]
	for c in chains:
		c.reset(position + Vector2(0, -150))


# ================================================================ poses
var TB := {}


func pz(d: Dictionary) -> Dictionary:
	return Pose.make(d, TB)


func _build_poses() -> void:
	TB = Pose.make({"fly": -2.5, "bly": -2.5, "wing": 0.15, "wpn": 2.6})
	P["idle"] = pz({"hy": 2, "tor": 0.06, "hd": -0.05, "flx": 5, "blx": -5, "uf": 0.9, "lf": 2.3, "ub": -0.25, "lb": 0.35, "wpn": 2.7, "wing": 0.15})
	P["intro"] = pz({"hy": 1, "tor": 0.0, "hd": -0.1, "flx": 3, "blx": -3, "uf": 2.6, "lf": 2.9, "ub": -0.2, "lb": 0.2, "wpn": 3.0, "wing": 0.9})
	P["win"] = pz({"ik": 0, "hy": -2, "tor": -0.1, "hd": -0.25, "tf": 0.3, "sf": 0.0, "tb": -0.1, "sb": -0.4, "uf": 2.9, "lf": 3.1, "ub": -0.6, "lb": -0.2, "wpn": 3.2, "wing": 1.1})
	P["crouch"] = pz({"hy": 11, "tor": 0.35, "hd": -0.3, "flx": 8, "blx": -7, "uf": 1.0, "lf": 2.2, "ub": 0.2, "lb": 0.9, "wpn": 2.5, "wing": 0.1})
	P["run"] = pz({"hy": 3, "tor": 0.5, "hd": -0.4, "uf": -0.8, "lf": -0.3, "ub": -1.0, "lb": -0.5, "wpn": -1.0, "wing": 0.45})
	P["fly"] = pz({"ik": 0, "tor": 0.15, "hd": -0.1, "tf": 0.35, "sf": 0.05, "tb": -0.05, "sb": -0.4, "uf": 0.9, "lf": 2.2, "ub": -0.5, "lb": 0.0, "wpn": 2.6, "wing": 1.0})
	P["fly_fast"] = pz({"ik": 0, "tor": 1.05, "hd": -0.95, "tf": -0.15, "sf": -0.35, "tb": -0.45, "sb": -0.65, "uf": 1.45, "lf": 1.6, "ub": -1.6, "lb": -1.5, "wpn": 1.6, "wing": 0.55})
	P["fall"] = pz({"ik": 0, "tor": -0.1, "hd": 0.2, "tf": 0.5, "sf": 0.2, "tb": 0.0, "sb": -0.3, "uf": 2.2, "lf": 2.5, "ub": -2.0, "lb": -1.6, "wpn": 2.0, "wing": 0.6})
	P["jump"] = pz({"ik": 0, "tor": 0.1, "tf": 0.9, "sf": -0.2, "tb": -0.2, "sb": -0.8, "uf": 1.8, "lf": 2.4, "ub": -1.0, "lb": -0.6, "wpn": 2.4, "wing": 0.9})
	P["dash"] = pz({"hy": 6, "tor": 0.8, "hd": -0.7, "flx": 10, "blx": -12, "uf": 1.4, "lf": 1.6, "ub": -1.4, "lb": -1.3, "wpn": 1.6, "wing": 0.5})
	P["airdash"] = P["fly_fast"]
	P["dodge"] = pz({"ik": 0, "tor": -0.4, "hd": 0.2, "tf": 0.9, "sf": 0.3, "tb": 0.3, "sb": -0.3, "uf": 1.8, "lf": 2.6, "ub": 0.5, "lb": 1.2, "wpn": 2.9, "wing": 0.2})
	P["guard"] = pz({"hy": 3, "tor": -0.05, "hd": 0.05, "flx": 5, "blx": -6, "uf": 1.6, "lf": 2.7, "ub": 1.2, "lb": 2.2, "wpn": 2.9, "wing": -0.45})
	P["guard_air"] = pz({"ik": 0, "tor": 0.0, "hd": 0.05, "tf": 0.9, "sf": -0.4, "tb": 0.5, "sb": -0.6, "uf": 1.6, "lf": 2.7, "ub": 1.2, "lb": 2.2, "wpn": 2.9, "wing": -0.45})
	P["parry"] = pz({"hy": 3, "tor": 0.25, "flx": 8, "blx": -5, "uf": 1.9, "lf": 1.8, "ub": 0.2, "lb": 0.8, "wpn": 1.6, "wing": 0.3})
	P["parry_air"] = pz({"ik": 0, "tor": 0.25, "tf": 0.6, "sf": 0.0, "tb": -0.1, "sb": -0.5, "uf": 1.9, "lf": 1.8, "ub": 0.2, "lb": 0.8, "wpn": 1.6, "wing": 0.6})
	P["hit"] = pz({"hy": 3, "tor": -0.45, "hd": 0.45, "flx": 4, "blx": -7, "uf": -0.4, "lf": 0.3, "ub": -0.9, "lb": -0.3, "wpn": 0.5, "wing": 0.5})
	P["hit_air"] = pz({"ik": 0, "tor": -0.5, "hd": 0.5, "tf": 0.6, "sf": 0.9, "tb": 0.2, "sb": 0.5, "uf": -1.0, "lf": -0.3, "ub": -1.6, "lb": -1.0, "wpn": 0.5, "wing": 0.75})
	P["tumble"] = pz({"ik": 0, "tor": -0.2, "hd": 0.3, "tf": 1.3, "sf": 0.2, "tb": 0.8, "sb": -0.2, "uf": 1.8, "lf": 2.4, "ub": -1.8, "lb": -1.2, "wpn": 0.8, "wing": 0.85})
	P["down"] = pz({"ik": 0, "hy": 27, "rot": -1.5, "tor": 0.0, "hd": -0.35, "tf": 0.35, "sf": 0.2, "tb": 0.1, "sb": -0.15, "uf": 1.1, "lf": 1.6, "ub": 0.6, "lb": 0.45, "wpn": 1.0, "wing": 0.3})
	P["grab"] = pz({"hy": 4, "tor": 0.3, "flx": 9, "blx": -6, "uf": 1.55, "lf": 1.65, "ub": -0.3, "lb": 0.4, "wpn": 2.6, "wing": 0.4})
	# attacks (air-style legs: they are used both grounded and flying)
	P["l1_a"] = pz({"hy": 3, "tor": -0.05, "flx": 6, "blx": -6, "uf": -0.6, "lf": 0.6, "ub": 0.3, "lb": 1.0, "wpn": -1.0, "wing": 0.5, "flap": -0.3})
	P["l1_b"] = pz({"hy": 4, "tor": 0.3, "flx": 9, "blx": -6, "uf": 1.6, "lf": 1.8, "ub": -0.4, "lb": 0.2, "wpn": 2.0, "wing": 0.6, "flap": 0.3})
	P["l2_a"] = pz({"hy": 3, "tor": 0.1, "flx": 8, "blx": -6, "uf": 2.3, "lf": -2.8, "ub": -0.3, "lb": 0.3, "wpn": -2.4, "wing": 0.5})
	P["l2_b"] = pz({"hy": 4, "tor": 0.35, "flx": 10, "blx": -6, "uf": 1.1, "lf": 0.5, "ub": -0.5, "lb": 0.1, "wpn": 0.2, "wing": 0.6})
	P["kick"] = pz({"ik": 0, "tor": -0.15, "hd": 0.0, "tf": 1.6, "sf": 1.62, "tb": -0.3, "sb": -0.8, "uf": 2.4, "lf": 2.8, "ub": -1.4, "lb": -1.0, "wpn": 2.6, "wing": 0.9})
	P["buf_a"] = pz({"hy": 5, "tor": -0.2, "hd": 0.1, "flx": 6, "blx": -8, "uf": -1.0, "lf": -0.4, "ub": -1.2, "lb": -0.6, "wpn": -1.0, "wing": 1.0, "flap": -0.9})
	P["buf_b"] = pz({"hy": 5, "tor": 0.45, "hd": -0.2, "flx": 11, "blx": -7, "uf": 1.6, "lf": 1.6, "ub": 1.4, "lb": 1.5, "wpn": 1.6, "wing": 1.15, "flap": 1.2})
	P["upl_a"] = pz({"hy": 6, "tor": 0.2, "flx": 7, "blx": -6, "uf": 0.2, "lf": 0.5, "ub": 0.0, "lb": 0.3, "wpn": 0.3, "wing": 0.4, "flap": 0.6})
	P["upl_b"] = pz({"hy": 1, "tor": -0.15, "hd": -0.35, "flx": 5, "blx": -6, "uf": 2.9, "lf": 3.1, "ub": 2.6, "lb": 2.9, "wpn": 3.1, "wing": 1.15, "flap": -0.9})
	P["tal_a"] = pz({"ik": 0, "tor": -0.15, "hd": 0.1, "tf": 1.5, "sf": -0.3, "tb": 0.2, "sb": -0.6, "uf": 1.9, "lf": 2.5, "ub": -1.0, "lb": -0.4, "wpn": 2.6, "wing": 0.9})
	P["tal_b"] = pz({"ik": 0, "tor": 0.25, "hd": 0.2, "tf": 0.65, "sf": 0.55, "tb": -0.1, "sb": -0.6, "uf": 2.3, "lf": 2.8, "ub": -1.3, "lb": -0.8, "wpn": 2.6, "wing": 1.0})
	P["palm_a"] = pz({"hy": 4, "tor": -0.2, "flx": 6, "blx": -8, "uf": -0.9, "lf": -0.3, "ub": 0.3, "lb": 0.8, "wpn": -1.2, "wing": 1.0, "flap": -0.6})
	P["palm_b"] = pz({"hy": 5, "tor": 0.4, "hd": -0.15, "flx": 11, "blx": -7, "uf": 1.57, "lf": 1.57, "ub": -0.6, "lb": -0.1, "wpn": 1.57, "wing": 1.1, "flap": 0.8})
	P["uh_a"] = pz({"hy": 10, "tor": 0.3, "flx": 8, "blx": -7, "uf": 0.4, "lf": 0.6, "ub": 0.2, "lb": 0.4, "wpn": 0.5, "wing": 0.5, "flap": 0.5})
	P["uh_b"] = pz({"hy": 0.5, "tor": -0.2, "hd": -0.4, "flx": 5, "blx": -6, "uf": 2.95, "lf": 3.1, "ub": 2.7, "lb": 3.0, "wpn": 3.1, "wing": 1.2, "flap": -1.0})
	P["dh_a"] = pz({"hy": 9, "tor": 0.3, "flx": 7, "blx": -9, "uf": -0.6, "lf": 0.2, "ub": -0.5, "lb": 0.1, "wpn": -0.8, "wing": 0.9, "flap": -0.6})
	P["dh_b"] = pz({"hy": 12, "tor": 0.6, "hd": -0.4, "flx": 13, "blx": -10, "uf": 1.2, "lf": 1.4, "ub": 1.0, "lb": 1.2, "wpn": 1.4, "wing": 1.1, "flap": 1.1})
	P["plummet"] = pz({"ik": 0, "tor": 0.2, "hd": 0.4, "tf": 0.2, "sf": 0.1, "tb": 0.1, "sb": 0.05, "uf": 2.8, "lf": 3.0, "ub": 2.6, "lb": 2.9, "wpn": 3.1, "wing": 0.3})
	P["plummet_a"] = pz({"ik": 0, "tor": -0.1, "hd": -0.1, "tf": 1.3, "sf": -0.3, "tb": 0.9, "sb": -0.6, "uf": 2.9, "lf": 3.1, "ub": 2.6, "lb": 3.0, "wpn": 3.1, "wing": 1.2})
	P["throw_a"] = pz({"hy": 3, "tor": -0.1, "flx": 7, "blx": -6, "uf": 2.5, "lf": -2.6, "ub": -0.3, "lb": 0.4, "wpn": -2.2, "wing": 0.6})
	P["cast_a"] = pz({"hy": 3, "tor": -0.2, "hd": -0.2, "flx": 6, "blx": -6, "uf": 2.8, "lf": 3.0, "ub": 0.2, "lb": 0.8, "wpn": 3.1, "wing": 1.0})
	P["cast_b"] = pz({"hy": 5, "tor": 0.45, "hd": -0.1, "flx": 11, "blx": -7, "uf": 1.3, "lf": 1.1, "ub": -0.5, "lb": 0.0, "wpn": 1.2, "wing": 1.1, "flap": 0.8})
	P["wrap"] = pz({"ik": 0, "tor": 0.3, "hd": 0.2, "tf": 1.4, "sf": -0.4, "tb": 1.0, "sb": -0.7, "uf": 0.8, "lf": 2.4, "ub": 0.6, "lb": 2.0, "wpn": 2.8, "wing": -0.5})
	P["storm"] = pz({"ik": 0, "tor": -0.15, "hd": -0.45, "tf": 0.4, "sf": 0.1, "tb": -0.1, "sb": -0.4, "uf": 3.0, "lf": 3.1, "ub": -0.9, "lb": -0.5, "wpn": 3.14, "wing": 1.25})


# ================================================================ moves
func _build_moves() -> void:
	moves["l1"] = mv({"name": "l1", "startup": 0.06, "active": 0.06, "recovery": 0.16, "box": Rect2(6, -60, 36, 36),
		"dmg": 28, "hitstun": 0.32, "kb": Vector2(130, 0), "air_kb": Vector2(150, 200), "next": "l2",
		"sfx": "swing_l", "hit_sfx": "hit_l", "spark": "wind", "poses": ["l1_a", "l1_b", "l1_b"],
		"slash": {"c": Vector2(2, -44), "r": 24, "a0": -150, "a1": 30, "w": 5, "wind": true}})
	moves["l2"] = mv({"name": "l2", "startup": 0.07, "active": 0.06, "recovery": 0.18, "box": Rect2(6, -62, 36, 40),
		"dmg": 30, "hitstun": 0.34, "kb": Vector2(150, 0), "air_kb": Vector2(160, 260), "next": "l3",
		"sfx": "swing_l", "hit_sfx": "hit_l", "spark": "wind", "poses": ["l2_a", "l2_b", "l2_b"],
		"slash": {"c": Vector2(2, -44), "r": 24, "a0": -80, "a1": 60, "w": 5, "wind": true}})
	moves["l3"] = mv({"name": "l3", "startup": 0.07, "active": 0.18, "recovery": 0.22, "box": Rect2(-26, -70, 64, 60),
		"hits": 2, "hit_every": 0.09, "dmg": 21, "hitstun": 0.38, "kb": Vector2(140, 0), "air_kb": Vector2(160, 300), "next": "l4",
		"sfx": "swing_m", "hit_sfx": "hit_m", "spark": "normal", "pose_fn": "_pose_spinkick",
		"slash": [{"type": "circle", "c": Vector2(0, -38), "r": 30, "w": 5, "wind": true}, {"t": 0.09, "type": "circle", "c": Vector2(0, -38), "r": 30, "w": 5, "wind": true}]})
	moves["l4"] = mv({"name": "l4", "startup": 0.12, "active": 0.1, "recovery": 0.3, "box": Rect2(4, -76, 60, 70),
		"dmg": 52, "hitstun": 0.55, "kb": Vector2(640, 280), "air_kb": Vector2(640, 300), "launch": true, "knockdown": true, "wall_bounce": true,
		"hitstop": 0.1, "shake": 6.0, "zoom": 0.04, "strength": 2, "guard_dmg": 20,
		"sfx": "gust", "hit_sfx": "hit_h", "spark": "wind", "poses": ["buf_a", "buf_b", "buf_b"], "spawn_t": 0.12, "spawn": "_gust_fx"})
	moves["up_l"] = mv({"name": "up_l", "startup": 0.08, "active": 0.08, "recovery": 0.24, "box": Rect2(-16, -100, 46, 54),
		"dmg": 38, "hitstun": 0.5, "kb": Vector2(40, 860), "air_kb": Vector2(40, 860), "launch": true,
		"hitstop": 0.08, "shake": 3.0, "sfx": "flap", "hit_sfx": "hit_m", "spark": "wind", "poses": ["upl_a", "upl_b", "upl_b"],
		"slash": {"c": Vector2(0, -50), "r": 28, "a0": 60, "a1": -120, "w": 6, "wind": true}})
	moves["down_l"] = mv({"name": "down_l", "startup": 0.08, "active": 0.08, "recovery": 0.22, "box": Rect2(4, -30, 34, 34),
		"dmg": 34, "hitstun": 0.4, "kb": Vector2(180, 0), "air_kb": Vector2(220, -520), "next": "l2",
		"sfx": "swing_m", "hit_sfx": "hit_m", "spark": "normal", "poses": ["tal_a", "tal_b", "tal_b"]})
	moves["run_l"] = mv({"name": "run_l", "startup": 0.05, "active": 0.2, "recovery": 0.25, "box": Rect2(-6, -60, 44, 52),
		"dmg": 46, "hitstun": 0.48, "kb": Vector2(420, 380), "air_kb": Vector2(420, 380), "launch": true, "kb_along_aim": true,
		"hitstop": 0.08, "shake": 4.0, "strength": 1, "sfx": "dash", "hit_sfx": "hit_m", "spark": "wind",
		"pose_fn": "_pose_swoop", "update": "_upd_swoop", "keep_momentum": true})
	moves["h"] = mv({"name": "h", "kind": "heavy", "startup": 0.18, "active": 0.08, "recovery": 0.38, "box": Rect2(8, -74, 66, 68),
		"dmg": 80, "hitstun": 0.6, "kb": Vector2(780, 300), "air_kb": Vector2(780, 320), "launch": true, "knockdown": true, "wall_bounce": true,
		"hitstop": 0.12, "shake": 8.0, "zoom": 0.06, "strength": 2, "guard_dmg": 30, "chargeable": true,
		"sfx": "gust", "hit_sfx": "hit_h", "spark": "wind", "poses": ["palm_a", "palm_b", "palm_b"], "spawn_t": 0.18, "spawn": "_gust_fx_big"})
	moves["up_h"] = mv({"name": "up_h", "kind": "heavy", "startup": 0.16, "active": 0.22, "recovery": 0.36, "box": Rect2(2, -130, 44, 124),
		"hits": 3, "hit_every": 0.07, "dmg": 25, "hitstun": 0.6, "kb": Vector2(20, 820), "air_kb": Vector2(20, 900), "launch": true, "anti_air": true,
		"hitstop": 0.07, "shake": 4.0, "strength": 1, "guard_dmg": 12, "sfx": "tornado", "hit_sfx": "hit_m", "spark": "wind",
		"poses": ["uh_a", "uh_b", "uh_b"], "spawn_t": 0.16, "spawn": "_updraft_fx"})
	moves["down_h"] = mv({"name": "down_h", "kind": "heavy", "startup": 0.14, "active": 0.1, "recovery": 0.36, "box": Rect2(-4, -26, 62, 26),
		"dmg": 56, "hitstun": 0.6, "kb": Vector2(280, 540), "air_kb": Vector2(280, 540), "launch": true, "knockdown": true, "otg": true,
		"hitstop": 0.09, "shake": 4.0, "strength": 1, "guard_dmg": 20, "sfx": "swing_h", "hit_sfx": "hit_m", "spark": "wind",
		"poses": ["dh_a", "dh_b", "dh_b"], "slash": {"c": Vector2(6, -18), "r": 34, "a0": -170, "a1": 20, "w": 6, "wind": true}})
	moves["air_down_h"] = mv({"name": "air_down_h", "kind": "heavy", "air": true, "startup": 0.12, "active": 0.6, "recovery": 0.28, "box": Rect2(-12, -30, 28, 46),
		"dmg": 64, "hitstun": 0.55, "kb": Vector2(200, 0), "air_kb": Vector2(220, -1200), "ground_bounce": true, "knockdown": true,
		"hitstop": 0.1, "shake": 6.0, "strength": 2, "sfx": "swing_h", "hit_sfx": "hit_h", "spark": "heavy", "poses": ["plummet_a", "plummet", "plummet"],
		"update": "_upd_plummet"})
	moves["throw"] = mv({"name": "throw", "kind": "throw", "throw": true, "startup": 0.06, "active": 0.06, "recovery": 0.35,
		"box": Rect2(4, -54, 24, 46), "dmg": 82, "sfx": "swing_m", "poses": ["grab", "grab", "idle"]})
	# abilities
	moves["q"] = mv({"name": "q", "kind": "special", "startup": 0.1, "active": 0.04, "recovery": 0.2, "box": Rect2(),
		"spawn_t": 0.1, "spawn": "_spawn_feathers", "cd_key": "q", "cd": 3.0, "sfx": "", "pose_fn": "_pose_throw", "cancel_special": false})
	moves["e"] = mv({"name": "e", "kind": "special", "startup": 0.18, "active": 0.05, "recovery": 0.3, "box": Rect2(),
		"spawn_t": 0.18, "spawn": "_spawn_tornado", "cd_key": "e", "cd": 8.0, "sfx": "", "poses": ["cast_a", "cast_b", "cast_b"], "cancel_special": false})
	moves["r"] = mv({"name": "r", "kind": "special", "startup": 0.14, "active": 0.32, "recovery": 0.26, "box": Rect2(-14, -60, 42, 60),
		"dmg": 80, "hitstun": 0.6, "kb": Vector2(560, 520), "air_kb": Vector2(560, 520), "launch": true, "knockdown": true, "ground_bounce": true,
		"kb_along_aim": true, "hitstop": 0.12, "shake": 7.0, "zoom": 0.05, "strength": 2, "guard_dmg": 26,
		"cd_key": "r", "cd": 6.0, "sfx": "", "hit_sfx": "zap", "spark": "lightning", "pose_fn": "_pose_dive", "update": "_upd_dive", "cancel_special": false})
	moves["ult"] = mv({"name": "ult", "kind": "ult", "ult": true, "startup": 0.2, "active": 2.4, "recovery": 0.5, "box": Rect2(),
		"invuln": Vector2(0.0, 0.3), "hover": true, "sfx": "", "poses": ["cast_a", "storm", "storm", "fly"], "update": "_upd_storm", "cancel_special": false})
	for k in moves:
		var s = moves[k]["slash"]
		if s is Dictionary and not s.is_empty():
			s["col"] = fx_color2
		elif s is Array:
			for e in s:
				e["col"] = fx_color2


# ================================================================ pose functions
func _pose_fly() -> Dictionary:
	var p: Dictionary = P["fly"].duplicate()
	var fwd := vel.x * facing
	if boosting:
		p = Pose.blend(p, P["fly_fast"], 0.9)
		p["flap"] = sin(flap_phase) * 0.5
	else:
		p["tor"] += clampf(fwd / 900.0, -0.4, 0.6) * 0.7
		p["tf"] += clampf(-vel.y / 800.0, -0.3, 0.5)
		p["flap"] = sin(flap_phase) * 0.9
		p["hy"] += sin(flap_phase + 1.3) * 1.3
	return p


func _pose_air() -> Dictionary:
	var p := super._pose_air()
	p["wing"] = 0.7
	p["flap"] = sin(anim_t * 20.0) * 0.6 if exhausted else 0.0
	return p


func _target_pose() -> Dictionary:
	if not on_ground:
		match state:
			S.GUARD, S.BLOCKSTUN:
				return P["guard_air"]
			S.PARRY:
				return P["parry_air"]
			S.IDLE, S.WALK:
				return _pose_fly()
	return super._target_pose()


func _pose_spinkick() -> Dictionary:
	var su: float = cur_move["startup"]
	var ac: float = cur_move["active"]
	if move_t < su:
		return Pose.blend(move_from_pose, P["tal_a"], move_t / su)
	var p: Dictionary = P["kick"].duplicate()
	if move_t < su + ac:
		p["rot"] = -TAU * Pose.ease_in_out((move_t - su) / ac)
		pose["rot"] = p["rot"]
		return p
	p["rot"] = 0.0
	pose["rot"] = 0.0
	return Pose.blend(p, neutral_pose(), (move_t - su - ac) / float(cur_move["recovery"]))


func _pose_swoop() -> Dictionary:
	var p: Dictionary = P["fly_fast"].duplicate()
	p["uf"] = 1.5
	p["lf"] = 1.55
	p["wpn"] = 1.6
	var fwdang := atan2(swoop_dir.y, absf(swoop_dir.x) + 0.001)
	p["rot"] = fwdang * 0.8
	if move_t > float(cur_move["startup"]) + float(cur_move["active"]):
		p["rot"] = 0.0
		return Pose.blend(p, neutral_pose(), 0.5)
	return p


func _pose_throw() -> Dictionary:
	var su: float = cur_move["startup"]
	var a := inp.aim
	var ang := atan2(a.x * facing, a.y)  # my convention: from down, + forward
	if move_t < su:
		return Pose.blend(move_from_pose, P["throw_a"], move_t / su)
	var p: Dictionary = P["l1_b"].duplicate()
	p["uf"] = ang
	p["lf"] = ang
	p["wpn"] = ang
	p["tor"] = 0.2 + clampf(ang - 1.57, -0.6, 0.6) * 0.3
	if move_t > su + 0.12:
		return Pose.blend(p, neutral_pose(), clampf((move_t - su - 0.12) / 0.12, 0.0, 1.0))
	return p


func _pose_dive() -> Dictionary:
	var su: float = cur_move["startup"]
	var ac: float = cur_move["active"]
	if move_t < su:
		return Pose.blend(move_from_pose, P["wrap"], Pose.ease_out(move_t / su))
	var p: Dictionary = P["fly_fast"].duplicate()
	p["wing"] = 0.25
	p["uf"] = 1.5
	p["lf"] = 1.55
	var local := Vector2(dive_dir.x * facing, dive_dir.y)
	p["rot"] = atan2(local.y, local.x) - 0.0
	if move_t > su + ac:
		p["rot"] = 0.0
		return Pose.blend(P["fly"], neutral_pose(), 0.5)
	return p


# ================================================================ move logic
func _on_move_start(n: String, _m: Dictionary) -> void:
	match n:
		"run_l":
			swoop_dir = inp.move.normalized() if inp.move.length() > 0.3 else Vector2(facing, 0)
			if absf(swoop_dir.x) > 0.2:
				facing = 1 if swoop_dir.x > 0 else -1
		"r":
			dive_dir = inp.aim
			dive_impacted = false
			snd("zap", -8, 1.4)
		"ult":
			arena.super_freeze(self, 0.85, "БУРЯ РАЙДЗИНА", "Гнев небес")
			storm_strikes = 0
		"q":
			snd("swing_l", -4, 1.3)
		"e":
			snd("gust", -6, 1.3)


func _upd_swoop(_dt: float) -> void:
	var su: float = cur_move["startup"]
	var ac: float = cur_move["active"]
	if move_t >= su and move_t < su + ac:
		vel = swoop_dir * 1150.0
		if not on_ground or swoop_dir.y < 0.0:
			on_ground = false if swoop_dir.y < -0.1 else on_ground
		if int(move_t * 40.0) != int((move_t - 0.016) * 40.0):
			fx().afterimage(self, Color(fx_color2, 0.4), 0.2)
	elif move_t >= su + ac:
		vel *= 0.86


func _upd_dive(_dt: float) -> void:
	var su: float = cur_move["startup"]
	var ac: float = cur_move["active"]
	if move_t < su:
		dive_dir = inp.aim if inp.aim.length() > 0.1 else Vector2(facing, 0)
		vel = vel.move_toward(Vector2.ZERO, 3000 * 0.016)
		if absf(dive_dir.x) > 0.15:
			facing = 1 if dive_dir.x > 0 else -1
		if randf() < 0.5:
			fx().zap(center_pos(), fx_color, 30.0)
		return
	if move_t < su + ac:
		if move_t - 0.017 < su:
			snd("thunder", -6, 1.4)
			fx().ring(center_pos(), Color(fx_color, 0.9), 10, 70, 0.25, 4)
		vel = dive_dir * 1550.0
		if dive_dir.y < -0.1:
			on_ground = false
		if int(move_t * 50.0) != int((move_t - 0.016) * 50.0):
			fx().afterimage(self, Color(fx_color, 0.5), 0.18)
			fx().zap(center_pos(), fx_color, 40.0)
		if on_ground and dive_dir.y > 0.2 and not dive_impacted:
			dive_impacted = true
			_thunder_impact()
			move_t = su + ac
	else:
		vel *= 0.8


func _thunder_impact() -> void:
	fx().shockwave(position, fx_color)
	fx().lightning(position + Vector2(0, -400), position, fx_color, 0.25, 3)
	arena.cam_shake(7.0)
	snd("thunder", -2, 1.2)
	arena.petals.impulse(position, 320.0, Vector2(0, -500))
	if opponent != null and absf(opponent.position.x - position.x) < 160.0 and opponent.position.y > Cfg.FLOOR_Y - 180.0:
		var sw := mv({"name": "thunderclap", "kind": "special", "dmg": 40, "hitstun": 0.55, "kb": Vector2(260, 620), "air_kb": Vector2(260, 620),
			"launch": true, "knockdown": true, "hitstop": 0.09, "shake": 4.0, "hit_sfx": "zap", "spark": "lightning", "strength": 1, "guard_dmg": 20})
		arena.resolve_direct_hit(self, opponent, sw, 1 if opponent.position.x > position.x else -1)


func _upd_plummet(_dt: float) -> void:
	var su: float = cur_move["startup"]
	var ac: float = cur_move["active"]
	if move_t < su:
		vel = vel.move_toward(Vector2(0, -150), 4000 * 0.016)
		return
	if move_t < su + ac:
		vel = Vector2(facing * 120.0, 1800.0)
		if on_ground:
			fx().shockwave(position, fx_color2)
			arena.cam_shake(6.0)
			snd("hit_h", -2, 0.7)
			arena.petals.impulse(position, 300.0, Vector2(0, -500))
			if opponent != null and opponent.on_ground and absf(opponent.position.x - position.x) < 140.0:
				var sw := mv({"name": "quake", "kind": "heavy", "dmg": 30, "hitstun": 0.5, "kb": Vector2(200, 560), "air_kb": Vector2(200, 560),
					"launch": true, "knockdown": true, "hitstop": 0.08, "shake": 4.0, "hit_sfx": "hit_m", "spark": "wind", "strength": 1, "guard_dmg": 18})
				arena.resolve_direct_hit(self, opponent, sw, 1 if opponent.position.x > position.x else -1)
			move_t = su + ac
			landing_lag = 0.1
	else:
		vel *= 0.8


func _upd_storm(_dt: float) -> void:
	var su: float = cur_move["startup"]
	vel = vel.move_toward(Vector2.ZERO, 40.0)
	if move_t < su:
		return
	var t := move_t - su
	var want := mini(int((t - 0.1) / 0.34) + 1, 6) if t > 0.1 else 0
	while storm_strikes < want:
		storm_strikes += 1
		_spawn_bolt(false)
	if t >= 2.15 and storm_strikes < 7:
		storm_strikes = 7
		_spawn_bolt(true)
	if int(move_t * 12.0) != int((move_t - 0.016) * 12.0):
		fx().zap(position + Vector2(facing * 20, -body_h * PX - 20), fx_color, 34.0)


func _spawn_bolt(final: bool) -> void:
	if opponent == null:
		return
	var tx := opponent.position.x + opponent.vel.x * 0.22 + randf_range(-20, 20)
	tx = clampf(tx, Cfg.WALL_L + 20, Cfg.WALL_R - 20)
	var data := mv({"name": "bolt", "kind": "ult", "dmg": 110 if final else 36, "hitstun": 0.7 if final else 0.5,
		"kb": Vector2(0, 700 if final else 260), "air_kb": Vector2(40, 700 if final else 320), "launch": true, "knockdown": final,
		"hitstop": 0.2 if final else 0.07, "shake": 12.0 if final else 4.0, "zoom": 0.1 if final else 0.0, "chip": 0.25, "guard_dmg": 30 if final else 14,
		"hit_sfx": "thunder" if final else "zap", "spark": "lightning", "strength": 3 if final else 1, "parryable": not final})
	var p = arena.spawn_projectile("bolt", self, Vector2(tx, Cfg.FLOOR_Y), Vector2.ZERO, data)
	if p != null and final:
		p.width = 150.0
		p.telegraph = 0.5


func _spawn_feathers() -> void:
	var a := inp.aim if inp.aim.length() > 0.1 else Vector2(facing, 0)
	var base := a.angle()
	for i in 3:
		var ang := base + (i - 1) * 0.16
		var d := Vector2.from_angle(ang)
		var data := mv({"name": "feather", "kind": "special", "dmg": 20, "hitstun": 0.28, "kb": Vector2(120, 0), "air_kb": Vector2(140, 150),
			"hitstop": 0.045, "shake": 1.5, "hit_sfx": "hit_l", "spark": "normal", "chip": 0.2, "guard_dmg": 7})
		arena.spawn_projectile("feather", self, chest_pos() + d * 30.0, d * 1150.0, data)
	snd("feather")
	snd("flap", -6, 1.3)


func _spawn_tornado() -> void:
	var a := inp.aim if inp.aim.length() > 0.1 else Vector2(facing, 0)
	var d := a.normalized()
	var start := center_pos() + d * 60.0
	var data := mv({"name": "tornado", "kind": "special", "dmg": 10, "hitstun": 0.34, "kb": Vector2(0, 0), "air_kb": Vector2(0, 300),
		"launch": true, "hitstop": 0.03, "shake": 1.0, "hit_sfx": "hit_l", "spark": "wind", "chip": 0.2, "guard_dmg": 6})
	arena.spawn_projectile("tornado", self, start, d * 270.0, data)
	snd("tornado")
	arena.petals.impulse(start, 200.0, d * 400.0)


func _gust_fx() -> void:
	fx().gust(center_pos() + Vector2(facing * 40, 0), facing, fx_color2, 1.0)
	arena.petals.impulse(center_pos() + Vector2(facing * 80, 0), 260.0, Vector2(facing * 700, -80))


func _gust_fx_big() -> void:
	fx().gust(center_pos() + Vector2(facing * 50, 0), facing, fx_color2, 1.0 + charge_t)
	arena.petals.impulse(center_pos() + Vector2(facing * 100, 0), 380.0, Vector2(facing * 1000, -120))


func _updraft_fx() -> void:
	fx().updraft(position + Vector2(facing * 70, 0), fx_color2)
	arena.petals.impulse(position + Vector2(facing * 70, -100), 200.0, Vector2(0, -900))


func preview_pose(dt: float) -> Dictionary:
	flap_phase += dt * 9.0
	return _pose_fly()


# ================================================================ per-tick extras
func _update_state(dt: float) -> void:
	super._update_state(dt)
	var fl := not on_ground and (state == S.FLY or (state == S.ATTACK and not exhausted) or state == S.DASH)
	var rate := 13.0 if boosting else 9.0
	if fl:
		var prev := flap_phase
		flap_phase += dt * rate
		if int(prev / TAU) != int(flap_phase / TAU):
			snd("flap", -16, randf_range(0.9, 1.1))
			arena.petals.impulse(position + Vector2(0, 20), 140.0, Vector2(0, 220))
		feather_t -= dt
		if feather_t <= 0.0:
			feather_t = randf_range(0.8, 1.8)
			fx().feather(center_pos() + Vector2(-facing * 30, -20), palette["wing"])
	else:
		flap_phase += dt * 3.0
	aura_t -= dt
	if aura_t <= 0.0:
		aura_t = 0.12
		if ki >= Cfg.KI_MAX and alive:
			fx().aura_spark(self, fx_color)


# ================================================================ drawing
func draw_body(ci: CanvasItem, p: Dictionary, j: Dictionary, sil: Color, use_sil: bool) -> void:
	if j.is_empty():
		return
	var c := palette
	var rot: float = j["rot"]
	var hip: Vector2 = j["hip"]
	var neck: Vector2 = j["neck"]
	var sh: Vector2 = j["sh"]
	var td := (neck - hip).normalized()
	var pp := Vector2(-td.y, td.x)
	var fwd := Vector2(1, 0).rotated(rot)
	var open: float = p["wing"]
	var flap: float = p["flap"]
	var root := sh - td * 1.5 - pp * 2.5

	# far wing + hair
	_wing(ci, root + pp * 1.0 - td * 0.5, open, flap - 0.18, rot, c["wing_d"], c["wing_d"].darkened(0.3), c["wing_hi"].darkened(0.35), c["wing_tip"].darkened(0.35), sil, use_sil)
	draw_chain(ci, hair, c["hair"], c["hair_d"], sil, use_sil)
	# back arm
	draw_group(ci, [["cap", sh, j["eb"], 4.6, 4.2]], c["top_d"], c["top_d"].darkened(0.35), sil, use_sil)
	draw_group(ci, [["cap", j["eb"], j["hb"], 2.7, 2.3], ["circ", j["hb"], 1.5]], c["skin_d"], c["skin_d"].darkened(0.35), sil, use_sil)
	# back leg
	_leg(ci, hip, j["kb"], j["fb"], c["pants_d"], c["wrap_d"], c["geta_d"], fwd, sil, use_sil)
	# near wing (behind torso unless wrapped forward)
	if open >= 0.0:
		_wing(ci, root, open, flap, rot, c["wing"], c["wing_d"], c["wing_hi"], c["wing_tip"], sil, use_sil)
	# torso
	draw_group(ci, [["poly", _quad(hip + td * 1.0, neck - td * 0.3, 7.5, 9.5)]], c["top"], c["top_d"], sil, use_sil)
	draw_group(ci, [["poly", _quad(hip + td * 2.0, hip - td * 3.5, 8.5, 10.0)]], c["pants"], c["pants_d"], sil, use_sil)
	draw_group(ci, [["poly", _quad(hip + td * 1.4, hip + td * 3.4, 8.2, 8.0)]], c["sash"], c["sash"].darkened(0.4), sil, use_sil)
	if not use_sil:
		ci.draw_line(neck - td * 0.3 + pp * 2.2, neck - td * 6.0 + pp * 0.6, c["top_d"], 1.0)
		ci.draw_line(hip + td * 4.2 - pp * 3.3, neck - td * 1.4 - pp * 4.1, c["top_d"], 1.0)
	draw_group(ci, [["circ", neck - td * 4.2 + pp * 3.9, 1.7], ["circ", neck - td * 8.2 + pp * 3.7, 1.7]], c["pom"], c["pom_d"], sil, use_sil)
	# front leg
	_leg(ci, hip, j["kf"], j["ff"], c["pants"], c["wrap"], c["geta"], fwd, sil, use_sil)
	# head
	_head(ci, j, c, rot, sil, use_sil)
	if open < 0.0:
		_wing(ci, root, open, flap, rot, c["wing"], c["wing_d"], c["wing_hi"], c["wing_tip"], sil, use_sil)
	# fan + front arm
	var hf: Vector2 = j["hf"]
	var ef: Vector2 = j["ef"]
	_fan(ci, hf, p["wpn"] + rot, c, sil, use_sil)
	draw_group(ci, [["cap", sh, ef, 5.0, 5.0], ["poly", _quad(sh + Vector2(0, 1), ef + Vector2(0, 2.2), 4.5, 6.0)]], c["top"], c["top_d"], sil, use_sil)
	draw_group(ci, [["cap", ef, hf, 2.9, 2.5], ["circ", hf, 1.7]], c["skin"], c["skin_d"], sil, use_sil)


func _quad(a: Vector2, b: Vector2, w0: float, w1: float) -> PackedVector2Array:
	var d := b - a
	var l := d.length()
	if l < 0.001:
		d = Vector2(0, -1)
		l = 1.0
	var n := Vector2(-d.y, d.x) / l
	return PackedVector2Array([a + n * w0 * 0.5, b + n * w1 * 0.5, b - n * w1 * 0.5, a - n * w0 * 0.5])


func _leg(ci: CanvasItem, hip: Vector2, knee: Vector2, foot: Vector2, pants: Color, wrap: Color, geta: Color, fwd: Vector2, sil: Color, use_sil: bool) -> void:
	draw_group(ci, [["cap", hip, knee, 6.8, 6.4]], pants, pants.darkened(0.4), sil, use_sil)
	draw_group(ci, [["cap", knee, foot, 3.8, 3.0]], wrap, wrap.darkened(0.4), sil, use_sil)
	var dn := Vector2(-fwd.y, fwd.x)
	var sole := PackedVector2Array([foot - fwd * 2.2 + dn * 0.8, foot + fwd * 3.6 + dn * 0.8, foot + fwd * 3.6 + dn * 1.9, foot - fwd * 2.2 + dn * 1.9])
	var tooth := PackedVector2Array([foot + fwd * 0.2 + dn * 1.9, foot + fwd * 1.6 + dn * 1.9, foot + fwd * 1.6 + dn * 3.4, foot + fwd * 0.2 + dn * 3.4])
	draw_group(ci, [["poly", sole], ["poly", tooth]], geta, geta.darkened(0.4), sil, use_sil)
	draw_group(ci, [["cap", foot - fwd * 0.8, foot + fwd * 2.4, 2.0, 1.8]], wrap, wrap.darkened(0.45), sil, use_sil)


func _wing(ci: CanvasItem, root: Vector2, open: float, flap: float, rot: float, col: Color, line: Color, hi: Color, tip: Color, sil: Color, use_sil: bool) -> void:
	var o := clampf(open, -0.6, 1.3)
	var oc := clampf(o, 0.0, 1.0)
	var ang: float
	var spread: float
	if o >= 0.0:
		ang = lerpf(-0.22, -2.05, oc) + flap * 0.55 * clampf(o + 0.2, 0.0, 1.0) + rot
		spread = lerpf(0.5, 1.5, oc)
	else:
		# wrapped forward around the body (guard)
		ang = lerpf(-0.22, 0.75, clampf(-o / 0.5, 0.0, 1.0)) + rot
		spread = -1.1
	var span := lerpf(15.0, 27.0, oc) if o >= 0.0 else 17.0
	var flen := lerpf(0.6, 1.0, oc) if o >= 0.0 else 0.9
	var d1 := Pose.dir(ang)
	var elbow := root + d1 * span * 0.45
	var d2 := Pose.dir(ang - 0.35 * oc + 0.1)
	var wtip := elbow + d2 * span * 0.58
	var fang := ang + spread
	var fd := Pose.dir(fang)
	var feathers := []
	var bases := []
	var n := 7
	for i in n:
		var t := float(i) / float(n - 1)
		var b: Vector2
		if t < 0.45:
			b = root.lerp(elbow, t / 0.45)
		else:
			b = elbow.lerp(wtip, (t - 0.45) / 0.55)
		var ln := lerpf(6.0, 13.0, t) * flen
		var fdi := Pose.dir(fang - t * 0.35 * signf(spread))
		bases.append(b)
		feathers.append(["cap", b, b + fdi * ln, 3.4, 1.6])
	var cover := PackedVector2Array([root, elbow, wtip, (bases[4] as Vector2) + fd * 5.0 * flen, (bases[2] as Vector2) + fd * 4.0 * flen, root + fd * 3.0])
	var prims := feathers.duplicate()
	prims.append(["poly", cover])
	draw_group(ci, prims, col, line, sil, use_sil)
	if not use_sil:
		ci.draw_line(root, elbow, hi, 1.0)
		ci.draw_line(elbow, wtip, hi, 1.0)
		for f in feathers.slice(4, 7):
			var a: Vector2 = f[1]
			var b2: Vector2 = f[2]
			ci.draw_line(a.lerp(b2, 0.6), b2, tip, 1.0)


func _fan(ci: CanvasItem, at: Vector2, ang: float, c: Dictionary, sil: Color, use_sil: bool) -> void:
	var pts := PackedVector2Array([at])
	var r := 8.5
	for i in 7:
		var a := ang - 0.85 + 1.7 * float(i) / 6.0
		pts.append(at + Pose.dir(a) * r)
	draw_group(ci, [["poly", pts]], c["fan"], c["fan_d"], sil, use_sil)
	if not use_sil:
		for i in range(1, 7):
			ci.draw_line(pts[i], pts[i + 1] if i < 7 else pts[i], c["fan_rim"], 1.0)
		ci.draw_line(at, at + Pose.dir(ang) * (r - 1.0), c["fan_d"].lightened(0.3), 1.0)
		ci.draw_circle(at, 1.2, c["fan_rim"])


func _head(ci: CanvasItem, j: Dictionary, c: Dictionary, rot: float, sil: Color, use_sil: bool) -> void:
	var head: Vector2 = j["head"]
	var neck: Vector2 = j["neck"]
	var ang: float = j["hdang"] + rot
	var up := Vector2(sin(ang), -cos(ang))
	var fw := Vector2(cos(ang), sin(ang))
	draw_group(ci, [["cap", neck, head - up * 2.0, 3.0, 3.0], ["circ", head, HEAD_R]], c["skin"], c["skin_d"], sil, use_sil)
	var hair_pts := [
		Vector2(5.6, 1.2), Vector2(3.8, 3.4), Vector2(4.6, 5.2), Vector2(1.5, 6.0), Vector2(-1.5, 6.2),
		Vector2(-4.5, 5.0), Vector2(-6.2, 2.5), Vector2(-6.4, -1.0), Vector2(-5.6, -5.5), Vector2(-4.0, -3.0),
		Vector2(-2.6, -0.6), Vector2(-0.2, 2.0), Vector2(2.6, 2.4),
	]
	var poly := PackedVector2Array()
	for hp in hair_pts:
		poly.append(head + fw * hp.x + up * hp.y)
	draw_group(ci, [["poly", poly]], c["hair"], c["hair_d"], sil, use_sil)
	# tokin (small tengu cap)
	var cap := PackedVector2Array()
	for cp in [Vector2(0.4, 5.6), Vector2(3.4, 6.0), Vector2(4.0, 8.0), Vector2(2.0, 9.0), Vector2(0.0, 7.8)]:
		cap.append(head + fw * cp.x + up * cp.y)
	draw_group(ci, [["poly", cap]], c["cap"], c["cap"].lightened(0.2), sil, use_sil)
	if not use_sil:
		var eye := head + fw * 3.0 - up * 0.1
		ci.draw_rect(Rect2(eye - Vector2(0.5, 1.0), Vector2(1.3, 2.1)), c["eye"])
		ci.draw_line(eye + up * -1.8 - fw * 0.6, eye + up * -1.8 + fw * 1.8, c["mark"], 1.0)
