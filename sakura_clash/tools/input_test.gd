extends Node
## Scripted human-input test. Injects actions into P1 and logs fighter state.
## Run: godot --headless --path . -- --scene=inputtest --p1=ronin

var arena: Arena
var t := 0.0
var steps: Array = []
var idx := 0
var f: Fighter


func _ready() -> void:
	Game.mode = Game.Mode.TRAINING
	arena = Arena.new()
	add_child(arena)
	f = arena.fighters[0]
	var ronin := [
		[2.0, "press", "p1_right"], [2.05, "release", "p1_right"], [2.12, "press", "p1_right"],
		[2.45, "log", "double tap -> expect RUN"],
		[2.5, "release", "p1_right"], [2.5, "press", "p1_left"],
		[2.75, "log", "switch dir -> expect RUN facing -1"],
		[2.8, "release", "p1_left"], [3.1, "log", "released -> expect IDLE"],
		[3.2, "press", "p1_right"], [3.22, "press", "p1_dash"], [3.26, "log", "shift+D -> expect DASH"],
		[3.3, "release", "p1_dash"], [3.6, "log", "holding D after dash -> RUN"], [3.65, "release", "p1_right"],
		[4.0, "press", "p1_jump"], [4.1, "log", "jump -> AIR"], [4.12, "release", "p1_jump"],
		[4.4, "press", "p1_jump"], [4.45, "log", "double jump -> jumps_left 0"], [4.5, "release", "p1_jump"],
		[5.6, "log", "landed"],
		[5.7, "press", "p1_light"], [5.72, "release", "p1_light"], [5.9, "press", "p1_light"], [5.92, "release", "p1_light"],
		[6.1, "press", "p1_light"], [6.12, "release", "p1_light"], [6.35, "press", "p1_light"], [6.37, "release", "p1_light"],
		[5.8, "log", "L1"], [6.0, "log", "L2"], [6.25, "log", "L3"], [6.5, "log", "L4"],
		[7.4, "press", "p1_q"], [7.42, "release", "p1_q"], [7.5, "log", "Q flash step"],
		[8.4, "press", "p1_e"], [8.42, "release", "p1_e"], [8.5, "log", "E crescent"],
		[9.4, "press", "p1_r"], [9.42, "release", "p1_r"], [9.5, "log", "R counter"],
		[10.8, "press", "p1_f"], [10.82, "release", "p1_f"], [11.0, "log", "F ult (freeze)"], [12.2, "log", "ult later"],
		[14.5, "press", "p1_guard"], [14.55, "log", "parry window"], [14.8, "log", "guard hold"], [14.9, "release", "p1_guard"],
		[15.2, "press", "p1_dash"], [15.25, "log", "shift alone -> DODGE"], [15.3, "release", "p1_dash"],
		[15.8, "press", "p1_up"], [15.8, "press", "p1_dash"], [15.8, "log", "t0"], [15.817, "log", "t1"], [15.834, "log", "t2"], [15.85, "log", "shift+W -> super jump"], [15.9, "release", "p1_up"], [15.9, "release", "p1_dash"],
		[17.0, "press", "p1_heavy"], [17.6, "log", "charging heavy"], [17.7, "release", "p1_heavy"], [17.8, "log", "heavy released"],
		[19.0, "press", "p1_light"], [19.02, "press", "p1_heavy"], [19.05, "release", "p1_light"], [19.06, "release", "p1_heavy"], [19.1, "log", "throw attempt"],
		[20.0, "quit", ""],
	]
	var tengu := [
		[2.0, "press", "p1_up"], [2.2, "log", "W on ground -> FLY"], [2.5, "release", "p1_up"],
		[2.6, "press", "p1_right"], [2.65, "press", "p1_dash"], [2.7, "log", "air dash right"], [2.72, "release", "p1_dash"],
		[3.0, "log", "hold -> boosting"], [3.1, "release", "p1_right"], [3.1, "press", "p1_left"], [3.3, "log", "switch -> still boosting"],
		[3.4, "release", "p1_left"], [3.8, "log", "released -> FLY not boosting"],
		[4.0, "press", "p1_up"], [4.05, "release", "p1_up"], [4.1, "press", "p1_up"], [4.15, "log", "double tap up -> DASH up"], [4.3, "release", "p1_up"],
		[4.6, "press", "p1_down"], [4.62, "release", "p1_down"], [4.68, "press", "p1_down"], [4.72, "log", "double tap down -> DASH down"], [4.9, "release", "p1_down"],
		[5.5, "press", "p1_light"], [5.52, "release", "p1_light"], [5.6, "log", "air L1"],
		[6.5, "press", "p1_q"], [6.52, "release", "p1_q"], [6.7, "log", "Q feathers"],
		[7.5, "press", "p1_e"], [7.52, "release", "p1_e"], [7.8, "log", "E tornado"],
		[9.0, "press", "p1_r"], [9.02, "release", "p1_r"], [9.2, "log", "R dive"],
		[12.2, "press", "p1_f"], [12.22, "release", "p1_f"], [12.4, "log", "F storm"], [14.0, "log", "storm later"],
		[17.0, "press", "p1_down"], [18.5, "log", "hold S -> landed"], [18.6, "release", "p1_down"],
		[19.0, "quit", ""],
	]
	steps = tengu if Game.p1_char == "tengu" else ronin
	steps.sort_custom(func(a, b): return a[0] < b[0])


func _physics_process(delta: float) -> void:
	t += delta
	while idx < steps.size() and steps[idx][0] <= t:
		var s: Array = steps[idx]
		idx += 1
		match s[1]:
			"press":
				Input.action_press(s[2])
			"release":
				Input.action_release(s[2])
			"log":
				print("[%.2f] %-40s state=%s move=%s facing=%d vel=(%d,%d) pos=(%d,%d) ground=%s jumps=%d boost=%s stam=%d ki=%d proj=%d" % [t, s[2], Fighter.S.keys()[f.state], f.move_name, f.facing, f.vel.x, f.vel.y, f.position.x, f.position.y, f.on_ground, f.jumps_left, f.boosting, f.stamina, f.ki, arena.projectiles.size()])
			"quit":
				get_tree().quit()
