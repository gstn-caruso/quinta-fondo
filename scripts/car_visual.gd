extends Node3D
## Vehículos originales de pocos polígonos, construidos con mallas nativas.

var wheels: Array[MeshInstance3D] = []
var jets: Array[MeshInstance3D] = []
var beacons: Array[MeshInstance3D] = []
var clock := 0.0
var body_material: StandardMaterial3D
var brake_material: StandardMaterial3D
var materials: Dictionary = {}


func build(color: Color, police := false, sporty := false) -> void:
	body_material = _material(color, 0.45, 0.35)
	var dark := _material(Color("101723"), 0.5, 0.28)
	var glass := _material(Color("253c50"), 0.7, 0.18)
	var rubber := _material(Color("11131a"))
	var rim := _material(Color("b5bec8"), 0.8, 0.25)
	var white := _material(Color("dce3dd"), 0.35)
	brake_material = _material(Color("fd422f"), 0.1, 0.3, true)
	_box(Vector3(0, 0.66, 0), Vector3(1.92, 0.57, 4.25), body_material)
	_box(Vector3(0, 0.46, 0), Vector3(1.98, 0.14, 4.35), dark)
	_box(Vector3(0, 1.06, 0.13), Vector3(1.62, 0.52, 1.95), glass)
	_box(Vector3(0, 1.35, 0.25), Vector3(1.65, 0.11, 1.45), white if police else body_material)
	_box(Vector3(0, 1.06, 0.22), Vector3(1.67, 0.55, 0.12), dark)
	_box(Vector3(0, 0.67, -2.15), Vector3(1.22, 0.22, 0.04), dark)
	_box(Vector3(0, 0.62, 2.16), Vector3(0.9, 0.17, 0.04), dark)
	for side: float in [-1.0, 1.0]:
		_box(Vector3(side * 1.06, 1.0, -0.6), Vector3(0.24, 0.14, 0.3), body_material)
		_box(Vector3(side * 0.68, 0.77, -2.14), Vector3(0.49, 0.13, 0.05), _material(Color("fff0be"), 0.0, 0.4, true))
		_box(Vector3(side * 0.67, 0.77, 2.14), Vector3(0.53, 0.12, 0.05), brake_material)
		for axle: float in [-1.32, 1.32]:
			var wheel := MeshInstance3D.new()
			var cylinder := CylinderMesh.new()
			cylinder.top_radius = 0.38
			cylinder.bottom_radius = 0.38
			cylinder.height = 0.25
			cylinder.radial_segments = 12
			wheel.mesh = cylinder
			wheel.material_override = rubber
			wheel.position = Vector3(side * 0.99, 0.4, axle)
			wheel.rotation.z = PI / 2.0
			add_child(wheel)
			wheels.append(wheel)
			var hub := _box(Vector3(side * 1.13, 0.4, axle), Vector3(0.025, 0.36, 0.36), rim)
			hub.rotation.x = PI / 4.0
	if sporty:
		_box(Vector3(0, 0.96, -1.4), Vector3(0.32, 0.025, 1.1), dark)
		_box(Vector3(0, 1.12, 1.75), Vector3(2.14, 0.1, 0.43), dark)
		for side: float in [-1.0, 1.0]:
			_box(Vector3(side * 0.72, 0.95, 1.75), Vector3(0.08, 0.3, 0.12), dark)
			var jet := _box(Vector3(side * 0.63, 0.46, 2.65), Vector3(0.2, 0.2, 0.9), _material(Color("5adcff"), 0.0, 0.5, true))
			jet.visible = false
			jets.append(jet)
	if police:
		for side: float in [-1.0, 1.0]:
			_box(Vector3(side * 0.97, 0.76, 0.18), Vector3(0.025, 0.3, 1.95), white)
			_box(Vector3(side * 0.99, 0.78, 0.18), Vector3(0.028, 0.19, 0.33), dark)
		_box(Vector3(0, 1.48, 0.25), Vector3(1.3, 0.11, 0.32), dark)
		beacons.append(_box(Vector3(-0.4, 1.58, 0.25), Vector3(0.48, 0.15, 0.28), _material(Color("ff2849"), 0.0, 0.3, true)))
		beacons.append(_box(Vector3(0.4, 1.58, 0.25), Vector3(0.48, 0.15, 0.28), _material(Color("337dff"), 0.0, 0.3, true)))
	_merge_body()


func _merge_body() -> void:
	# Las piezas estáticas comparten una superficie por material para reducir dibujados.
	var batches: Dictionary = {}
	var surfaces: Dictionary = {}
	for child in get_children():
		if not child is MeshInstance3D or child in wheels or child in jets or child in beacons:
			continue
		var material: Material = child.material_override
		var key := material.get_instance_id()
		if not batches.has(key):
			var surface := SurfaceTool.new()
			surface.begin(Mesh.PRIMITIVE_TRIANGLES)
			batches[key] = surface
			surfaces[key] = material
		batches[key].append_from(child.mesh, 0, child.transform)
		child.free()
	var combined := ArrayMesh.new()
	for key: int in batches:
		batches[key].set_material(surfaces[key])
		batches[key].commit(combined)
	var body := MeshInstance3D.new()
	body.mesh = combined
	add_child(body)


func animate(delta: float, speed: float, boost := false, braking := false) -> void:
	clock += delta
	for wheel in wheels:
		wheel.rotate_object_local(Vector3.UP, speed * delta / 0.38)
	for jet in jets:
		jet.visible = boost
		jet.scale.z = 1.0 + sin(clock * 75.0) * 0.28
	for index in beacons.size():
		beacons[index].visible = fmod(clock, 0.36) < 0.18 if index == 0 else fmod(clock, 0.36) >= 0.18
	brake_material.emission_energy_multiplier = 3.0 if braking else 0.7


func _box(at: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.material_override = material
	node.position = at
	add_child(node)
	return node


func _material(color: Color, metallic := 0.0, roughness := 0.8, glowing := false) -> StandardMaterial3D:
	var key := "%s/%s/%s/%s" % [color, metallic, roughness, glowing]
	if materials.has(key):
		return materials[key]
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = roughness
	if glowing:
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.emission_enabled = true
		material.emission = color
	materials[key] = material
	return material
