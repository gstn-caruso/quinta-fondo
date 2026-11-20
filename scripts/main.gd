extends Node3D
## Entrada de la persecución. El juego y las pruebas comparten la misma simulación.

const Highway = preload("res://scripts/highway.gd")
const PlayerCar = preload("res://scripts/player_car.gd")
const CarVisual = preload("res://scripts/car_visual.gd")
const Pursuit = preload("res://scripts/pursuit.gd")
const DriveHUD = preload("res://scripts/drive_hud.gd")
const DriveAudio = preload("res://scripts/drive_audio.gd")

var highway: Node3D
var player: Node3D
var pursuit: Node3D
var camera: Camera3D
var hud: Control
var audio: Node
var state := "ready"
var clock := 0.0
var close_camera := false


func _ready() -> void:
	_configure_input()
	_build_environment()
	highway = Highway.new()
	highway.name = "Highway"
	add_child(highway)
	player = PlayerCar.new()
	player.name = "Player"
	add_child(player)
	player.visual = CarVisual.new()
	player.add_child(player.visual)
	player.visual.build(Color("eb9f42"), false, true)
	player.reset()
	pursuit = Pursuit.new()
	pursuit.name = "Pursuit"
	add_child(pursuit)
	pursuit.reset()
	camera = Camera3D.new()
	camera.name = "Camera"
	camera.current = true
	camera.far = 1550.0
	camera.near = 0.15
	add_child(camera)
	camera.position = Vector3(player.offset, 3.8, 8.5)
	camera.look_at(Vector3(player.offset, 1.0, -15.0))
	var layer := CanvasLayer.new()
	layer.name = "HUD"
	add_child(layer)
	hud = DriveHUD.new()
	hud.game = self
	layer.add_child(hud)
	audio = DriveAudio.new()
	add_child(audio)


func _configure_input() -> void:
	var bindings := {
		"accelerate": [KEY_W, KEY_UP], "brake": [KEY_S, KEY_DOWN, KEY_SPACE],
		"steer_left": [KEY_A, KEY_LEFT], "steer_right": [KEY_D, KEY_RIGHT],
		"nitro": [KEY_SHIFT], "pause_run": [KEY_ESCAPE], "start_run": [KEY_ENTER],
		"restart_run": [KEY_R], "camera_view": [KEY_C], "mute_audio": [KEY_M]
	}
	for action: String in bindings:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for key: int in bindings[action]:
			var event := InputEventKey.new()
			event.physical_keycode = key
			if not InputMap.action_has_event(action, event):
				InputMap.action_add_event(action, event)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("mute_audio"):
		audio.muted = not audio.muted
	elif event.is_action_pressed("camera_view"):
		close_camera = not close_camera
	elif event.is_action_pressed("restart_run"):
		start_run()
	elif event.is_action_pressed("start_run"):
		if state == "paused":
			state = "running"
		elif state != "running":
			start_run()
	elif event.is_action_pressed("pause_run"):
		toggle_pause()


func toggle_pause() -> void:
	if state == "running":
		state = "paused"
	elif state == "paused":
		state = "running"


func start_run() -> void:
	player.reset()
	pursuit.reset()
	highway.update_road(0.0)
	state = "running"


func _physics_process(delta: float) -> void:
	if state == "running":
		simulate(delta, Input.get_action_strength("accelerate"), Input.get_axis("steer_left", "steer_right"), Input.is_action_pressed("brake"), Input.is_action_pressed("nitro"))


func simulate(delta: float, throttle: float, steering: float, brake: bool, boost: bool) -> void:
	if state != "running":
		return
	var previous_distance: float = player.distance
	var previous_offset: float = player.offset
	player.drive(delta, throttle, steering, brake, boost)
	pursuit.step(delta, player, previous_distance, previous_offset)
	highway.update_road(player.distance)
	if not pursuit.result.is_empty():
		state = pursuit.result


func _process(delta: float) -> void:
	clock += delta
	_update_camera(delta)
	audio.update_sound(player, pursuit.nearest_police, state == "running")
	hud.queue_redraw()


func _update_camera(delta: float) -> void:
	var ratio: float = player.speed / PlayerCar.BOOST_SPEED
	var follow := 1.0 - exp(-delta * 7.0)
	var target := Vector3(player.offset - player.lateral_speed * 0.12, 3.5, 8.0 + ratio * 1.9)
	if close_camera:
		target = Vector3(player.offset, 2.2, 5.5 + ratio * 0.8)
	if state == "ready":
		target = Vector3(player.offset + 4.5, 2.8, 7.0)
	camera.position = camera.position.lerp(target, follow)
	var shake: float = ratio * ratio * 0.026 + player.impact * 0.13
	if state == "running":
		camera.position += Vector3(sin(clock * 73.0), cos(clock * 81.0), 0) * shake
	camera.look_at(Vector3(player.offset + player.lateral_speed * 0.16, 1.1, -18.0 - ratio * 10.0))
	camera.rotation.z = lerp_angle(camera.rotation.z, -player.lateral_speed * 0.003, follow)
	var target_fov: float = 68.0 + ratio * 17.0 + (8.0 if player.boosting else 0.0)
	camera.fov = lerpf(camera.fov, target_fov, 1.0 - exp(-delta * 3.5))


func _build_environment() -> void:
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("172f53")
	sky_material.sky_horizon_color = Color("e6b59d")
	sky_material.ground_bottom_color = Color("333a45")
	sky_material.ground_horizon_color = Color("bfa38c")
	sky_material.sky_curve = 0.22
	sky_material.sun_angle_max = 5.0
	sky.sky_material = sky_material
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("b5c5db")
	environment.ambient_light_energy = 0.52
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.fog_enabled = true
	environment.fog_light_color = Color("b5a6a0")
	environment.fog_density = 0.0012
	environment.fog_sky_affect = 0.25
	world.environment = environment
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-17.0, -32.0, 0.0)
	sun.light_color = Color("ffd7aa")
	sun.light_energy = 1.1
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 160.0
	add_child(sun)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(5000, 5000)
	ground.mesh = plane
	ground.position.y = -0.5
	var ground_material := StandardMaterial3D.new()
	ground_material.albedo_color = Color("525749")
	ground.material_override = ground_material
	add_child(ground)
