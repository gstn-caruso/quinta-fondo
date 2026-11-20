extends Node3D
## Carga una autopista circular de 16 km alrededor de un origen móvil y acotado.

const SEGMENT_LENGTH := 50.0
const SEGMENT_COUNT := 320
const LENGTH := SEGMENT_LENGTH * SEGMENT_COUNT
const RADIUS := LENGTH / TAU
const BEHIND := 4
const AHEAD := 27
const LANES := [-7.5, -2.5, 2.5, 7.5]

var chunks: Dictionary = {}
var mesh_cache: Dictionary = {}
var road_material: StandardMaterial3D
var viewer_distance := 0.0


func _ready() -> void:
	road_material = StandardMaterial3D.new()
	road_material.vertex_color_use_as_albedo = true
	road_material.roughness = 0.88
	update_road(0.0)


static func point(relative_distance: float, offset := 0.0) -> Vector3:
	var angle := relative_distance / RADIUS
	return Vector3(RADIUS * (1.0 - cos(angle)) + offset * cos(angle), 0.0, -RADIUS * sin(angle) + offset * sin(angle))


func update_road(distance: float) -> void:
	viewer_distance = distance
	var center := int(floor(distance / SEGMENT_LENGTH))
	for index: int in chunks.keys():
		if index < center - BEHIND or index > center + AHEAD:
			chunks[index].queue_free()
			chunks.erase(index)
	for index in range(center - BEHIND, center + AHEAD + 1):
		if not chunks.has(index):
			var chunk := MeshInstance3D.new()
			var wrapped := posmod(index, SEGMENT_COUNT)
			if not mesh_cache.has(wrapped):
				mesh_cache[wrapped] = _build_chunk(wrapped)
			chunk.mesh = mesh_cache[wrapped]
			chunk.material_override = road_material
			chunk.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(chunk)
			chunks[index] = chunk
			if wrapped % 8 == 0:
				_add_sign(chunk, wrapped)
		var relative := index * SEGMENT_LENGTH - distance
		chunks[index].position = point(relative)
		chunks[index].rotation.y = -relative / RADIUS


func _build_chunk(index: int) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var asphalt := Color("303640")
	var shoulder := Color("444954")
	var grass := Color("525744")
	var white := Color("ded9bb")
	var metal := Color("9aa3a7")
	var concrete := Color("69747d")
	for step in range(5):
		var start := step * 10.0
		_strip(surface, start, start + 10.0, -14.0, 14.0, 0.0, shoulder)
		_strip(surface, start, start + 10.0, -10.2, 10.2, 0.012, asphalt)
		for lane: float in LANES:
			for wheel: float in [-0.72, 0.72]:
				_strip(surface, start, start + 10.0, lane + wheel - 0.2, lane + wheel + 0.2, 0.014, asphalt.darkened(0.055))
		_strip(surface, start, start + 10.0, -110.0, -14.0, -0.25, grass)
		_strip(surface, start, start + 10.0, 14.0, 110.0, -0.25, grass)
		for edge: float in [-10.3, 10.3]:
			_strip(surface, start, start + 10.0, edge - 0.08, edge + 0.08, 0.025, white)
	for dash in range(4):
		for lane: float in [-5.0, 0.0, 5.0]:
			_strip(surface, dash * 12.5, dash * 12.5 + 5.0, lane - 0.09, lane + 0.09, 0.03, white)
	for rumble in range(16):
		for side: float in [-1.0, 1.0]:
			_strip(surface, rumble * 3.125, rumble * 3.125 + 0.38, side * 11.55 - 0.42, side * 11.55 + 0.42, 0.03, Color("8e9294"))
	for side: float in [-1.0, 1.0]:
		for step in range(5):
			var along := step * 10.0 + 5.0
			var angle := -along / RADIUS
			_box(surface, point(along, side * 13.3) + Vector3(0, 0.6, 0), Vector3(0.32, 1.2, 10.1), concrete, angle)
			_box(surface, point(along, side * 13.3) + Vector3(0, 1.28, 0), Vector3(0.18, 0.13, 10.1), metal, angle)
			_box(surface, point(along, side * 13.08) + Vector3(0, 0.91, 0), Vector3(0.06, 0.13, 0.35), Color("f4bd5e"), angle)
		if index % 2 == 0:
			var lamp := point(22.0, side * 15.0)
			_box(surface, lamp + Vector3(0, 5.2, 0), Vector3(0.22, 10.5, 0.22), metal)
			_box(surface, lamp + Vector3(-side * 1.7, 10.4, 0), Vector3(3.6, 0.18, 0.3), metal)
			_box(surface, lamp + Vector3(-side * 3.1, 10.25, 0), Vector3(1.3, 0.1, 0.6), Color("ffebba"))
	var rng := RandomNumberGenerator.new()
	rng.seed = index * 8191 + 71
	for side: float in [-1.0, 1.0]:
		for building in range(3):
			var along := rng.randf_range(0, 50)
			var offset := side * rng.randf_range(55, 180)
			var height := rng.randf_range(12, 75) if index % 24 < 15 else rng.randf_range(4, 19)
			var width := rng.randf_range(12, 27)
			var at := point(along, offset)
			var tint := Color("535d6f").lerp(Color("b0a69a"), rng.randf() * 0.7)
			_box(surface, at + Vector3(0, height * 0.5 - 0.2, 0), Vector3(width, height, 17), tint)
			for floor_index in range(2, int(height / 3.5), 2):
				_box(surface, at + Vector3(-side * (width * 0.5 + 0.02), floor_index * 3.5, 0), Vector3(0.04, 0.7, 12.0), Color("d7ba82"))
		for tree in range(3):
			var at := point(tree * 17.0, side * rng.randf_range(20, 34))
			_box(surface, at + Vector3(0, 1.7, 0), Vector3(0.45, 3.4, 0.45), Color("5b4941"))
			_box(surface, at + Vector3(0, 4.0, 0), Vector3(3.2, 4.7, 3.2), Color("3b554b"))
	if index % 8 == 0:
		for side: float in [-1.0, 1.0]:
			_box(surface, Vector3(side * 14.7, 4.8, -25), Vector3(0.5, 9.6, 0.5), metal)
		_box(surface, Vector3(0, 9.1, -25), Vector3(30, 0.5, 0.5), metal)
		_box(surface, Vector3(0, 8.0, -25), Vector3(15, 2.8, 0.22), Color("245963"))
	return surface.commit()


func _strip(surface: SurfaceTool, start: float, end: float, left: float, right: float, height: float, color: Color) -> void:
	var corners := [point(start, left), point(start, right), point(end, right), point(end, left)]
	surface.set_color(color.srgb_to_linear())
	surface.set_normal(Vector3.UP)
	for corner: int in [0, 2, 1, 0, 3, 2]:
		surface.add_vertex(corners[corner] + Vector3(0, height, 0))


func _box(surface: SurfaceTool, at: Vector3, size: Vector3, color: Color, yaw := 0.0) -> void:
	var basis := Basis(Vector3.UP, yaw)
	var corners: Array[Vector3] = []
	for v: Vector3 in [Vector3(-1,-1,-1), Vector3(1,-1,-1), Vector3(1,1,-1), Vector3(-1,1,-1), Vector3(-1,-1,1), Vector3(1,-1,1), Vector3(1,1,1), Vector3(-1,1,1)]:
		corners.append(at + basis * (v * size * 0.5))
	surface.set_color(color.srgb_to_linear())
	var faces := [[0,1,2,3], [5,4,7,6], [4,0,3,7], [1,5,6,2], [3,2,6,7], [4,5,1,0]]
	var normals := [Vector3.FORWARD, Vector3.BACK, Vector3.LEFT, Vector3.RIGHT, Vector3.UP, Vector3.DOWN]
	for face_index in faces.size():
		surface.set_normal(basis * normals[face_index])
		var face: Array = faces[face_index]
		for vertex: int in [0,1,2,0,2,3]:
			surface.add_vertex(corners[face[vertex]])


func _add_sign(chunk: Node3D, index: int) -> void:
	var label := Label3D.new()
	label.text = "QUINTA FONDO   /   %02d\n%s   ↓  ↓  ↓  ↓" % [index / 8 + 1, tr("HIGHWAY_SIGN")]
	label.font_size = 54
	label.pixel_size = 0.012
	label.position = Vector3(0, 8.05, -24.85)
	label.modulate = Color("d9eddf")
	label.outline_size = 0
	label.no_depth_test = false
	chunk.add_child(label)
