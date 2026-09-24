extends Node
## Autoload "Sfx": pooled sound effects + looping music with a menu low-pass.

const NAMES := [
	"block", "charge", "counter", "crescent", "dash", "double_jump", "feather", "fight", "flap",
	"flash_step", "guard_break", "gust", "hit_h", "hit_l", "hit_m", "hit_slash", "jump", "ko",
	"land", "parry", "perfect", "round", "slash_h", "slash_l", "step", "swing_h", "swing_l",
	"swing_m", "throw", "thunder", "tornado", "ui_back", "ui_move", "ui_ok", "ult_hit",
	"ult_start", "wall", "zap",
]
const POOL := 20

var streams := {}
var players: Array[AudioStreamPlayer] = []
var music: AudioStreamPlayer
var _next := 0
var _last_play := {}
var _sfx_bus := 0
var _music_bus := 0
## Attract mode behind menus plays everything quieter.
var quiet := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_buses()
	for n in NAMES:
		var s = load("res://assets/sfx/%s.wav" % n)
		if s != null:
			streams[n] = s
	for i in POOL:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		players.append(p)
	music = AudioStreamPlayer.new()
	music.bus = "Music"
	music.stream = load("res://assets/music/battle_theme.wav")
	music.finished.connect(func(): music.play())
	add_child(music)
	apply_volumes()


func _setup_buses() -> void:
	_sfx_bus = AudioServer.get_bus_index("SFX")
	if _sfx_bus < 0:
		AudioServer.add_bus()
		_sfx_bus = AudioServer.bus_count - 1
		AudioServer.set_bus_name(_sfx_bus, "SFX")
		AudioServer.set_bus_send(_sfx_bus, "Master")
	_music_bus = AudioServer.get_bus_index("Music")
	if _music_bus < 0:
		AudioServer.add_bus()
		_music_bus = AudioServer.bus_count - 1
		AudioServer.set_bus_name(_music_bus, "Music")
		AudioServer.set_bus_send(_music_bus, "Master")
		var lp := AudioEffectLowPassFilter.new()
		lp.cutoff_hz = 900.0
		AudioServer.add_bus_effect(_music_bus, lp)
		AudioServer.set_bus_effect_enabled(_music_bus, 0, false)


func apply_volumes() -> void:
	AudioServer.set_bus_volume_db(_sfx_bus, linear_to_db(maxf(Game.sfx_volume, 0.001)))
	AudioServer.set_bus_volume_db(_music_bus, linear_to_db(maxf(Game.music_volume * 0.55, 0.001)))


func play(sound: String, volume_db := 0.0, pitch := 1.0, variance := 0.06) -> void:
	if not streams.has(sound):
		return
	# Avoid machine-gun stacking of the exact same sound in one frame.
	var now := Time.get_ticks_msec()
	if _last_play.get(sound, -1000) > now - 25:
		return
	_last_play[sound] = now
	var p := players[_next]
	_next = (_next + 1) % POOL
	p.stream = streams[sound]
	p.volume_db = volume_db - (13.0 if quiet else 0.0)
	p.pitch_scale = maxf(0.05, pitch * (1.0 + randf_range(-variance, variance)))
	p.play()


func play_music() -> void:
	if music.stream != null and not music.playing:
		music.play()


func set_muffled(on: bool) -> void:
	AudioServer.set_bus_effect_enabled(_music_bus, 0, on)
