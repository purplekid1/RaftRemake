extends CharacterBody3D

# --- Movement ---
@export var move_speed: float = 4.0
@export var sprint_speed: float = 7.0
@export var jump_velocity: float = 4.5
@export var gravity: float = 9.8
@export var climb_speed: float = 4.0 # Added for ladder movement

# --- Mouse Look ---
@export var mouse_sensitivity: float = 0.002
@export var max_look_angle: float = 89.0  # degrees, prevents flipping

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D

# --- Ladder State ---
var is_climbing: bool = false # Added to track ladder contact

func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

# This function will be called by your Ladder's Area3D signals
func set_climbing(status: bool):
	is_climbing = status

func _input(event):
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity)
		head.rotate_x(-event.relative.y * mouse_sensitivity)
		head.rotation.x = clamp(head.rotation.x, deg_to_rad(-max_look_angle), deg_to_rad(max_look_angle))

func _physics_process(delta):
	
	if Input.is_action_just_pressed("ui_cancel"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	# Gravity - Only apply if not on a ladder
	if not is_on_floor() and not is_climbing:
		velocity.y -= gravity * delta
	elif is_climbing and not is_on_floor():
		# Stop falling if we are touching a ladder but not moving
		velocity.y = 0

	# Jump
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity

	# Get input vector
	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	
	# Handle Ladder Climbing logic
	if is_climbing:
		# move_forward is negative Y in get_vector
		if input_dir.y < 0: 
			velocity.y = climb_speed
		elif input_dir.y > 0: 
			velocity.y = -climb_speed
		else:
			velocity.y = lerp(velocity.y, 0.0, 0.2) # Smooth stop on ladder
	
	# Movement direction relative to where player is facing
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	var speed = sprint_speed if Input.is_action_pressed("sprint") else move_speed

	if direction:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		# Smooth stop
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)

	move_and_slide()
