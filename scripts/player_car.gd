extends Node3D
## Conducción arcade en coordenadas de la ruta; metros, segundos y metros por segundo.

const MAX_SPEED := 76.0
const BOOST_SPEED := 94.0
const ROAD_LIMIT := 12.25

var distance := 0.0
var offset := 2.5
var speed := 0.0
var lateral_speed := 0.0
var health := 100.0
var nitro := 100.0
var boosting := false
var nitro_locked := false
var drifting := false
var impact := 0.0
var impact_cooldown := 0.0
var yaw := 0.0
var visual: Node3D


func reset() -> void:
	distance = 0.0
	offset = 2.5
	speed = 0.0
	lateral_speed = 0.0
	health = 100.0
	nitro = 100.0
	boosting = false
	nitro_locked = false
	drifting = false
	impact = 0.0
	impact_cooldown = 0.0
	yaw = 0.0
	position = Vector3(offset, 0.0, 0.0)


func drive(delta: float, throttle: float, steering: float, brake: bool, boost: bool) -> void:
	impact = move_toward(impact, 0.0, delta * 2.8)
	impact_cooldown = maxf(0.0, impact_cooldown - delta)
	if nitro <= 1.0:
		nitro_locked = true
	elif not boost and nitro >= 15.0:
		nitro_locked = false
	boosting = boost and not nitro_locked and throttle > 0.0 and nitro > 1.0 and speed > 8.0 and not brake
	drifting = brake and absf(steering) > 0.2 and speed > 18.0
	if boosting:
		nitro = maxf(0.0, nitro - delta * 23.0)
	else:
		nitro = minf(100.0, nitro + delta * 6.5)
		if not boost and nitro >= 15.0:
			nitro_locked = false
	var limit := BOOST_SPEED if boosting else MAX_SPEED
	var acceleration := 15.0 * throttle + (23.0 if boosting else 0.0)
	acceleration -= 2.0 + speed * speed * 0.00125
	if brake:
		acceleration -= 36.0 if not drifting else 13.0
	if absf(offset) > 10.5:
		acceleration -= 8.0
	if speed > limit:
		acceleration = minf(acceleration, -5.0)
	speed = clampf(speed + acceleration * delta, 0.0, BOOST_SPEED)
	var steering_power := lerpf(3.0, 13.0, minf(speed / 35.0, 1.0))
	var target := steering * steering_power * (1.25 if drifting else 1.0)
	lateral_speed = move_toward(lateral_speed, target, delta * (9.0 if drifting else 32.0))
	if speed < 0.5:
		lateral_speed = 0.0
	offset += lateral_speed * delta
	if absf(offset) > ROAD_LIMIT:
		offset = clampf(offset, -ROAD_LIMIT, ROAD_LIMIT)
		if impact_cooldown <= 0.0 and speed > 6.0:
			hit(5.0 + speed * 0.06, 0.84)
		lateral_speed *= -0.45
	distance += speed * delta
	yaw = lerpf(yaw, -atan2(lateral_speed, maxf(speed, 12.0)) * (1.8 if drifting else 1.0), 1.0 - exp(-delta * 7.0))
	position = Vector3(offset, 0.0, 0.0)
	rotation.y = yaw
	if visual:
		visual.rotation.z = -lateral_speed * 0.009
		visual.rotation.x = acceleration * 0.0015
		visual.animate(delta, speed, boosting, brake)


func hit(damage: float, speed_factor: float) -> void:
	if impact_cooldown > 0.0:
		return
	health = maxf(0.0, health - damage)
	speed *= speed_factor
	impact = 1.0
	impact_cooldown = 0.75
