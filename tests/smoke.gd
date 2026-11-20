extends SceneTree
## Exercise the actual entry scene and the native translation catalogs.

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
	_expect(
		TranslationServer.get_locale() == localization.resolve_locale(OS.get_locale()),
		"Startup language must follow the operating system"
	)
	var scene: PackedScene = load("res://scenes/main.tscn")
	var main := scene.instantiate()
	root.add_child(main)
	await process_frame
	_expect(main is Node3D, "The entry scene must be 3D")
	_expect(main.get_node("Camera").current, "The entry scene needs an active camera")
	for locale: String in ["es", "en"]:
		TranslationServer.set_locale(locale)
		await process_frame
		var expected := "Un juego de carreras 3D hecho en Godot." if locale == "es" else "A 3D racing game made with Godot."
		_expect(main.get_node("HUD/Content/Description").text == expected, "The entry scene must translate into " + locale)
	main.queue_free()
	await process_frame
	if failures.is_empty():
		print("PASS: 3D entry scene, system locale and English/Spanish translations")
	quit(0 if failures.is_empty() else 1)
