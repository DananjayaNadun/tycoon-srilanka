extends Camera3D

var speed := 10.0
var zoom_speed := 2.0

func _process(delta):
	var dir = Vector3.ZERO
	
	if Input.is_action_pressed("cam_left"):
		dir.x -= 1
	if Input.is_action_pressed("cam_right"):
		dir.x += 1
	if Input.is_action_pressed("cam_up"):
		dir.z -= 1
	if Input.is_action_pressed("cam_down"):
		dir.z += 1
	
	global_position += dir.normalized() * speed * delta

func _unhandled_input(event):
	if event.is_action_pressed("cam_zoom_in"):
		global_position.y -= zoom_speed
	if event.is_action_pressed("cam_zoom_out"):
		global_position.y += zoom_speed
