extends SceneTree
## Verifica la escena real, los controles y los catálogos nativos de traducción.

var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)


func _run() -> void:
	var localization := root.get_node("Localization")
	_expect(localization.resolve_locale("es_AR") == "es", "Regional Spanish must resolve to es")
	_expect(localization.resolve_locale("en-US") == "en", "Regional English must resolve to en")
	_expect(localization.resolve_locale("pt_BR") == "es", "Unsupported languages must fall back to Spanish")
	_expect(TranslationServer.get_locale() == localization.resolve_locale(OS.get_locale()), "Startup language must follow the operating system")
	var scene: PackedScene = load("res://scenes/main.tscn")
	var main := scene.instantiate()
	root.add_child(main)
	await process_frame
	_expect(main is Node3D, "The entry scene must be 3D")
	_expect(main.get_node("Camera").current, "The entry scene needs an active camera")
	_expect(main.state == "ready", "Startup must explain controls before the pursuit")
	for locale: String in ["es", "en"]:
		TranslationServer.set_locale(locale)
		await process_frame
		var expected := "ENTER  /  INICIAR PERSECUCIÓN" if locale == "es" else "ENTER  /  START PURSUIT"
		_expect(main.hud.primary.text == expected, "The actual start button must translate into " + locale)
		var csv := FileAccess.open("res://assets/i18n/messages.csv", FileAccess.READ)
		csv.get_csv_line()
		while not csv.eof_reached():
			var row := csv.get_csv_line()
			if row.size() == 3:
				_expect(TranslationServer.translate(row[0]) == row[1 if locale == "en" else 2], "Catalog must translate " + row[0])
	main.set_physics_process(false)
	main.hud.primary.pressed.emit()
	_expect(main.state == "running", "The menu must start a playable run")
	Input.action_press("accelerate")
	for frame in range(120):
		main._physics_process(1.0 / 60.0)
	Input.action_release("accelerate")
	_expect(main.player.speed > 15.0 and main.player.distance > 10.0, "Mapped acceleration must move the actual player")
	var pause_event := InputEventAction.new()
	pause_event.action = "pause_run"
	pause_event.pressed = true
	main._unhandled_input(pause_event)
	var before: float = main.player.distance
	main._physics_process(1.0)
	_expect(main.state == "paused" and main.player.distance == before, "Pause must freeze the pursuit")
	main.hud.primary.pressed.emit()
	_expect(main.state == "running", "The menu must resume a paused run")
	var camera_event := InputEventAction.new()
	camera_event.action = "camera_view"
	camera_event.pressed = true
	main._unhandled_input(camera_event)
	_expect(main.close_camera, "Camera input must switch the chase camera")
	main.player.speed = 90.0
	main.player.boosting = true
	for frame in range(60):
		main._update_camera(1.0 / 60.0)
	_expect(main.camera.fov > 88.0, "Speed and nitro must widen the actual camera FOV")
	main.queue_free()
	await process_frame
	if failures.is_empty():
		print("PASS: entry scene, menu, actual input, camera, pause and complete EN/ES catalogs")
	quit(0 if failures.is_empty() else 1)
