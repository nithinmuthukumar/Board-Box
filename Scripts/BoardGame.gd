extends StaticBody3D

enum State { ON_SHELF, MOVING, ON_TABLE }

@export var table_position: Vector3 = Vector3(0.795, 3.523, -2.08)
@export var move_duration: float = 0.8
@export var piece_scene: PackedScene
@export var piece_count: int = 6

var _state: State = State.ON_SHELF
var _shelf_position: Vector3
var _shelf_rotation: Vector3
var _table_position_global: Vector3
var _tween: Tween = null
var _spawned_pieces: Array[RigidBody3D] = []

# Spawn offsets for a 2-column grid on the table surface
const SPAWN_OFFSETS: Array = [
	Vector3(-0.06, 0.15, -0.05),
	Vector3( 0.06, 0.15, -0.05),
	Vector3(-0.06, 0.15,  0.00),
	Vector3( 0.06, 0.15,  0.00),
	Vector3(-0.06, 0.15,  0.05),
	Vector3( 0.06, 0.15,  0.05),
]

func _ready() -> void:
	_shelf_position = global_position
	_shelf_rotation = global_rotation
	_table_position_global = get_parent().to_global(table_position)
	add_to_group("interactable")

func interact() -> void:
	if _state == State.MOVING:
		return
	match _state:
		State.ON_SHELF:
			_move_to(_table_position_global, Vector3.ZERO, State.ON_TABLE)
		State.ON_TABLE:
			_move_to(_shelf_position, _shelf_rotation, State.ON_SHELF)

func get_interact_prompt() -> String:
	match _state:
		State.ON_SHELF:
			return "Press F to take out"
		State.ON_TABLE:
			return "Press F to put away"
		_:
			return ""

func _move_to(target_pos: Vector3, target_rot: Vector3, next_state: State) -> void:
	if _tween:
		_tween.kill()
	_state = State.MOVING
	_tween = create_tween()
	_tween.set_ease(Tween.EASE_IN_OUT)
	_tween.set_trans(Tween.TRANS_CUBIC)
	_tween.set_parallel(true)
	_tween.tween_property(self, "global_position", target_pos, move_duration)
	_tween.tween_property(self, "global_rotation", target_rot, move_duration)
	_tween.set_parallel(false)
	_tween.tween_callback(func():
		_state = next_state
		if next_state == State.ON_TABLE:
			_spawn_pieces()
		elif next_state == State.ON_SHELF:
			_clear_pieces()
	)

func _clear_pieces() -> void:
	for piece in _spawned_pieces:
		if is_instance_valid(piece):
			piece.queue_free()
	_spawned_pieces.clear()

func _spawn_pieces() -> void:
	if piece_scene == null:
		return
	var count = min(piece_count, SPAWN_OFFSETS.size())
	for i in count:
		var piece: RigidBody3D = piece_scene.instantiate()
		get_tree().root.add_child(piece)
		piece.global_position = _table_position_global + SPAWN_OFFSETS[i]
		_spawned_pieces.append(piece)
