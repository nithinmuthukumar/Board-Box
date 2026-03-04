extends CharacterBody3D

@export var move_speed: float = 4.5
@export var acceleration: float = 18.0
@export var mouse_sensitivity: float = 0.10
@export var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

@export var head_path: NodePath
@export var camera_path: NodePath

var _head: Node3D
var _camera: Camera3D
var _pitch: float = 0.0

func _ready() -> void:
	_head = get_node(head_path) as Node3D
	_camera = get_node(camera_path) as Camera3D
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		# Yaw: rotate the body
		rotate_y(deg_to_rad(-event.relative.x * mouse_sensitivity))

		# Pitch: rotate the head
		_pitch = clamp(_pitch - event.relative.y * mouse_sensitivity, -89.0, 89.0)
		_head.rotation_degrees.x = _pitch

	if event.is_action_pressed("ui_cancel"):
		# Toggle mouse capture (handy for testing)
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _physics_process(delta: float) -> void:

	# WASD movement in local space
	var input_vec := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var dir := (transform.basis * Vector3(input_vec.x, 0.0, input_vec.y)).normalized()

	var target_vel := dir * move_speed

	velocity.x = move_toward(velocity.x, target_vel.x, acceleration * delta)
	velocity.z = move_toward(velocity.z, target_vel.z, acceleration * delta)

	move_and_slide()

func get_view_camera() -> Camera3D:
	return _camera
