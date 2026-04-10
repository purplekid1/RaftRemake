extends CharacterBody3D

@export_group("Movement")
@export var move_speed: float = 4.0
@export var sprint_speed: float = 7.0
@export var jump_velocity: float = 4.5
@export var gravity: float = 9.8
@export var climb_speed: float = 4.0

@export_group("Mouse Look")
@export var mouse_sensitivity: float = 0.002
@export var max_look_angle: float = 89.0

@export_group("Hook")
@export var hook_min_distance: float = 5.0
@export var hook_max_distance: float = 35.0
@export var hook_max_charge_time: float = 1.5

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var inventory_manager: InventoryManager = $CanvasLayer
@onready var hook_charge_bar: ProgressBar = $CanvasLayer/HookChargeBar
@onready var hook_info_label: Label = $CanvasLayer/HookInfoLabel

var is_climbing: bool = false
var is_charging_hook: bool = false
var hook_charge_time: float = 0.0

func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	hook_charge_bar.visible = false
	hook_info_label.visible = false

func set_climbing(status: bool):
	is_climbing = status

func _input(event):
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not inventory_manager.is_open:
		rotate_y(-event.relative.x * mouse_sensitivity)
		head.rotate_x(-event.relative.y * mouse_sensitivity)
		head.rotation.x = clamp(head.rotation.x, deg_to_rad(-max_look_angle), deg_to_rad(max_look_angle))

	if inventory_manager.is_open:
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_start_hook_charge()
		else:
			_release_hook()

func _physics_process(delta):
	if Input.is_action_just_pressed("ui_cancel") and not inventory_manager.is_open:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED

	if inventory_manager.is_open:
		is_charging_hook = false
		hook_charge_bar.visible = false
		hook_info_label.visible = false
		velocity.x = 0.0
		velocity.z = 0.0
		if not is_on_floor() and not is_climbing:
			velocity.y -= gravity * delta
		move_and_slide()
		return

	if is_charging_hook:
		hook_charge_time = minf(hook_charge_time + delta, hook_max_charge_time)
		_update_hook_ui()

	if not is_on_floor() and not is_climbing:
		velocity.y -= gravity * delta
	elif is_climbing and not is_on_floor():
		velocity.y = 0

	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity

	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_back")

	if is_climbing:
		if input_dir.y < 0:
			velocity.y = climb_speed
		elif input_dir.y > 0:
			velocity.y = -climb_speed
		else:
			velocity.y = lerp(velocity.y, 0.0, 0.2)

	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	var speed = sprint_speed if Input.is_action_pressed("sprint") else move_speed

	if direction:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)

	move_and_slide()

func _start_hook_charge():
	is_charging_hook = true
	hook_charge_time = 0.0
	hook_charge_bar.visible = true
	hook_info_label.visible = true
	_update_hook_ui()

func _release_hook():
	if not is_charging_hook:
		return

	is_charging_hook = false
	hook_charge_bar.visible = false
	hook_info_label.visible = false

	var charge_ratio = clampf(hook_charge_time / hook_max_charge_time, 0.0, 1.0)
	var throw_distance = lerpf(hook_min_distance, hook_max_distance, charge_ratio)
	var origin = camera.global_position
	var direction = -camera.global_transform.basis.z
	var end = origin + (direction * throw_distance)
	var query = PhysicsRayQueryParameters3D.create(origin, end)
	query.exclude = [get_rid()]
	var hit = get_world_3d().direct_space_state.intersect_ray(query)
	if not hit:
		return

	var collider = hit.collider
	if collider is FloatingItem:
		collider.collect(inventory_manager)

func _update_hook_ui():
	var charge_ratio = clampf(hook_charge_time / hook_max_charge_time, 0.0, 1.0)
	var throw_distance = lerpf(hook_min_distance, hook_max_distance, charge_ratio)
	hook_charge_bar.value = charge_ratio * 100.0
	hook_info_label.text = "Hook Charge: %d%%  Range: %.1fm" % [int(round(charge_ratio * 100.0)), throw_distance]
