extends Control
## Instrumentos adaptables, radar, estelas de velocidad y botones de menú.

const Highway = preload("res://scripts/highway.gd")
const Pursuit = preload("res://scripts/pursuit.gd")
const INK := Color("0c1421")
const PAPER := Color("e9e7df")
const MUTED := Color("abb8c5")
const AMBER := Color("ffb957")
const CYAN := Color("6be0ec")
const RED := Color("fc6269")

var game: Node3D
var font: Font
var primary: Button
var quit_button: Button
var previous_state := ""
var time := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	font = ThemeDB.fallback_font
	primary = Button.new()
	primary.name = "PrimaryAction"
	primary.add_theme_font_size_override("font_size", 21)
	primary.add_theme_color_override("font_color", INK)
	primary.add_theme_color_override("font_focus_color", INK)
	primary.add_theme_color_override("font_hover_color", INK)
	primary.add_theme_color_override("font_pressed_color", INK)
	var style := StyleBoxFlat.new()
	style.bg_color = AMBER
	style.corner_radius_top_left = 3
	style.corner_radius_bottom_right = 3
	primary.add_theme_stylebox_override("normal", style)
	var hover := style.duplicate()
	hover.bg_color = Color("ffcf87")
	primary.add_theme_stylebox_override("hover", hover)
	primary.pressed.connect(_primary_action)
	add_child(primary)
	quit_button = Button.new()
	quit_button.name = "QuitAction"
	quit_button.flat = true
	quit_button.add_theme_color_override("font_color", MUTED)
	quit_button.pressed.connect(func(): get_tree().quit())
	add_child(quit_button)


func _primary_action() -> void:
	if game.state == "paused":
		game.toggle_pause()
	else:
		game.start_run()


func _process(delta: float) -> void:
	time += delta
	var scale_factor := minf(get_viewport_rect().size.x / 1280.0, get_viewport_rect().size.y / 720.0)
	var origin := (get_viewport_rect().size - Vector2(1280, 720) * scale_factor) * 0.5
	primary.position = origin + Vector2(440, 530) * scale_factor
	primary.size = Vector2(400, 50) * scale_factor
	quit_button.position = origin + Vector2(540, 590) * scale_factor
	quit_button.size = Vector2(200, 34) * scale_factor
	primary.visible = game.state != "running"
	quit_button.visible = primary.visible
	primary.text = tr("RESUME") if game.state == "paused" else tr("START") if game.state == "ready" else tr("RETRY")
	quit_button.text = tr("QUIT")
	if game.state != previous_state:
		if primary.visible:
			primary.grab_focus()
		previous_state = game.state


func _draw() -> void:
	if not game or not font:
		return
	var scale_factor := minf(get_viewport_rect().size.x / 1280.0, get_viewport_rect().size.y / 720.0)
	draw_set_transform((get_viewport_rect().size - Vector2(1280, 720) * scale_factor) * 0.5, 0, Vector2.ONE * scale_factor)
	var player: Node3D = game.player
	if game.state == "running":
		_speed_effects(player)
	# Identidad e instrumentos de persecución en la franja superior.
	_panel(Rect2(30, 26, 235, 78))
	draw_rect(Rect2(30, 26, 4, 78), AMBER)
	_text(Vector2(48, 58), "QUINTA FONDO", 25, PAPER)
	_text(Vector2(49, 83), tr("ROUTE_LABEL"), 12, AMBER)
	_panel(Rect2(1000, 26, 250, 78))
	_text(Vector2(1018, 51), tr("HEAT"), 12, MUTED)
	for index in range(5):
		draw_rect(Rect2(1019 + index * 27, 66, 19, 5), AMBER if index < game.pursuit.heat else Color("3d4653"))
	_text(Vector2(1174, 77), "%02d" % game.pursuit.police.size(), 27, PAPER)
	_text(Vector2(1214, 76), tr("UNITS"), 10, MUTED)
	if game.state == "running":
		var escaping: bool = game.pursuit.nearest_police > Pursuit.ESCAPE_DISTANCE
		var danger: bool = game.pursuit.bust_progress > 0.1
		var accent := CYAN if escaping else RED if danger else AMBER
		_panel(Rect2(405, 26, 470, 64))
		_text(Vector2(640, 51), tr("EVADING") if escaping else tr("BUSTING") if danger else tr("PURSUIT_ACTIVE"), 17, accent, true)
		var progress: float = game.pursuit.escape_progress / Pursuit.ESCAPE_TIME if escaping else game.pursuit.bust_progress / Pursuit.BUST_TIME if danger else 0.0
		_bar(Rect2(431, 65, 418, 4), progress, accent)
		_text(Vector2(640, 112), tr("ESCAPE_HINT") if escaping else tr("CHASE_HINT"), 13, PAPER, true)
	_draw_radar()
	# Estado del vehículo y nitro junto a la vista de la ruta.
	_panel(Rect2(223, 556, 220, 133))
	_text(Vector2(240, 582), tr("CONDITION"), 12, MUTED)
	_text(Vector2(422, 582), "%03d" % int(player.health), 15, PAPER, false, true)
	_bar(Rect2(240, 594, 183, 5), player.health / 100.0, RED if player.health < 30 else PAPER)
	_text(Vector2(240, 627), tr("NITRO"), 12, CYAN)
	_text(Vector2(422, 627), "SHIFT", 11, MUTED, false, true)
	_bar(Rect2(240, 639, 183, 7), player.nitro / 100.0, CYAN)
	_text(Vector2(240, 671), tr("NEAR_MISSES") + "  %02d" % game.pursuit.near_misses, 11, MUTED)
	_draw_speedometer()
	_text(Vector2(640, 670), "%04.2f km   /   %02d:%02d" % [player.distance / 1000.0, int(game.pursuit.elapsed) / 60, int(game.pursuit.elapsed) % 60], 19, PAPER, true)
	_text(Vector2(640, 695), tr("QUICK_CONTROLS") + ("  ·  " + tr("MUTED") if game.audio.muted else ""), 11, MUTED, true)
	if game.state != "running":
		_draw_menu()


func _draw_speedometer() -> void:
	var speed: float = game.player.speed * 3.6
	_panel(Rect2(1030, 521, 220, 168))
	draw_rect(Rect2(1030, 521, 220, 3), CYAN if game.player.boosting else AMBER)
	_text(Vector2(1228, 623), "%03d" % int(speed), 85, PAPER, false, true)
	_text(Vector2(1229, 652), "KM/H", 13, MUTED, false, true)
	_text(Vector2(1049, 653), "N" if speed < 1 else "%d" % mini(6, 1 + int(speed / 54.0)), 26, AMBER)
	for index in range(16):
		draw_rect(Rect2(1049 + index * 11, 667, 7, 5), CYAN if game.player.boosting else AMBER if speed > index * 21.0 else Color("3d4653"))


func _draw_radar() -> void:
	_panel(Rect2(30, 500, 175, 189))
	_text(Vector2(45, 524), tr("RADAR"), 11, MUTED)
	var area := Rect2(49, 537, 136, 135)
	for x in range(5):
		draw_line(Vector2(area.position.x + x * 34, area.position.y), Vector2(area.position.x + x * 34, area.end.y), Color(0.6, 0.7, 0.8, 0.15), 1.0)
	var player: Node3D = game.player
	for actor: Dictionary in game.pursuit.traffic + game.pursuit.police:
		var relative: float = actor.distance - player.distance
		if relative > -65 and relative < 160:
			var at := Vector2(117 + actor.offset * 4.6, 633 - relative * 0.55)
			draw_rect(Rect2(at - Vector2(2, 4), Vector2(4, 8)), RED if actor in game.pursuit.police else MUTED)
	var marker := Vector2(117 + player.offset * 4.6, 633)
	draw_colored_polygon(PackedVector2Array([marker + Vector2(0,-7), marker + Vector2(-5,5), marker + Vector2(5,5)]), CYAN)


func _speed_effects(player: Node3D) -> void:
	var strength := clampf((player.speed - 40.0) / 54.0, 0.0, 1.0)
	if strength > 0.0:
		for index in range(28):
			var angle := index * 2.39996
			var phase := fmod(time * (0.8 + strength) + index * 0.137, 1.0)
			var direction := Vector2(cos(angle), sin(angle) * 0.62)
			var start := Vector2(640, 340) + direction * (490 + phase * 360)
			var end := start + direction * (25 + phase * 100) * strength
			draw_line(start, end, Color(0.77, 0.9, 1.0, strength * (1.0 - phase) * 0.2), 1.2, true)
	if player.boosting:
		draw_rect(Rect2(0, 0, 4, 720), Color(0.3, 0.8, 1.0, 0.5))
		draw_rect(Rect2(1276, 0, 4, 720), Color(0.3, 0.8, 1.0, 0.5))
	if player.impact > 0.0:
		draw_rect(Rect2(0, 0, 1280, 720), Color(0.95, 0.19, 0.13, player.impact * 0.16))
	# Los destellos periféricos avisan de un patrullero cercano.
	if game.pursuit.nearest_police < 35.0:
		var pulse := 0.06 + absf(sin(time * 15.0)) * 0.12
		draw_rect(Rect2(0, 170, 7, 240), Color(1.0, 0.15, 0.2, pulse))
		draw_rect(Rect2(1273, 170, 7, 240), Color(0.1, 0.4, 1.0, pulse))


func _draw_menu() -> void:
	draw_rect(Rect2(-1000, -1000, 4000, 3000), Color(0.02, 0.04, 0.08, 0.72))
	_panel(Rect2(330, 125, 620, 505), 0.94)
	draw_rect(Rect2(330, 125, 620, 4), CYAN if game.state == "escaped" else AMBER)
	_text(Vector2(640, 170), "QUINTA FONDO  /  01", 14, AMBER, true)
	var title_key := "INTRO_TITLE"
	var body_key := "INTRO_BODY"
	match game.state:
		"paused":
			title_key = "PAUSED"
			body_key = "PAUSE_BODY"
		"escaped":
			title_key = "ESCAPED"
			body_key = "ESCAPED_BODY"
		"busted":
			title_key = "BUSTED"
			body_key = "BUSTED_BODY"
	_text(Vector2(640, 233), tr(title_key), 40, PAPER, true)
	_text(Vector2(640, 274), tr(body_key), 15, MUTED, true)
	if game.state == "ready" or game.state == "paused":
		var lines := [tr("HELP_DRIVE"), tr("HELP_NITRO"), tr("HELP_BRAKE"), tr("HELP_CAMERA")]
		for index in lines.size():
			_text(Vector2(640, 332 + index * 31), lines[index], 16, PAPER, true)
	else:
		_text(Vector2(640, 345), "%04.2f km    /    %02d:%02d    /    %d %s" % [game.player.distance / 1000.0, int(game.pursuit.elapsed) / 60, int(game.pursuit.elapsed) % 60, game.pursuit.near_misses, tr("NEAR_MISSES")], 22, AMBER, true)
		_text(Vector2(640, 401), tr("RETRY_HINT"), 16, MUTED, true)
	_text(Vector2(640, 487), tr("OBJECTIVE"), 13, CYAN, true)


func _panel(rect: Rect2, opacity := 0.8) -> void:
	draw_rect(rect, Color(INK, opacity))


func _bar(rect: Rect2, value: float, color: Color) -> void:
	draw_rect(rect, Color("384250"))
	draw_rect(Rect2(rect.position, Vector2(rect.size.x * clampf(value, 0.0, 1.0), rect.size.y)), color)


func _text(at: Vector2, text: String, size: int, color: Color, centered := false, right := false) -> void:
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	if centered:
		at.x -= width * 0.5
	elif right:
		at.x -= width
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
