extends Node
## Bucles de motor, viento y sirena sintetizados, sin grabaciones externas.

var engine: AudioStreamPlayer
var wind: AudioStreamPlayer
var siren: AudioStreamPlayer
var collision: AudioStreamPlayer
var muted := false
var last_impact := 0.0


func _exit_tree() -> void:
	for player in [engine, wind, siren, collision]:
		if is_instance_valid(player):
			player.stop()
			player.stream = null


func _ready() -> void:
	engine = _loop("engine", 1.0)
	wind = _loop("wind", 2.0)
	siren = _loop("siren", 2.0)
	collision = _loop("collision", 0.22, false)


func _loop(kind: String, duration: float, looping := true) -> AudioStreamPlayer:
	const RATE := 22050
	var samples := int(RATE * duration)
	var data := PackedByteArray()
	data.resize(samples * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 251
	var filtered := 0.0
	for index in samples:
		var time := float(index) / RATE
		var value := 0.0
		match kind:
			"engine":
				value = sin(TAU * 60.0 * time) * 0.4 + sin(TAU * 120.0 * time) * 0.2 + sin(TAU * 180.0 * time) * 0.1
			"wind", "collision":
				filtered = lerpf(filtered, rng.randf_range(-1.0, 1.0), 0.15 if kind == "wind" else 0.7)
				value = filtered * (0.7 if kind == "wind" else pow(1.0 - time / duration, 2.0))
			"siren":
				# Integrar el barrido de frecuencia conserva la fase al repetir el bucle.
				value = sin(TAU * 950.0 * time - 500.0 * cos(PI * time)) * 0.25
		data.encode_s16(index * 2, int(clampf(value, -1.0, 1.0) * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.data = data
	if looping:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_end = samples
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = -80.0
	add_child(player)
	if looping and DisplayServer.get_name() != "headless":
		player.play()
	return player


func update_sound(player: Node3D, nearest_police: float, running: bool) -> void:
	var audible := running and not muted
	var ratio: float = player.speed / 94.0
	# Las caídas breves de tono sugieren cambios de marcha al acelerar.
	var gear := mini(5, int(player.speed / 15.0))
	engine.pitch_scale = 0.7 + (player.speed - gear * 13.0) / 22.0
	engine.volume_db = -15.0 if audible else -80.0
	wind.volume_db = lerpf(-42.0, -9.0, ratio) if audible else -80.0
	siren.volume_db = clampf(-13.0 - nearest_police * 0.13, -65.0, -13.0) if audible else -80.0
	if player.impact > 0.95 and last_impact <= 0.95 and audible:
		collision.volume_db = -7.0
		collision.play()
	if not audible:
		collision.stop()
	last_impact = player.impact
