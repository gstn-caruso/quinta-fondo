extends SceneTree
## Pruebas deterministas de las partidas y del circuito completo.

const Highway = preload("res://scripts/highway.gd")
const Pursuit = preload("res://scripts/pursuit.gd")
var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)


func _advance(game: Node3D, seconds: float, throttle := 1.0, steering := 0.0, brake := false, boost := false) -> void:
	for frame in range(int(seconds * 60.0)):
		game.simulate(1.0 / 60.0, throttle, steering, brake, boost)


func _run() -> void:
	var scene: PackedScene = load("res://scenes/main.tscn")
	var game := scene.instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	await process_frame
	game.start_run()
	var player: Node3D = game.player
	# Verificar el controlador del juego sin interferencia de la IA.
	for frame in range(360):
		player.drive(1.0 / 60.0, 1.0, 0.0, false, false)
	_expect(player.speed > 58.0 and player.speed <= player.MAX_SPEED, "Acceleration must reach highway speeds")
	var before: float = player.offset
	player.drive(0.2, 1.0, -1.0, false, false)
	_expect(player.offset < before, "Steering must change road position")
	player.offset = 0.0
	var nitro_before: float = player.nitro
	for frame in range(120):
		player.drive(1.0 / 60.0, 1.0, 0.0, false, true)
	_expect(player.speed > player.MAX_SPEED and player.nitro < nitro_before - 35, "Nitro must add speed and consume charge")
	var boosted_speed: float = player.speed
	player.drive(1.0 / 60.0, 1.0, 0.0, false, false)
	_expect(player.speed > boosted_speed - 1.0, "Releasing nitro must not instantly clamp speed")
	for frame in range(120):
		player.drive(1.0 / 60.0, 0.0, 0.0, true, false)
	_expect(player.speed < 20.0, "Braking must substantially reduce speed")
	_expect(player.nitro > 60.0, "Nitro must recharge when not in use")
	player.nitro = 0.5
	player.drive(0.1, 1.0, 0.0, false, true)
	for frame in range(120):
		player.drive(1.0 / 60.0, 1.0, 0.0, false, true)
	_expect(not player.boosting and player.nitro > 10.0, "An empty held nitro key must recharge without flickering on/off")
	player.drive(0.5, 1.0, 0.0, false, false)
	player.drive(0.1, 1.0, 0.0, false, true)
	_expect(player.boosting, "Releasing nitro must rearm it after recharging")
	player.speed = 55.0
	player.offset = player.ROAD_LIMIT
	player.drive(0.2, 1.0, 1.0, false, false)
	_expect(player.offset <= player.ROAD_LIMIT and player.health < 100.0, "Barriers must contain and damage the vehicle")
	_expect(Pursuit.swept_contact(Vector2(0, 20), Vector2(0, -20)), "Fast crossing must collide without tunnelling")
	_expect(not Pursuit.swept_contact(Vector2(4, 20), Vector2(4, -20)), "Adjacent lanes must not collide")
	_expect(not Pursuit.swept_contact(Vector2(0, 20), Vector2(0, 10)), "A car ahead must not collide prematurely")
	# Colisión con el tráfico real, incluyendo grandes velocidades relativas.
	game.start_run()
	player.speed = 90.0
	var car: Dictionary = game.pursuit.traffic[0]
	car.distance = 8.0
	car.offset = player.offset
	car.speed = 20.0
	game.simulate(0.2, 1.0, 0.0, false, true)
	_expect(player.health < 100.0 and player.speed < 60.0, "Traffic must damage and slow the actual player")
	# Pasar cerca sin chocar recupera nitro y conserva el estado del auto.
	game.start_run()
	player.speed = 90.0
	player.nitro = 40.0
	car = game.pursuit.traffic[0]
	car.distance = 5.0
	car.offset = player.offset + 2.7
	car.speed = 20.0
	game.simulate(0.1, 1.0, 0.0, false, false)
	_expect(player.health == 100.0 and game.pursuit.near_misses == 1 and player.nitro > 50.0, "Clean close calls must reward nitro")
	# La policía debe alcanzar y detener al jugador inmóvil.
	game.start_run()
	_advance(game, 16.0, 0.0)
	_expect(game.state == "busted", "Pursuers must catch and arrest a stationary player")
	# Una partida completa debe permitir ganar frente a la IA real.
	game.start_run()
	var start_gap: float = game.pursuit.police[0].distance
	_advance(game, 3.0, 1.0, -0.4)
	_expect(game.pursuit.police[0].distance > start_gap, "Police must actively pursue")
	# Ganar una partida predeterminada esquivando el tráfico con controles reales.
	game.start_run()
	var target_lane := 2.5
	for frame in range(7200):
		var best_score := -10000.0
		for lane: float in Highway.LANES:
			var clearance := 250.0
			for actor: Dictionary in game.pursuit.traffic:
				var gap: float = actor.distance - player.distance
				if absf(actor.offset - lane) < 2.2 and gap > -8.0:
					clearance = minf(clearance, gap)
			var score := clearance - absf(lane - player.offset) * 4.0
			if score > best_score:
				best_score = score
				target_lane = lane
		var steering := clampf((target_lane - player.offset) * 0.9 - player.lateral_speed * 0.16, -1.0, 1.0)
		game.simulate(1.0 / 60.0, 1.0, steering, false, player.nitro > 30.0 and best_score > 80.0)
		if game.state != "running":
			break
	_expect(game.state == "escaped", "Steering and nitro must allow a default run to escape the real AI; result: " + game.state)
	# Volver al alcance policial reduce la fuga; moverse reduce el cerco.
	game.start_run()
	game.pursuit.escape_progress = 4.0
	game.pursuit.bust_progress = 2.0
	player.speed = 30.0
	game.pursuit.police[0].distance = player.distance - 10.0
	game.simulate(0.2, 1.0, 0.0, false, false)
	_expect(game.pursuit.escape_progress < 4.0 and game.pursuit.bust_progress < 2.0, "Reacquisition and moving away must update countdowns")
	game.pursuit.elapsed = 80.0
	game.simulate(0.1, 1.0, 0.0, false, false)
	_expect(game.pursuit.heat == 4 and game.pursuit.police.size() == 3, "Heat must escalate and bring bounded reinforcements")
	game.start_run()
	player.health = 0.0
	game.simulate(1.0 / 60.0, 0.0, 0.0, false, false)
	_expect(game.state == "busted", "A destroyed car ends the run")
	game.start_run()
	_expect(player.health == 100.0 and player.nitro == 100.0 and player.distance == 0.0 and game.pursuit.police.size() == 2 and game.pursuit.traffic.size() == Pursuit.TRAFFIC_COUNT, "Retry must reset the complete run")
	# Inspeccionar cada tramo, el cierre, la tangente y la carga acotada entre vueltas.
	_expect(Highway.LENGTH >= 16000, "The circuit must be at least 16 km")
	_expect(Highway.point(Highway.LENGTH).length() < 0.01, "Road position must close exactly at a full lap")
	var seam_before := (Highway.point(Highway.LENGTH) - Highway.point(Highway.LENGTH - 0.1)).normalized()
	var seam_after := (Highway.point(0.1) - Highway.point(0.0)).normalized()
	_expect(seam_before.dot(seam_after) > 0.999, "The loop seam must have a continuous driving direction")
	for index in range(Highway.SEGMENT_COUNT + 34):
		game.highway.update_road(index * Highway.SEGMENT_LENGTH)
		_expect(game.highway.chunks.size() == Highway.AHEAD + Highway.BEHIND + 1, "Visible road must remain bounded across a complete lap")
		await process_frame
	_expect(game.highway.mesh_cache.size() == Highway.SEGMENT_COUNT, "Road cache must stop growing after one full lap")
	game.queue_free()
	await process_frame
	if failures.is_empty():
		print("PASS: arcade driving, nitro, swept collisions, traffic, pursuit, escape/arrest, retry and 16 km loop")
	quit(0 if failures.is_empty() else 1)
