extends StaticBody3D

@onready var mesh: MeshInstance3D = get_parent().get_node("CarMesh")

func _ready() -> void:
	# Make sure the body receives hover events
	input_ray_pickable = true

func _input_event(
	_camera: Camera3D,
	event: InputEvent,
	_position: Vector3,
	_normal: Vector3,
	_shape_idx: int
) -> void:
	if event is InputEventMouseButton \
	and event.button_index == MOUSE_BUTTON_LEFT \
	and event.pressed:
		get_tree().current_scene.open_car_panel(get_parent())

func _mouse_enter() -> void:
	_set_glow(true)

func _mouse_exit() -> void:
	_set_glow(false)

func _set_glow(on: bool) -> void:
	var mat := mesh.get_active_material(0)
	if mat is StandardMaterial3D:
		mat.emission_enabled = true
		mat.emission_energy_multiplier = 2.0 if on else 0.0
