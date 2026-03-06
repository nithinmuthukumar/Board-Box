extends CharacterBody3D

@export var move_speed: float = 4.5
@export var acceleration: float = 18.0
@export var mouse_sensitivity: float = 0.10
@export var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
@export var head_path: NodePath
@export var camera_path: NodePath
@export var grab_prompt_path: NodePath

# Grab settings
@export var grab_distance: float = 3.0
@export var grab_stiffness: float = 120.0
@export var grab_damping: float = 12.0
@export var throw_force: float = 12.0
@export var min_hold_distance: float = 1.0
@export var max_hold_distance: float = 5.0
@export var scroll_speed: float = 0.5

var _head: Node3D
var _camera: Camera3D
var _pitch: float = 0.0

# Grab state
var _held_body: RigidBody3D = null
var _grab_prompt: Label
var _hold_distance: float = 2.5
var _raycast: RayCast3D
var _hold_point: Marker3D

func _ready() -> void:
	_head = get_node(head_path) as Node3D
	_camera = get_node(camera_path) as Camera3D
	if grab_prompt_path:
		_grab_prompt = get_node(grab_prompt_path) as Label
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	# Build RayCast3D at runtime (or you can add it in the scene instead)
	_raycast = RayCast3D.new()
	_raycast.target_position = Vector3(0, 0, -grab_distance)
	_raycast.collision_mask = 1  # adjust to match your grabbable layer
	_camera.add_child(_raycast)

	# Hold point floats in front of the camera
	_hold_point = Marker3D.new()
	_camera.add_child(_hold_point)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		rotate_y(deg_to_rad(-event.relative.x * mouse_sensitivity))
		_pitch = clamp(_pitch - event.relative.y * mouse_sensitivity, -89.0, 89.0)
		_head.rotation_degrees.x = _pitch

	# Grab / throw
	if event.is_action_pressed("grab"):
		if _held_body != null:
			_throw_object()
		else:
			_try_grab()

	# Scroll to adjust hold distance
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and _held_body != null:
			_hold_distance = clamp(_hold_distance + scroll_speed, min_hold_distance, max_hold_distance)
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN and _held_body != null:
			_hold_distance = clamp(_hold_distance - scroll_speed, min_hold_distance, max_hold_distance)

	if event.is_action_pressed("ui_cancel"):
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _physics_process(delta: float) -> void:

	# WASD movement
	var input_vec := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var dir := (transform.basis * Vector3(input_vec.x, 0.0, input_vec.y)).normalized()
	var target_vel := dir * move_speed
	velocity.x = move_toward(velocity.x, target_vel.x, acceleration * delta)
	velocity.z = move_toward(velocity.z, target_vel.z, acceleration * delta)
	move_and_slide()

	# Pull held object toward hold point each frame
	if _held_body != null:
		_update_held_object(delta)

	# Show grab prompt only when looking at a grabbable and not already holding
	if _grab_prompt != null:
		_raycast.force_raycast_update()
		var can_grab = _held_body == null and _raycast.is_colliding() and \
			_raycast.get_collider() is RigidBody3D and \
			_raycast.get_collider().is_in_group("grabbable")
		_grab_prompt.visible = can_grab

func _try_grab() -> void:
	_raycast.force_raycast_update()
	if not _raycast.is_colliding():
		return
	var collider = _raycast.get_collision_point()
	var body = _raycast.get_collider()
	if body is RigidBody3D and body.is_in_group("grabbable"):
		_held_body = body
		_hold_distance = _raycast.get_collision_point().distance_to(_camera.global_position)
		_hold_distance = clamp(_hold_distance, min_hold_distance, max_hold_distance)
		_held_body.gravity_scale = 0.0
		_held_body.linear_damp = 5.0

func _release_object() -> void:
	if _held_body == null:
		return
	_held_body.gravity_scale = 1.0
	_held_body.linear_damp = 0.0
	_held_body = null

func _throw_object() -> void:
	if _held_body == null:
		return
	var throw_dir := -_camera.global_transform.basis.z
	_held_body.gravity_scale = 1.0
	_held_body.linear_damp = 0.0
	_held_body.linear_velocity = Vector3.ZERO
	_held_body.apply_central_impulse(throw_dir * throw_force)
	_held_body = null

func _update_held_object(delta: float) -> void:
	_hold_point.position = Vector3(0, 0, -_hold_distance)
	var target_pos := _hold_point.global_position

	var error := target_pos - _held_body.global_position
	_held_body.linear_velocity += error * grab_stiffness * delta
	_held_body.linear_velocity -= _held_body.linear_velocity * grab_damping * delta

func get_view_camera() -> Camera3D:
	return _camera
