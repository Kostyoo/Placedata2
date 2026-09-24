extends Fighter
## REN - grounded ronin with a katana.
## Double jump that reaches the ceiling, wall cling / wall jump, running,
## strong heavy slashes, counter stance and a flash-step ultimate.

var scarf: Chain
var tail: Chain
var band: Chain
var ult_victim: Fighter = null
var ult_slashes := 0
var ult_final_done := false


func _setup_stats() -> void:
	char_id = "ronin"
	display_name = "РЭН"
	max_hp = 1100.0
	walk_speed = 330.0
	run_speed = 720.0
	dash_speed = 1300.0
	dash_time = 0.15
	air_dash_speed = 1150.0
	jump_vel = 1400.0
	dbl_jump_vel = 1370.0
	super_jump_vel = 1680.0
	air_speed = 400.0
	is_flier = false
	extra_jumps = 1
	air_dashes_max = 1
	weight = 1.0
	HIP_H = 31.0
	THIGH = 15.5
	SHIN = 15.5
	TORSO = 17.0
	NECK = 2.0
	HEAD_R = 5.5
	UARM = 10.0
	LARM = 10.0
	SH_DROP = 2.5
	body_w = 17.0
	body_h = 63.0
	fx_color = Color(0.55, 0.95, 1.0)
	fx_color2 = Color(1.0, 0.72, 0.86)
	palette = {
		"skin": Color("f2c9a0"), "skin_d": Color("c7906e"),
		"hair": Color("241c33"), "hair_d": Color("120e1a"),
		"top": Color("ece6f2"), "top_d": Color("a99dbd"),
		"collar": Color("d33d4f"),
		"obi": Color("c8313f"), "obi_d": Color("7d1a2a"),
		"pants": Color("323770"), "pants_d": Color("1f2046"),
		"scarf": Color("e8384f"), "scarf_d": Color("8e1b33"),
		"blade": Color("e6eefa"), "blade_d": Color("8797b5"),
		"tsuba": Color("e8b54a"), "handle": Color("3a1e2e"), "wrap": Color("b83a4b"),
		"tabi": Color("f0ecf4"), "tabi_d": Color("a8a0b8"),
		"eye": Color("1b1622"), "saya": Color("2d1c2a"),
	}
	palette_alt = palette.duplicate()
	palette_alt.merge({
		"hair": Color("ebe6f5"), "hair_d": Color("9d97b0"),
		"top": Color("2e2440"), "top_d": Color("19131f"),
		"collar": Color("f0c14a"), "obi": Color("f0c14a"), "obi_d": Color("9a7020"),
		"pants": Color("7c2438"), "pants_d": Color("4a1422"),
		"scarf": Color("f5c84f"), "scarf_d": Color("a07a1e"),
	}, true)


func _on_alt_palette() -> void:
	fx_color = Color(1.0, 0.78, 0.38)
	fx_color2 = Color(1.0, 0.5, 0.4)
	_on_alt_moves_tint()


func _init_chains() -> void:
	scarf = Chain.new(10, 8.0)
	scarf.anchor_key = "neck"
	scarf.anchor_off = Vector2(-1.5, 1.0)
	scarf.width = 3.4
	scarf.width_end = 1.6
	scarf.grav = 520.0
	scarf.damp = 0.9
	tail = Chain.new(5, 6.5)
	tail.anchor_key = "head"
	tail.anchor_off = Vector2(-4.5, -2.5)
	tail.width = 3.2
	tail.width_end = 1.2
	tail.grav = 1100.0
	band = Chain.new(4, 5.0)
	band.anchor_key = "head"
	band.anchor_off = Vector2(-5.2, -2.6)
	band.width = 1.6
	band.width_end = 1.0
	band.grav = 450.0
	chains = [scarf, tail, band]
	for c in chains:
		c.reset(position + Vector2(0, -150))


# ================================================================ poses
func pz(d: Dictionary) -> Dictionary:
	return Pose.make(d)


func _build_poses() -> void:
	P["idle"] = pz({"hy": 2.5, "tor": 0.12, "hd": -0.08, "flx": 7, "blx": -7, "uf": 0.55, "lf": 1.45, "ub": 0.85, "lb": 1.6, "wpn": 2.05})
	P["intro"] = pz({"hy": 1.5, "tor": 0.02, "hd": 0.05, "flx": 3, "blx": -3, "uf": 0.15, "lf": 0.7, "ub": 0.4, "lb": 1.2, "wpn": -0.9})
	P["win"] = pz({"hy": 1.5, "tor": -0.05, "hd": -0.25, "flx": 5, "blx": -4, "uf": 2.9, "lf": 3.05, "ub": -0.3, "lb": 0.2, "wpn": 3.1})
	P["crouch"] = pz({"hy": 12, "tor": 0.38, "hd": -0.35, "flx": 9, "blx": -8, "uf": 0.95, "lf": 1.6, "ub": 1.15, "lb": 1.7, "wpn": 1.75})
	P["run"] = pz({"hy": 3, "tor": 0.55, "hd": -0.45, "uf": -0.9, "lf": -0.35, "ub": -1.15, "lb": -0.6, "wpn": -1.35})
	P["jump"] = pz({"ik": 0, "tor": 0.1, "hd": -0.1, "tf": 0.95, "sf": -0.25, "tb": -0.3, "sb": -0.9, "uf": 0.35, "lf": 1.25, "ub": -0.6, "lb": 0.2, "wpn": 2.4})
	P["fall"] = pz({"ik": 0, "tor": 0.05, "hd": 0.05, "tf": 0.45, "sf": 0.1, "tb": -0.2, "sb": -0.5, "uf": 1.5, "lf": 1.95, "ub": -1.2, "lb": -0.6, "wpn": 2.2})
	P["dash"] = pz({"hy": 7, "tor": 0.72, "hd": -0.55, "flx": 11, "blx": -12, "uf": -0.85, "lf": -0.5, "ub": -1.05, "lb": -0.6, "wpn": -1.42})
	P["airdash"] = pz({"ik": 0, "tor": 0.85, "hd": -0.65, "tf": 1.05, "sf": 0.3, "tb": -0.75, "sb": -1.2, "uf": -0.95, "lf": -0.6, "ub": -1.15, "lb": -0.7, "wpn": -1.45})
	P["dodge"] = pz({"hy": 7, "tor": -0.38, "hd": 0.12, "flx": 9, "fly": -3, "blx": -6, "uf": 1.2, "lf": 2.0, "ub": 0.2, "lb": 0.8, "wpn": 2.5})
	P["guard"] = pz({"hy": 5, "tor": -0.02, "hd": -0.12, "flx": 7, "blx": -8, "uf": 1.55, "lf": 2.55, "ub": 1.35, "lb": 2.35, "wpn": 2.75})
	P["parry"] = pz({"hy": 4, "tor": 0.22, "hd": -0.1, "flx": 10, "blx": -6, "uf": 1.95, "lf": 2.35, "ub": 1.55, "lb": 2.05, "wpn": 2.3})
	P["hit"] = pz({"hy": 4, "tor": -0.42, "hd": 0.45, "flx": 5, "blx": -8, "uf": -0.4, "lf": 0.25, "ub": -0.8, "lb": -0.3, "wpn": 0.35})
	P["hit_air"] = pz({"ik": 0, "tor": -0.5, "hd": 0.5, "tf": 0.6, "sf": 0.9, "tb": 0.2, "sb": 0.5, "uf": -1.0, "lf": -0.3, "ub": -1.6, "lb": -1.0, "wpn": 0.5})
	P["tumble"] = pz({"ik": 0, "tor": -0.2, "hd": 0.3, "tf": 1.3, "sf": 0.2, "tb": 0.8, "sb": -0.2, "uf": 1.8, "lf": 2.4, "ub": -1.8, "lb": -1.2, "wpn": 0.8})
	P["down"] = pz({"ik": 0, "hy": 27.5, "rot": -1.5, "tor": 0.0, "hd": -0.35, "tf": 0.35, "sf": 0.2, "tb": 0.1, "sb": -0.15, "uf": 1.1, "lf": 1.6, "ub": 0.6, "lb": 0.45, "wpn": 1.0})
	P["wall"] = pz({"ik": 0, "tor": -0.12, "hd": 0.1, "tf": 0.95, "sf": -0.3, "tb": 0.4, "sb": -0.8, "uf": 2.3, "lf": 2.7, "ub": -0.4, "lb": 0.2, "wpn": 1.8})
	P["grab"] = pz({"hy": 5, "tor": 0.3, "flx": 10, "blx": -7, "uf": 1.55, "lf": 1.65, "ub": -0.3, "lb": 0.4, "wpn": -0.8})
	P["throw_toss"] = pz({"hy": 6, "tor": -0.25, "flx": 7, "blx": -10, "uf": 2.8, "lf": 3.2, "ub": -0.5, "lb": 0.1, "wpn": -0.8})
	# --- light string
	P["l1_a"] = pz({"hy": 3, "tor": -0.05, "flx": 8, "blx": -7, "uf": -0.6, "lf": 0.2, "ub": 0.6, "lb": 1.2, "wpn": -1.8})
	P["l1_b"] = pz({"hy": 4.5, "tor": 0.35, "flx": 11, "blx": -7, "uf": 1.55, "lf": 1.6, "ub": -0.4, "lb": 0.3, "wpn": 1.65})
	P["l1_c"] = pz({"hy": 4.5, "tor": 0.3, "flx": 11, "blx": -7, "uf": 1.9, "lf": 2.3, "ub": -0.5, "lb": 0.1, "wpn": 2.6})
	P["l2_a"] = pz({"hy": 4.5, "tor": 0.28, "flx": 10, "blx": -7, "uf": 0.5, "lf": 0.3, "ub": 0.7, "lb": 0.5, "wpn": 0.35})
	P["l2_b"] = pz({"hy": 2.5, "tor": 0.05, "hd": -0.2, "flx": 10, "blx": -6, "uf": 2.45, "lf": 2.8, "ub": 1.85, "lb": 2.4, "wpn": 3.0})
	P["l2_c"] = pz({"hy": 2.5, "tor": 0.02, "flx": 10, "blx": -6, "uf": 2.6, "lf": 3.0, "ub": 2.0, "lb": 2.6, "wpn": 3.4})
	P["l3_a"] = pz({"hy": 3, "tor": -0.1, "flx": 8, "blx": -8, "uf": 2.6, "lf": 3.1, "ub": 2.2, "lb": 2.8, "wpn": -2.6})
	P["l3_b"] = pz({"hy": 6.5, "tor": 0.5, "flx": 12, "blx": -7, "uf": 1.2, "lf": 1.0, "ub": 1.0, "lb": 0.9, "wpn": 0.7})
	P["l3_c"] = pz({"hy": 3, "tor": 0.1, "flx": 12, "blx": -6, "uf": 2.5, "lf": 2.9, "ub": 2.2, "lb": 2.7, "wpn": 3.2})
	P["l3_d"] = pz({"hy": 3, "tor": 0.1, "flx": 11, "blx": -6, "uf": 2.2, "lf": 2.6, "ub": 1.9, "lb": 2.3, "wpn": 2.9})
	P["l4_a"] = pz({"hy": 6, "tor": 0.0, "flx": 6, "blx": -10, "uf": -0.2, "lf": 1.25, "ub": 0.2, "lb": 1.4, "wpn": 1.6})
	P["l4_b"] = pz({"hy": 7.5, "tor": 0.55, "hd": -0.2, "flx": 15, "blx": -11, "uf": 1.55, "lf": 1.57, "ub": 1.4, "lb": 1.5, "wpn": 1.57})
	P["l4_c"] = pz({"hy": 6.5, "tor": 0.45, "flx": 14, "blx": -10, "uf": 1.5, "lf": 1.5, "ub": 1.3, "lb": 1.45, "wpn": 1.62})
	P["upl_a"] = pz({"hy": 9, "tor": 0.32, "flx": 9, "blx": -7, "uf": 0.2, "lf": 0.0, "ub": 0.4, "lb": 0.2, "wpn": -0.4})
	P["upl_b"] = pz({"hy": 0.5, "tor": -0.1, "hd": -0.35, "flx": 6, "blx": -8, "uf": 2.8, "lf": 3.0, "ub": 2.5, "lb": 2.9, "wpn": 3.1})
	P["upl_c"] = pz({"hy": 1, "tor": -0.12, "hd": -0.3, "flx": 6, "blx": -8, "uf": 2.9, "lf": 3.2, "ub": 2.6, "lb": 3.0, "wpn": 3.45})
	P["dl_a"] = pz({"hy": 12, "tor": 0.42, "hd": -0.3, "flx": 9, "blx": -8, "uf": -0.5, "lf": 0.1, "ub": 0.1, "lb": 0.5, "wpn": -1.6})
	P["dl_b"] = pz({"hy": 13, "tor": 0.62, "hd": -0.5, "flx": 13, "blx": -8, "uf": 1.2, "lf": 1.4, "ub": 0.8, "lb": 1.0, "wpn": 1.45})
	P["rl_a"] = pz({"hy": 9, "tor": 0.72, "hd": -0.6, "flx": 12, "blx": -12, "uf": -1.0, "lf": -0.6, "ub": -1.1, "lb": -0.6, "wpn": -1.5})
	P["rl_b"] = pz({"hy": 9, "tor": 0.5, "hd": -0.4, "flx": 14, "blx": -12, "uf": 1.7, "lf": 1.8, "ub": -0.8, "lb": -0.3, "wpn": 1.7})
	P["rl_c"] = pz({"hy": 8, "tor": 0.4, "flx": 13, "blx": -11, "uf": 2.1, "lf": 2.5, "ub": -0.9, "lb": -0.4, "wpn": 2.6})
	# --- air lights
	P["al1_a"] = pz({"ik": 0, "tor": 0.0, "tf": 0.9, "sf": 0.1, "tb": 0.3, "sb": -0.5, "uf": -0.8, "lf": 0.0, "ub": 0.5, "lb": 1.0, "wpn": -1.9})
	P["al1_b"] = pz({"ik": 0, "tor": 0.35, "tf": 1.0, "sf": 0.3, "tb": 0.2, "sb": -0.6, "uf": 1.5, "lf": 1.6, "ub": -0.5, "lb": 0.2, "wpn": 1.6})
	P["al2_a"] = pz({"ik": 0, "tor": 0.3, "tf": 1.1, "sf": 0.2, "tb": 0.4, "sb": -0.4, "uf": 0.5, "lf": 0.3, "ub": 0.7, "lb": 0.5, "wpn": 0.3})
	P["al2_b"] = pz({"ik": 0, "tor": -0.05, "hd": -0.2, "tf": 0.7, "sf": -0.1, "tb": 0.1, "sb": -0.6, "uf": 2.5, "lf": 2.9, "ub": 1.9, "lb": 2.5, "wpn": 3.1})
	P["spin"] = pz({"ik": 0, "tor": 0.25, "tf": 1.3, "sf": 0.2, "tb": 1.0, "sb": -0.1, "uf": 1.57, "lf": 1.57, "ub": -1.2, "lb": -0.8, "wpn": 1.57})
	P["adl_a"] = pz({"ik": 0, "tor": -0.15, "hd": -0.2, "tf": 0.8, "sf": -0.2, "tb": 0.2, "sb": -0.8, "uf": 2.9, "lf": 3.2, "ub": 2.6, "lb": 3.0, "wpn": -2.8})
	P["adl_b"] = pz({"ik": 0, "tor": 0.6, "hd": -0.4, "tf": 1.2, "sf": 0.4, "tb": 0.3, "sb": -0.4, "uf": 0.9, "lf": 0.6, "ub": 0.7, "lb": 0.5, "wpn": 0.35})
	# --- heavies
	P["h_a"] = pz({"hy": 5, "tor": -0.25, "hd": 0.05, "flx": 9, "blx": -9, "uf": 2.7, "lf": -2.6, "ub": 2.4, "lb": -2.8, "wpn": -2.0})
	P["h_b"] = pz({"hy": 8, "tor": 0.6, "hd": -0.35, "flx": 15, "blx": -10, "uf": 1.45, "lf": 1.4, "ub": 1.3, "lb": 1.3, "wpn": 1.35})
	P["h_c"] = pz({"hy": 8, "tor": 0.55, "flx": 15, "blx": -10, "uf": 0.9, "lf": 0.7, "ub": 0.8, "lb": 0.6, "wpn": 0.55})
	P["uh_a"] = pz({"hy": 11, "tor": 0.35, "hd": -0.2, "flx": 10, "blx": -8, "uf": -0.3, "lf": -0.2, "ub": -0.1, "lb": 0.0, "wpn": -0.2})
	P["uh_b"] = pz({"hy": 0.5, "tor": -0.2, "hd": -0.45, "flx": 7, "fly": -2, "blx": -8, "uf": 3.0, "lf": 3.1, "ub": 2.8, "lb": 3.0, "wpn": 3.14})
	P["uh_c"] = pz({"hy": 1.5, "tor": -0.15, "hd": -0.35, "flx": 7, "blx": -8, "uf": 2.9, "lf": 3.3, "ub": 2.7, "lb": 3.2, "wpn": 3.6})
	P["dh_a"] = pz({"hy": 13, "tor": 0.3, "hd": -0.2, "flx": 7, "blx": -10, "uf": -1.2, "lf": -0.9, "ub": -1.0, "lb": -0.8, "wpn": -1.7})
	P["dh_b"] = pz({"hy": 15, "tor": 0.65, "hd": -0.5, "flx": 15, "fly": 0, "blx": -12, "uf": 1.3, "lf": 1.5, "ub": 1.2, "lb": 1.4, "wpn": 1.5})
	P["ah_a"] = pz({"ik": 0, "tor": -0.3, "tf": 0.7, "sf": -0.3, "tb": 0.0, "sb": -0.9, "uf": 2.8, "lf": -2.7, "ub": 2.5, "lb": -2.9, "wpn": -2.2})
	P["ah_b"] = pz({"ik": 0, "tor": 0.7, "hd": -0.4, "tf": 1.2, "sf": 0.3, "tb": 0.2, "sb": -0.6, "uf": 1.1, "lf": 0.9, "ub": 1.0, "lb": 0.8, "wpn": 0.8})
	P["auh_a"] = pz({"ik": 0, "tor": 0.35, "tf": 1.2, "sf": 0.3, "tb": 0.6, "sb": -0.3, "uf": 0.1, "lf": -0.1, "ub": 0.2, "lb": 0.0, "wpn": -0.3})
	P["auh_b"] = pz({"ik": 0, "tor": -0.25, "hd": -0.4, "tf": 0.4, "sf": 0.1, "tb": -0.2, "sb": -0.5, "uf": 3.0, "lf": 3.1, "ub": 2.8, "lb": 3.0, "wpn": 3.2})
	P["plunge"] = pz({"ik": 0, "tor": 0.15, "hd": 0.3, "tf": 0.5, "sf": 0.0, "tb": 0.2, "sb": -0.4, "uf": 0.1, "lf": 0.05, "ub": 0.2, "lb": 0.1, "wpn": 0.0})
	P["plunge_a"] = pz({"ik": 0, "tor": -0.1, "tf": 1.4, "sf": -0.3, "tb": 1.0, "sb": -0.6, "uf": 2.9, "lf": 3.1, "ub": 2.7, "lb": 3.0, "wpn": 3.1})
	# --- abilities
	P["sheathe"] = pz({"hy": 9, "tor": 0.5, "hd": -0.3, "flx": 12, "blx": -10, "uf": 0.9, "lf": 1.9, "ub": 0.3, "lb": 1.5, "wpn": -1.2})
	P["iai"] = pz({"hy": 10, "tor": 0.55, "hd": -0.35, "flx": 16, "blx": -11, "uf": 1.6, "lf": 1.6, "ub": -1.0, "lb": -0.4, "wpn": 1.6})
	P["iai_end"] = pz({"hy": 9, "tor": 0.45, "hd": -0.3, "flx": 16, "blx": -11, "uf": 2.2, "lf": 2.6, "ub": -1.1, "lb": -0.5, "wpn": 2.9})
	P["cast"] = pz({"hy": 6, "tor": -0.1, "flx": 9, "blx": -8, "uf": 2.5, "lf": -2.7, "ub": 0.3, "lb": 0.9, "wpn": -2.3})
	P["cast_b"] = pz({"hy": 8, "tor": 0.5, "hd": -0.3, "flx": 14, "blx": -9, "uf": 1.4, "lf": 1.3, "ub": -0.6, "lb": 0.0, "wpn": 1.2})
	P["counter"] = pz({"hy": 8, "tor": 0.05, "hd": 0.0, "flx": 8, "blx": -9, "uf": 0.6, "lf": 1.9, "ub": 0.5, "lb": 1.6, "wpn": -1.3})


# ================================================================ moves
func _build_moves() -> void:
	var cyan := fx_color
	moves["l1"] = mv({"name": "l1", "startup": 0.07, "active": 0.06, "recovery": 0.17, "box": Rect2(8, -60, 36, 36),
		"dmg": 32, "hitstun": 0.32, "kb": Vector2(140, 0), "air_kb": Vector2(170, 260), "next": "l2",
		"sfx": "slash_l", "hit_sfx": "hit_slash", "spark": "slash", "poses": ["l1_a", "l1_b", "l1_c"],
		"slash": {"c": Vector2(2, -44), "r": 26, "a0": -160, "a1": 25, "w": 6}, "lunge": Vector2(180, 0), "lunge_t0": 0.04, "lunge_t1": 0.12})
	moves["l2"] = mv({"name": "l2", "startup": 0.08, "active": 0.06, "recovery": 0.2, "box": Rect2(6, -72, 34, 50),
		"dmg": 36, "hitstun": 0.34, "kb": Vector2(160, 0), "air_kb": Vector2(160, 380), "next": "l3",
		"sfx": "slash_l", "hit_sfx": "hit_slash", "spark": "slash", "poses": ["l2_a", "l2_b", "l2_c"],
		"slash": {"c": Vector2(3, -42), "r": 27, "a0": 60, "a1": -100, "w": 6}, "lunge": Vector2(160, 0), "lunge_t0": 0.05, "lunge_t1": 0.13})
	moves["l3"] = mv({"name": "l3", "startup": 0.09, "active": 0.16, "recovery": 0.22, "box": Rect2(6, -66, 38, 48),
		"hits": 2, "hit_every": 0.08, "dmg": 24, "hitstun": 0.36, "kb": Vector2(120, 0), "air_kb": Vector2(150, 300), "next": "l4",
		"sfx": "slash_l", "hit_sfx": "hit_slash", "spark": "slash", "poses": ["l3_a", "l3_b", "l3_c", "l3_d"],
		"slash": [{"c": Vector2(3, -44), "r": 28, "a0": -120, "a1": 50, "w": 6}, {"t": 0.08, "c": Vector2(3, -44), "r": 28, "a0": 50, "a1": -110, "w": 6}],
		"lunge": Vector2(200, 0), "lunge_t0": 0.07, "lunge_t1": 0.2})
	moves["l4"] = mv({"name": "l4", "startup": 0.13, "active": 0.08, "recovery": 0.32, "box": Rect2(10, -52, 50, 18),
		"dmg": 62, "hitstun": 0.55, "kb": Vector2(680, 300), "air_kb": Vector2(680, 320), "launch": true, "knockdown": true,
		"wall_bounce": true, "hitstop": 0.11, "shake": 6.0, "zoom": 0.05, "strength": 2, "guard_dmg": 22,
		"sfx": "slash_h", "hit_sfx": "hit_h", "spark": "heavy", "poses": ["l4_a", "l4_b", "l4_c"],
		"slash": {"type": "thrust", "c": Vector2(12, -43), "len": 56, "w": 7}, "lunge": Vector2(720, 0), "lunge_t0": 0.1, "lunge_t1": 0.2})
	moves["up_l"] = mv({"name": "up_l", "startup": 0.09, "active": 0.09, "recovery": 0.26, "box": Rect2(-6, -92, 36, 64),
		"dmg": 45, "hitstun": 0.55, "kb": Vector2(60, 950), "air_kb": Vector2(60, 950), "launch": true, "anti_air": true, "jump_cancel": true,
		"hitstop": 0.08, "shake": 3.0, "sfx": "slash_l", "hit_sfx": "hit_slash", "spark": "slash", "poses": ["upl_a", "upl_b", "upl_c"],
		"slash": {"c": Vector2(2, -44), "r": 32, "a0": 80, "a1": -100, "w": 7}})
	moves["down_l"] = mv({"name": "down_l", "startup": 0.07, "active": 0.07, "recovery": 0.2, "box": Rect2(4, -24, 40, 22),
		"dmg": 30, "hitstun": 0.34, "kb": Vector2(180, 0), "next": "l2", "otg": false,
		"sfx": "slash_l", "hit_sfx": "hit_slash", "spark": "slash", "poses": ["dl_a", "dl_b", "dl_b"],
		"slash": {"c": Vector2(6, -24), "r": 24, "a0": -150, "a1": 30, "w": 5}})
	moves["run_l"] = mv({"name": "run_l", "startup": 0.08, "active": 0.12, "recovery": 0.26, "box": Rect2(6, -60, 44, 42),
		"dmg": 50, "hitstun": 0.45, "kb": Vector2(460, 240), "air_kb": Vector2(460, 300), "launch": true, "keep_momentum": true,
		"hitstop": 0.08, "shake": 4.0, "sfx": "slash_h", "hit_sfx": "hit_slash", "spark": "slash", "poses": ["rl_a", "rl_b", "rl_c"],
		"slash": {"c": Vector2(4, -42), "r": 34, "a0": -170, "a1": 40, "w": 8}, "lunge": Vector2(820, 0), "lunge_t0": 0.0, "lunge_t1": 0.2})
	# air
	moves["air_l1"] = mv({"name": "air_l1", "air": true, "startup": 0.06, "active": 0.07, "recovery": 0.16, "box": Rect2(6, -62, 38, 40),
		"dmg": 30, "hitstun": 0.34, "kb": Vector2(120, 0), "air_kb": Vector2(170, 220), "air_stall": 200, "next": "air_l2",
		"sfx": "slash_l", "hit_sfx": "hit_slash", "spark": "slash", "poses": ["al1_a", "al1_b", "al1_b"],
		"slash": {"c": Vector2(2, -44), "r": 26, "a0": -160, "a1": 30, "w": 6}})
	moves["air_l2"] = mv({"name": "air_l2", "air": true, "startup": 0.07, "active": 0.07, "recovery": 0.18, "box": Rect2(4, -76, 38, 54),
		"dmg": 34, "hitstun": 0.36, "kb": Vector2(140, 0), "air_kb": Vector2(160, 340), "air_stall": 260, "next": "air_l3",
		"sfx": "slash_l", "hit_sfx": "hit_slash", "spark": "slash", "poses": ["al2_a", "al2_b", "al2_b"],
		"slash": {"c": Vector2(3, -42), "r": 28, "a0": 70, "a1": -100, "w": 6}})
	moves["air_l3"] = mv({"name": "air_l3", "air": true, "startup": 0.06, "active": 0.22, "recovery": 0.2, "box": Rect2(-30, -76, 72, 64),
		"hits": 2, "hit_every": 0.11, "dmg": 27, "hitstun": 0.42, "kb": Vector2(300, 0), "air_kb": Vector2(420, 460), "air_stall": 240,
		"sfx": "swing_h", "hit_sfx": "hit_slash", "spark": "slash", "pose_fn": "_pose_spin",
		"slash": [{"type": "circle", "c": Vector2(0, -40), "r": 34, "w": 7}, {"t": 0.11, "type": "circle", "c": Vector2(0, -40), "r": 34, "w": 7}]})
	moves["air_up_l"] = mv({"name": "air_up_l", "air": true, "startup": 0.07, "active": 0.08, "recovery": 0.2, "box": Rect2(-8, -96, 38, 60),
		"dmg": 36, "hitstun": 0.45, "air_kb": Vector2(60, 720), "kb": Vector2(60, 720), "launch": true, "anti_air": true, "air_stall": 300,
		"sfx": "slash_l", "hit_sfx": "hit_slash", "spark": "slash", "poses": ["al2_a", "al2_b", "al2_b"],
		"slash": {"c": Vector2(2, -46), "r": 32, "a0": 80, "a1": -100, "w": 6}})
	moves["air_down_l"] = mv({"name": "air_down_l", "air": true, "startup": 0.1, "active": 0.08, "recovery": 0.25, "box": Rect2(0, -40, 42, 48),
		"dmg": 48, "hitstun": 0.5, "kb": Vector2(160, 0), "air_kb": Vector2(160, -1100), "ground_bounce": true, "knockdown": true,
		"hitstop": 0.09, "shake": 5.0, "sfx": "slash_h", "hit_sfx": "hit_m", "spark": "heavy", "strength": 1, "poses": ["adl_a", "adl_b", "adl_b"],
		"slash": {"c": Vector2(2, -40), "r": 32, "a0": -110, "a1": 70, "w": 7}})
	# heavies
	moves["h"] = mv({"name": "h", "kind": "heavy", "startup": 0.2, "active": 0.08, "recovery": 0.4, "box": Rect2(6, -70, 50, 60),
		"dmg": 90, "hitstun": 0.6, "kb": Vector2(720, 320), "air_kb": Vector2(720, 340), "launch": true, "knockdown": true, "wall_bounce": true,
		"hitstop": 0.13, "shake": 8.0, "zoom": 0.07, "strength": 2, "guard_dmg": 32, "chargeable": true,
		"sfx": "slash_h", "hit_sfx": "hit_h", "spark": "heavy", "poses": ["h_a", "h_b", "h_c"],
		"slash": {"c": Vector2(2, -46), "r": 40, "a0": -150, "a1": 55, "w": 10, "life": 0.22}, "lunge": Vector2(420, 0), "lunge_t0": 0.17, "lunge_t1": 0.28})
	moves["up_h"] = mv({"name": "up_h", "kind": "heavy", "startup": 0.16, "active": 0.1, "recovery": 0.38, "box": Rect2(-2, -104, 40, 90),
		"dmg": 70, "hitstun": 0.8, "kb": Vector2(40, 1320), "air_kb": Vector2(40, 1250), "launch": true, "jump_cancel": true, "anti_air": true,
		"hitstop": 0.1, "shake": 5.0, "strength": 2, "guard_dmg": 24, "sfx": "slash_h", "hit_sfx": "hit_h", "spark": "heavy",
		"poses": ["uh_a", "uh_b", "uh_c"], "slash": {"c": Vector2(4, -46), "r": 40, "a0": 90, "a1": -95, "w": 9, "life": 0.2}})
	moves["down_h"] = mv({"name": "down_h", "kind": "heavy", "startup": 0.14, "active": 0.1, "recovery": 0.38, "box": Rect2(0, -22, 56, 22),
		"dmg": 60, "hitstun": 0.6, "kb": Vector2(260, 560), "air_kb": Vector2(260, 560), "launch": true, "knockdown": true, "otg": true,
		"hitstop": 0.09, "shake": 4.0, "strength": 1, "guard_dmg": 22, "sfx": "slash_h", "hit_sfx": "hit_m", "spark": "heavy",
		"poses": ["dh_a", "dh_b", "dh_b"], "slash": {"c": Vector2(8, -20), "r": 34, "a0": -170, "a1": 20, "w": 7}})
	moves["air_h"] = mv({"name": "air_h", "kind": "heavy", "air": true, "startup": 0.13, "active": 0.1, "recovery": 0.3, "box": Rect2(4, -72, 50, 70),
		"dmg": 75, "hitstun": 0.55, "kb": Vector2(620, 300), "air_kb": Vector2(620, -380), "knockdown": true, "wall_bounce": true,
		"hitstop": 0.12, "shake": 7.0, "zoom": 0.05, "strength": 2, "guard_dmg": 28, "chargeable": true,
		"sfx": "slash_h", "hit_sfx": "hit_h", "spark": "heavy", "poses": ["ah_a", "ah_b", "ah_b"],
		"slash": {"c": Vector2(2, -44), "r": 40, "a0": -140, "a1": 70, "w": 10, "life": 0.2}})
	moves["air_up_h"] = mv({"name": "air_up_h", "kind": "heavy", "air": true, "startup": 0.12, "active": 0.1, "recovery": 0.3, "box": Rect2(-10, -110, 46, 78),
		"dmg": 62, "hitstun": 0.65, "kb": Vector2(60, 1050), "air_kb": Vector2(60, 1050), "launch": true, "anti_air": true,
		"hitstop": 0.1, "shake": 5.0, "strength": 2, "sfx": "slash_h", "hit_sfx": "hit_h", "spark": "heavy", "poses": ["auh_a", "auh_b", "auh_b"],
		"slash": {"c": Vector2(2, -46), "r": 40, "a0": 90, "a1": -95, "w": 9}})
	moves["air_down_h"] = mv({"name": "air_down_h", "kind": "heavy", "air": true, "startup": 0.12, "active": 0.6, "recovery": 0.3, "box": Rect2(-10, -30, 26, 44),
		"dmg": 70, "hitstun": 0.55, "kb": Vector2(200, 0), "air_kb": Vector2(200, -1300), "ground_bounce": true, "knockdown": true,
		"hitstop": 0.11, "shake": 6.0, "strength": 2, "sfx": "swing_h", "hit_sfx": "hit_h", "spark": "heavy", "poses": ["plunge_a", "plunge", "plunge"],
		"lunge": Vector2(0, -1900), "lunge_t0": 0.12, "lunge_t1": 0.72, "landing_lag": 0.18})
	moves["throw"] = mv({"name": "throw", "kind": "throw", "throw": true, "startup": 0.06, "active": 0.06, "recovery": 0.35,
		"box": Rect2(4, -54, 24, 46), "dmg": 90, "sfx": "swing_m", "poses": ["grab", "grab", "idle"]})
	# abilities
	moves["q"] = mv({"name": "q", "kind": "special", "startup": 0.1, "active": 0.05, "recovery": 0.3, "invuln": Vector2(0.0, 0.3),
		"box": Rect2(), "dmg": 72, "hitstun": 0.7, "kb": Vector2(260, 420), "air_kb": Vector2(260, 460), "launch": true,
		"hitstop": 0.1, "spawn_t": 0.1, "spawn": "_do_flash_step", "cd_key": "q", "cd": 5.0, "sfx": "", "hit_sfx": "hit_slash",
		"spark": "slash", "strength": 2, "poses": ["sheathe", "iai", "iai_end"], "cancel_special": false, "hover": true})
	moves["air_q"] = moves["q"].duplicate(true)
	moves["air_q"]["air"] = true
	moves["air_q"]["end_on_land"] = false
	moves["e"] = mv({"name": "e", "kind": "special", "startup": 0.16, "active": 0.05, "recovery": 0.28, "box": Rect2(),
		"spawn_t": 0.16, "spawn": "_spawn_crescent", "cd_key": "e", "cd": 4.0, "sfx": "", "poses": ["cast", "cast_b", "cast_b"], "cancel_special": false})
	moves["air_e"] = moves["e"].duplicate(true)
	moves["air_e"]["air"] = true
	moves["air_e"]["hover"] = true
	moves["air_e"]["end_on_land"] = false
	moves["r"] = mv({"name": "r", "kind": "special", "startup": 0.04, "active": 0.72, "recovery": 0.34, "box": Rect2(),
		"cd_key": "r", "cd": 9.0, "sfx": "", "poses": ["counter", "counter", "counter", "idle"], "cancel_special": false, "hover": true})
	moves["r_strike"] = mv({"name": "r_strike", "kind": "special", "startup": 0.03, "active": 0.08, "recovery": 0.34, "box": Rect2(-4, -74, 60, 72),
		"dmg": 115, "hitstun": 0.8, "kb": Vector2(420, 900), "air_kb": Vector2(420, 900), "launch": true, "knockdown": true, "unblockable": true, "parryable": false,
		"hitstop": 0.16, "shake": 9.0, "zoom": 0.08, "strength": 2, "sfx": "", "hit_sfx": "hit_h", "spark": "heavy", "poses": ["sheathe", "iai", "iai_end"],
		"slash": {"c": Vector2(4, -46), "r": 44, "a0": 100, "a1": -110, "w": 11, "life": 0.25}, "hover": true, "cancel_special": false})
	moves["ult"] = mv({"name": "ult", "kind": "ult", "ult": true, "startup": 0.1, "active": 0.28, "recovery": 0.5, "box": Rect2(-4, -64, 44, 64),
		"dmg": 30, "hitstun": 1.0, "kb": Vector2(0, 0), "air_kb": Vector2(0, 0), "invuln": Vector2(0.0, 0.42), "guard_dmg": 55, "chip": 0.4,
		"hitstop": 0.05, "sfx": "", "hit_sfx": "hit_slash", "spark": "slash", "on_hit": "_ult_connect", "poses": ["sheathe", "iai", "iai_end"],
		"lunge": Vector2(1850, 0), "lunge_t0": 0.1, "lunge_t1": 0.38, "hover": true, "cancel_special": false})
	moves["ult_combo"] = mv({"name": "ult_combo", "kind": "ult", "startup": 0.0, "active": 1.45, "recovery": 0.55, "box": Rect2(),
		"invuln": Vector2(0.0, 2.2), "update": "_upd_ult_combo", "pose_fn": "_pose_ult_combo", "hover": true, "sfx": "", "cancel_special": false})
	# slash tint
	for k in moves:
		var s = moves[k]["slash"]
		if s is Dictionary and not s.is_empty():
			s["col"] = cyan
		elif s is Array:
			for e in s:
				e["col"] = cyan


func _on_alt_moves_tint() -> void:
	for k in moves:
		var s = moves[k]["slash"]
		if s is Dictionary and not s.is_empty():
			s["col"] = fx_color
		elif s is Array:
			for e in s:
				e["col"] = fx_color


func _pose_spin() -> Dictionary:
	var su: float = cur_move["startup"]
	var ac: float = cur_move["active"]
	var k := clampf((move_t - su) / ac, 0.0, 1.0)
	var p: Dictionary = P["spin"].duplicate()
	if move_t < su:
		return Pose.blend(move_from_pose, P["al1_a"], move_t / su)
	p["rot"] = TAU * 2.0 * Pose.ease_in_out(k)
	pose["rot"] = p["rot"]
	if move_t > su + ac:
		var kr := (move_t - su - ac) / float(cur_move["recovery"])
		p["rot"] = 0.0
		pose["rot"] = 0.0
		return Pose.blend(p, P["fall"], kr)
	return p


# ================================================================ abilities
func _on_move_start(n: String, _m: Dictionary) -> void:
	match n:
		"ult":
			arena.super_freeze(self, 0.85, "СЭНБОНДЗАКУРА", "Тысяча лепестков")
			ult_victim = null
		"q", "air_q":
			snd("charge", -8, 1.8)
		"r":
			snd("counter", -10, 0.7)
			fx().ring(center_pos(), Color(fx_color, 0.6), 60, 20, 0.3, 3)
		"e", "air_e":
			snd("swing_m", -4, 0.8)


func _do_flash_step() -> void:
	var start := position
	var dist := 340.0
	var tx := clampf(position.x + facing * dist, Cfg.WALL_L + 40, Cfg.WALL_R - 40)
	var end := Vector2(tx, position.y)
	for i in 6:
		var t := float(i) / 6.0
		fx().afterimage(self, Color(fx_color, 0.55 - t * 0.3), 0.3, start.lerp(end, t))
	var path := Rect2(minf(start.x, end.x), position.y - body_h * PX, absf(end.x - start.x), body_h * PX)
	position = end
	snd("flash_step")
	var a := start + Vector2(0, -body_h * PX * 0.6)
	var b := end + Vector2(0, -body_h * PX * 0.6)
	fx().line_flash(a, b, fx_color, 0.35)
	arena.petals.impulse((a + b) * 0.5, 260.0, Vector2(facing * 700, -100))
	if opponent != null and path.intersects(opponent.hurtbox()):
		var res: int = arena.resolve_direct_hit(self, opponent, cur_move, facing, 0.28)
		if res == R.HIT:
			fx().petal_burst(opponent.center_pos(), 18, Vector2(facing * 200, -100))
	arena.cam_shake(3.0)


func _spawn_crescent() -> void:
	var a := inp.aim
	var ang := atan2(a.y, a.x * facing)
	ang = clampf(ang, -0.62, 0.62)
	var d := Vector2(cos(ang) * facing, sin(ang))
	var data := mv({"name": "crescent", "kind": "special", "dmg": 58, "hitstun": 0.48, "kb": Vector2(300, 0), "air_kb": Vector2(300, 360),
		"hitstop": 0.08, "shake": 3.0, "hit_sfx": "hit_slash", "spark": "slash", "strength": 1, "guard_dmg": 16, "chip": 0.15})
	arena.spawn_projectile("crescent", self, chest_pos() + d * 40.0, d * 960.0, data)
	snd("crescent")
	fx().ring(chest_pos() + d * 40.0, Color(fx_color, 0.8), 8, 44, 0.2, 3)


func counter_ready(m: Dictionary, _from_proj: bool) -> bool:
	return state == S.ATTACK and move_name == "r" and move_t >= 0.03 and move_t < 0.76 and not bool(m["throw"])


func on_countered(atk: Fighter, from_proj: bool) -> void:
	snd("counter")
	flash_t = 0.12
	flash_color = Color(0.8, 1, 1)
	arena.slowmo(0.3, 0.45, self)
	fx().text(head_pos() + Vector2(0, -30), "КАГАМИ!", fx_color, 2)
	cooldowns["r"] = 4.0
	if from_proj or atk == null or atk.position.distance_to(position) > 460.0:
		interrupt_move()
		start_move("e")
		move_t = 0.14
		cooldowns["e"] = 0.0
		return
	var behind_x := clampf(atk.position.x - atk.facing * 72.0, Cfg.WALL_L + 30, Cfg.WALL_R - 30)
	fx().afterimage(self, Color(fx_color, 0.6), 0.35)
	fx().line_flash(center_pos(), Vector2(behind_x, atk.center_pos().y), fx_color, 0.25)
	position = Vector2(behind_x, minf(atk.position.y, Cfg.FLOOR_Y))
	on_ground = position.y >= Cfg.FLOOR_Y - 0.5
	vel = Vector2.ZERO
	facing = 1 if atk.position.x > position.x else -1
	atk.get_parried()
	atk.stun_time = 0.45
	interrupt_move()
	start_move("r_strike")
	snd("slash_h", 0, 0.9)


# ---------------------------------------------------------------- ultimate
func _ult_connect(def: Fighter) -> void:
	if not def.alive:
		return
	ult_victim = def
	ult_slashes = 0
	ult_final_done = false
	def.lock_for_ult()
	interrupt_move()
	start_move("ult_combo")
	vanished = true
	snd("ult_hit", -2, 1.2)
	arena.cam_punch(0.12)
	fx().petal_burst(def.center_pos(), 30, Vector2.ZERO)


func _upd_ult_combo(_dt: float) -> void:
	var v := ult_victim
	if v == null:
		vanished = false
		return
	var c := v.center_pos()
	var n := int(move_t / 0.1)
	while ult_slashes < mini(n, 11) and not ult_final_done:
		ult_slashes += 1
		var ang := randf_range(0.0, TAU)
		var d := Vector2.from_angle(ang)
		var col := fx_color if ult_slashes % 2 == 0 else fx_color2
		fx().line_flash(c - d * 110.0, c + d * 110.0, col, 0.22)
		var tick := mv({"name": "ult_tick", "kind": "ult", "dmg": 17, "hitstun": 0.5, "kb": Vector2.ZERO, "air_kb": Vector2.ZERO,
			"unblockable": true, "parryable": false, "ult_hit": true, "hitstop": 0.02, "shake": 2.0, "hit_sfx": "hit_slash", "spark": "slash"})
		arena.resolve_direct_hit(self, v, tick, 1 if d.x >= 0 else -1)
		if v.alive:
			v.lock_for_ult()
		else:
			move_t = maxf(move_t, 1.25)
		fx().petal_burst(c, 4, d * 200.0)
		snd("slash_l", -3, randf_range(0.9, 1.3))
	if move_t >= 1.25 and not ult_final_done:
		ult_final_done = true
		vanished = false
		var side := 1 if position.x < v.position.x else -1
		position = Vector2(clampf(v.position.x + side * 110.0, Cfg.WALL_L + 30, Cfg.WALL_R - 30), Cfg.FLOOR_Y if v.position.y > Cfg.FLOOR_Y - 60 else v.position.y)
		on_ground = position.y >= Cfg.FLOOR_Y - 0.5
		facing = side
		vel = Vector2.ZERO
		var fin := mv({"name": "ult_final", "kind": "ult", "dmg": 150, "hitstun": 1.0, "kb": Vector2(260, 1000), "air_kb": Vector2(260, 1000),
			"launch": true, "knockdown": true, "unblockable": true, "parryable": false, "ult_hit": true, "hitstop": 0.3,
			"shake": 14.0, "zoom": 0.12, "hit_sfx": "ult_hit", "spark": "ult", "strength": 3})
		if v.alive:
			v.state = S.HITSTUN
		arena.resolve_direct_hit(self, v, fin, side)
		fx().petal_burst(c, 60, Vector2.ZERO)
		fx().ring(c, Color(fx_color2, 0.9), 20, 260, 0.6, 8)
		fx().ring(c, Color(1, 1, 1, 0.9), 10, 180, 0.45, 5)
		arena.screen_flash(Color(1, 0.85, 0.95), 0.35)
		snd("counter", 0, 0.6)


func _pose_ult_combo() -> Dictionary:
	if move_t < 1.25:
		return P["iai"]
	var k := (move_t - 1.25) / 0.6
	return Pose.blend(P["iai_end"], P["intro"], Pose.ease_in_out(k))


func _extra_hitboxes(_res: Array) -> void:
	pass


func _move_landed(m: Dictionary) -> void:
	if m["name"] == "air_down_h":
		fx().shockwave(position, fx_color)
		arena.petals.impulse(position, 300.0, Vector2(0, -500))
		arena.cam_shake(6.0)
		snd("hit_h", -2, 0.7)
		if opponent != null and opponent.on_ground and absf(opponent.position.x - position.x) < 150.0:
			var sw := mv({"name": "quake", "kind": "heavy", "dmg": 35, "hitstun": 0.5, "kb": Vector2(200, 600), "air_kb": Vector2(200, 600),
				"launch": true, "knockdown": true, "hitstop": 0.08, "shake": 4.0, "hit_sfx": "hit_m", "spark": "heavy", "strength": 1, "guard_dmg": 20})
			arena.resolve_direct_hit(self, opponent, sw, 1 if opponent.position.x > position.x else -1)


func _update_state(dt: float) -> void:
	super._update_state(dt)
	# charged / ult-ready aura sparkles
	aura_t -= dt
	if aura_t <= 0.0:
		aura_t = 0.12
		if ki >= Cfg.KI_MAX and alive:
			fx().aura_spark(self, fx_color2)
		if state == S.ATTACK and move_name == "r" and move_t < 0.76:
			fx().aura_spark(self, fx_color)


# ================================================================ drawing
func draw_body(ci: CanvasItem, p: Dictionary, j: Dictionary, sil: Color, use_sil: bool) -> void:
	if j.is_empty():
		return
	var c := palette
	var rot: float = j["rot"]
	var hip: Vector2 = j["hip"]
	var neck: Vector2 = j["neck"]
	var head: Vector2 = j["head"]
	var sh: Vector2 = j["sh"]
	var td := (neck - hip).normalized()
	var pp := Vector2(-td.y, td.x)
	var fwd := Vector2(1, 0).rotated(rot)

	# chains behind the body
	draw_chain(ci, scarf, c["scarf"], c["scarf_d"], sil, use_sil)
	draw_chain(ci, tail, c["hair"], c["hair_d"], sil, use_sil)

	# back arm
	draw_group(ci, [["cap", sh, j["eb"], 5.0, 4.5]], c["top_d"], c["top_d"].darkened(0.35), sil, use_sil)
	draw_group(ci, [["cap", j["eb"], j["hb"], 3.0, 2.6], ["circ", j["hb"], 1.6]], c["skin_d"], c["skin_d"].darkened(0.35), sil, use_sil)

	# scabbard at the hip (behind)
	var saya_a := hip + (Vector2(1, -2)).rotated(rot)
	var saya_b := hip + (Vector2(-15, 6)).rotated(rot)
	draw_group(ci, [["cap", saya_a, saya_b, 2.2, 2.0]], c["saya"], c["saya"].darkened(0.4), sil, use_sil)

	# back leg (hakama)
	_leg(ci, hip, j["kb"], j["fb"], c["pants_d"], c["tabi_d"], fwd, sil, use_sil)

	# torso: hakama top, kimono, obi, collar
	var torso := [
		["poly", _quad(hip + td * 2.0, neck - td * 0.5, 8.5, 10.5)],
	]
	draw_group(ci, torso, c["top"], c["top_d"], sil, use_sil)
	var hk := [["poly", _quad(hip + td * 2.5, hip - td * 4.5, 9.5, 11.0)]]
	draw_group(ci, hk, c["pants"], c["pants_d"], sil, use_sil)
	draw_group(ci, [["poly", _quad(hip + td * 1.8, hip + td * 4.4, 9.4, 9.2)]], c["obi"], c["obi_d"], sil, use_sil)
	if not use_sil:
		var ca := neck - td * 0.5 + pp * 2.5
		var cb := neck - td * 6.5 + pp * 1.0
		var cc := neck - td * 0.5 - pp * 1.5
		ci.draw_line(ca, cb, c["collar"], 1.0)
		ci.draw_line(cc, cb, c["collar"], 1.0)
		# kimono shading on the back side
		ci.draw_line(hip + td * 4.8 - pp * 3.8, neck - td * 1.5 - pp * 4.6, c["top_d"], 1.0)
		# obi knot
		ci.draw_circle(hip + td * 3.0 - pp * 5.2, 1.4, c["obi_d"])

	# front leg
	_leg(ci, hip, j["kf"], j["ff"], c["pants"], c["tabi"], fwd, sil, use_sil)

	# head
	_head(ci, j, c, rot, sil, use_sil)

	# sword
	var wd := Pose.dir(p["wpn"] + rot)
	var hf: Vector2 = j["hf"]
	var wn := Vector2(-wd.y, wd.x)
	draw_group(ci, [["cap", hf - wd * 4.5, hf + wd * 1.2, 1.8, 1.8]], c["handle"], c["handle"].darkened(0.4), sil, use_sil)
	draw_group(ci, [["poly", PackedVector2Array([hf + wd * 2.0 + wn * 0.9, hf + wd * 25.0 + wn * 0.5, hf + wd * 27.5, hf + wd * 25.0 - wn * 0.9, hf + wd * 2.0 - wn * 0.9])]], c["blade"], c["blade_d"], sil, use_sil)
	draw_group(ci, [["cap", hf + wd * 1.7 + wn * 2.0, hf + wd * 1.7 - wn * 2.0, 1.3, 1.3]], c["tsuba"], c["tsuba"].darkened(0.4), sil, use_sil)
	if not use_sil:
		ci.draw_line(hf + wd * 3.0 + wn * 0.3, hf + wd * 24.0 + wn * 0.2, Color(1, 1, 1, 0.9), 1.0)
		ci.draw_circle(hf - wd * 2.0, 0.7, c["wrap"])

	# front arm (wide sleeve)
	var ef: Vector2 = j["ef"]
	draw_group(ci, [["cap", sh, ef, 5.5, 5.5], ["poly", _quad(sh + Vector2(0, 1), ef + Vector2(0, 2.5), 5.0, 6.5)]], c["top"], c["top_d"], sil, use_sil)
	draw_group(ci, [["cap", ef, hf, 3.2, 2.7], ["circ", hf, 1.8]], c["skin"], c["skin_d"], sil, use_sil)


func _quad(a: Vector2, b: Vector2, w0: float, w1: float) -> PackedVector2Array:
	var d := b - a
	var l := d.length()
	if l < 0.001:
		d = Vector2(0, -1)
		l = 1.0
	var n := Vector2(-d.y, d.x) / l
	return PackedVector2Array([a + n * w0 * 0.5, b + n * w1 * 0.5, b - n * w1 * 0.5, a - n * w0 * 0.5])


func _leg(ci: CanvasItem, hip: Vector2, knee: Vector2, foot: Vector2, pants: Color, tabi: Color, fwd: Vector2, sil: Color, use_sil: bool) -> void:
	var ankle := foot + (knee - foot).normalized() * 2.0
	var prims := [
		["cap", hip, knee, 7.5, 7.5],
		["poly", _quad(knee, ankle, 7.5, 10.0)],
	]
	draw_group(ci, prims, pants, pants.darkened(0.4), sil, use_sil)
	draw_group(ci, [["cap", foot - fwd * 1.0, foot + fwd * 3.0, 2.4, 2.2]], tabi, tabi.darkened(0.45), sil, use_sil)


func _head(ci: CanvasItem, j: Dictionary, c: Dictionary, rot: float, sil: Color, use_sil: bool) -> void:
	var head: Vector2 = j["head"]
	var neck: Vector2 = j["neck"]
	var ang: float = j["hdang"] + rot
	var up := Vector2(sin(ang), -cos(ang))
	var fw := Vector2(cos(ang), sin(ang))
	draw_group(ci, [["cap", neck, head - up * 2.0, 3.2, 3.2], ["circ", head, HEAD_R]], c["skin"], c["skin_d"], sil, use_sil)
	# hair
	var hair_pts := [
		Vector2(5.9, 1.4), Vector2(4.2, 2.6), Vector2(5.4, 4.9), Vector2(2.8, 4.7), Vector2(2.6, 7.4),
		Vector2(0.0, 5.9), Vector2(-2.6, 7.9), Vector2(-3.6, 5.3), Vector2(-7.0, 6.0), Vector2(-5.9, 3.0),
		Vector2(-8.8, 1.8), Vector2(-6.1, 0.1), Vector2(-7.9, -2.4), Vector2(-5.0, -2.2), Vector2(-5.6, -5.0),
		Vector2(-2.6, -3.0), Vector2(-1.2, -0.6), Vector2(0.8, 2.3), Vector2(3.4, 1.7),
	]
	var poly := PackedVector2Array()
	for hp in hair_pts:
		poly.append(head + fw * hp.x + up * hp.y)
	draw_group(ci, [["poly", poly]], c["hair"], c["hair_d"], sil, use_sil)
	# headband
	draw_group(ci, [["cap", head + fw * 5.3 + up * 2.0, head - fw * 5.2 + up * 2.6, 1.5, 1.5]], c["scarf"], c["scarf_d"], sil, use_sil)
	draw_chain(ci, band, c["scarf"], c["scarf_d"], sil, use_sil)
	if not use_sil:
		var eye := head + fw * 3.2 - up * 0.2
		var ecol: Color = c["eye"]
		if state == S.ATTACK and cur_move.get("kind", "") == "ult":
			ecol = fx_color
		ci.draw_rect(Rect2(eye - Vector2(0.5, 1.0), Vector2(1.2, 2.2)), ecol)
		ci.draw_rect(Rect2(eye + fw * 1.5 + up * 2.0 - Vector2(0.5, 0.5), Vector2(1.6, 0.9)), c["hair_d"])
