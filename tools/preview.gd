extends SceneTree
## Captura del juego: godot --path . --script res://tools/preview.gd -- boost


func _initialize() -> void:
	_capture.call_deferred()


func _capture() -> void:
	var scene: PackedScene = load("res://scenes/main.tscn")
	var game := scene.instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	var args := OS.get_cmdline_user_args()
	var scenario := args[0] if not args.is_empty() else "ready"
	TranslationServer.set_locale("es")
	if scenario != "ready":
		game.start_run()
		game.player.distance = 1400.0
		game.player.speed = 83.0 if scenario == "boost" else 62.0
		game.player.boosting = scenario == "boost"
		game.player.nitro = 65.0
		game.pursuit.elapsed = 42.0
		game.pursuit.heat = 2
		for index in game.pursuit.traffic.size():
			var car: Dictionary = game.pursuit.traffic[index]
			car.distance = 1440.0 + index * 43.0
		game.pursuit.police[0].distance = 1407.0
		game.pursuit.police[0].offset = -2.0
		game.pursuit.police[1].distance = 1389.0
		game.pursuit.police[1].offset = 7.5
		game.pursuit.nearest_police = 12.0
		game.pursuit.update_visuals(game.player.distance, 0.05)
		game.highway.update_road(game.player.distance)
		game.player.visual.animate(0.1, game.player.speed, game.player.boosting)
	for frame in range(30):
		await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://build/previews")
	root.get_texture().get_image().save_png("res://build/previews/" + scenario + ".png")
	print("Preview: build/previews/" + scenario + ".png; draw calls: ", Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	game.queue_free()
	await process_frame
	quit()
