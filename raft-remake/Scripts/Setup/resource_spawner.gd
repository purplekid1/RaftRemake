extends Node3D

@export_group("Spawning Rules")
## Drag your FloatingWood scene (and plastic/leaves later) into this array in the Inspector
@export var item_scenes: Array[PackedScene]

@export var spawn_width: float = 40.0 # How wide the horizontal spawn line is
@export var spawn_distance: float = 60.0 # How far away from the center they spawn

@onready var spawn_timer: Timer = $Timer

func _ready():
	# Connect the timer through code so you don't have to use the Node tab manually
	spawn_timer.timeout.connect(_on_timer_timeout)

func _on_timer_timeout():
	if item_scenes.is_empty():
		push_warning("ResourceSpawner: No items in the array to spawn!")
		return
		
	# Pick a random item from the list
	var scene_to_spawn = item_scenes.pick_random()
	if not scene_to_spawn: return
		
	var item = scene_to_spawn.instantiate()
	
	# Add the item to the main world tree, NOT as a child of the spawner.
	# This ensures the items move independently.
	get_tree().current_scene.add_child(item) 
	
	# Pick a random spot left or right of the center
	var random_x = randf_range(-spawn_width / 2.0, spawn_width / 2.0)
	
	# Set the position (X is random, Y is 0 for water level, Z is far away)
	# Assuming your raft stays roughly around Vector3.ZERO
	item.global_position = Vector3(random_x, 0, -spawn_distance)
	
	# Optional: Give it a random rotation so they don't all look identical
	item.rotation.y = randf_range(0, PI * 2)
