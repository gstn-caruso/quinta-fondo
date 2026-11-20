extends Node3D
## Tráfico, patrulleros y colisiones continuas en las coordenadas de la ruta.

const Highway = preload("res://scripts/highway.gd")
const CarVisual = preload("res://scripts/car_visual.gd")
const TRAFFIC_COUNT := 18
const ESCAPE_DISTANCE := 170.0
const ESCAPE_TIME := 8.0
const BUST_TIME := 5.0

var traffic: Array[Dictionary] = []
var police: Array[Dictionary] = []
var elapsed := 0.0
var heat := 1
var escape_progress := 0.0
var bust_progress := 0.0
var nearest_police := 0.0
var near_misses := 0
var result := ""
var rng := RandomNumberGenerator.new()


func reset() -> void:
	for actor in traffic + police:
		actor.visual.queue_free()
	traffic.clear()
	police.clear()
	rng.seed = 2026
	elapsed = 0.0
	heat = 1
	escape_progress = 0.0
	bust_progress = 0.0
	nearest_police = 45.0
	near_misses = 0
	result = ""
	var colors := [Color("a95747"), Color("909da4"), Color("d5c498"), Color("507b81"), Color("d2d7d4"), Color("555375")]
	for index in TRAFFIC_COUNT:
		var actor := _actor(colors[index % colors.size()], false)
		actor.distance = 105.0 + index * 49.0
		actor.offset = Highway.LANES[(index * 3 + 1) % 4]
		actor.speed = rng.randf_range(27.0, 43.0)
		actor.cruise = actor.speed
		traffic.append(actor)
	_spawn_unit(-45.0, -2.5)
	_spawn_unit(-78.0, 7.5)
	update_visuals(0.0, 0.0)


func _actor(color: Color, is_police: bool) -> Dictionary:
	var visual := CarVisual.new()
	visual.build(color, is_police)
	add_child(visual)
	return {"visual": visual, "distance": 0.0, "offset": 0.0, "speed": 0.0, "cruise": 0.0, "cooldown": 0.0, "passed": false}


func _spawn_unit(distance: float, offset: float) -> void:
	var unit := _actor(Color("172738"), true)
	unit.distance = distance
	unit.offset = offset
	unit.speed = 42.0
	police.append(unit)


func step(delta: float, player: Node3D, previous_distance: float, previous_offset: float) -> void:
	elapsed += delta
	heat = mini(5, 1 + int(elapsed / 25.0))
	# Los refuerzos llegan por detrás como unidades nuevas.
	if police.size() < mini(4, heat + 1) and nearest_police < ESCAPE_DISTANCE:
		_spawn_unit(player.distance - 105.0, Highway.LANES[police.size() % 4])
	for actor in traffic:
		var old := Vector2(actor.offset - previous_offset, actor.distance - previous_distance)
		var cruise: float = actor.cruise
		for other in traffic:
			var ahead: float = other.distance - actor.distance
			if other != actor and ahead > 0.0 and ahead < 30.0 and absf(other.offset - actor.offset) < 2.0:
				cruise = minf(cruise, maxf(0.0, other.speed + (ahead - 10.0) * 0.7))
		actor.speed = move_toward(actor.speed, cruise, delta * 8.0)
		actor.distance += actor.speed * delta
		actor.cooldown = maxf(0.0, actor.cooldown - delta)
		var relative: float = actor.distance - player.distance
		if relative < -130.0 or relative > 1150.0:
			_recycle_traffic(actor, player.distance)
			continue
		var current := Vector2(actor.offset - player.offset, relative)
		if swept_contact(old, current) and actor.cooldown <= 0.0:
			player.hit(12.0 + absf(player.speed - actor.speed) * 0.18, 0.52)
			actor.speed = maxf(17.0, actor.speed - 5.0)
			actor.offset = clampf(actor.offset + signf(actor.offset - player.offset) * 0.7, -9.0, 9.0)
			actor.cooldown = 1.0
		elif old.y > 0.0 and current.y <= 0.0 and absf(current.x) < 3.3 and absf(current.x) > 1.9 and not actor.passed:
			near_misses += 1
			actor.passed = true
			player.nitro = minf(100.0, player.nitro + 12.0)
	nearest_police = 10000.0
	for index in police.size():
		var unit: Dictionary = police[index]
		var old := Vector2(unit.offset - previous_offset, unit.distance - previous_distance)
		var gap: float = player.distance - unit.distance
		var target_speed := clampf(player.speed + gap * 0.36 + 2.0, 0.0, 68.0 + heat * 1.6)
		unit.speed = move_toward(unit.speed, target_speed, delta * 10.0)
		var target_offset: float = player.offset
		if absf(gap) < 20.0:
			target_offset += -1.65 if index % 2 == 0 else 1.65
		# Frenar y esquivar el tráfico lento; la congestión puede facilitar la fuga.
		for car in traffic:
			var ahead: float = car.distance - unit.distance
			if ahead > 0.0 and ahead < 18.0 and absf(car.offset - unit.offset) < 2.0:
				unit.speed = move_toward(unit.speed, car.speed, delta * 25.0)
				target_offset = clampf(car.offset + (5.0 if car.offset < 0.0 else -5.0), -9.5, 9.5)
		unit.offset = move_toward(unit.offset, clampf(target_offset, -10.5, 10.5), delta * 3.5)
		unit.distance += unit.speed * delta
		unit.cooldown = maxf(0.0, unit.cooldown - delta)
		var current := Vector2(unit.offset - player.offset, unit.distance - player.distance)
		if swept_contact(old, current) and unit.cooldown <= 0.0:
			player.hit(7.0, 0.77)
			unit.speed *= 0.7
			unit.cooldown = 1.2
		nearest_police = minf(nearest_police, current.length())
	if nearest_police > ESCAPE_DISTANCE:
		escape_progress += delta
	else:
		escape_progress = maxf(0.0, escape_progress - delta * 2.0)
	if nearest_police < 15.0 and player.speed < 9.0:
		bust_progress += delta
	else:
		bust_progress = maxf(0.0, bust_progress - delta * 1.4)
	if player.health <= 0.0 or bust_progress >= BUST_TIME:
		result = "busted"
	elif escape_progress >= ESCAPE_TIME:
		result = "escaped"
	update_visuals(player.distance, delta)


func _recycle_traffic(actor: Dictionary, player_distance: float) -> void:
	actor.distance = player_distance + rng.randf_range(780.0, 1080.0)
	actor.offset = Highway.LANES[rng.randi_range(0, 3)]
	for other in traffic:
		if other != actor and absf(other.offset - actor.offset) < 2.0 and absf(other.distance - actor.distance) < 28.0:
			actor.distance = other.distance + 32.0
	actor.speed = rng.randf_range(27.0, 43.0)
	actor.cruise = actor.speed
	actor.passed = false
	actor.cooldown = 0.0


func update_visuals(player_distance: float, delta: float) -> void:
	for actor in traffic + police:
		var relative: float = actor.distance - player_distance
		actor.visual.visible = relative > -150.0 and relative < 1200.0
		if actor.visual.visible:
			actor.visual.position = Highway.point(relative, actor.offset)
			actor.visual.rotation.y = -relative / Highway.RADIUS
			actor.visual.animate(delta, actor.speed)


static func swept_contact(previous: Vector2, current: Vector2) -> bool:
	# La intersección barrida evita atravesar otros autos a gran velocidad.
	var travel := current - previous
	var enter := 0.0
	var leave := 1.0
	for axis in range(2):
		var extent := 1.85 if axis == 0 else 4.25
		if absf(travel[axis]) < 0.00001:
			if absf(previous[axis]) > extent:
				return false
		else:
			var a := (-extent - previous[axis]) / travel[axis]
			var b := (extent - previous[axis]) / travel[axis]
			enter = maxf(enter, minf(a, b))
			leave = minf(leave, maxf(a, b))
			if enter > leave:
				return false
	return true
