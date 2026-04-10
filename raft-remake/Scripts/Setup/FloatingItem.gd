extends Area3D
class_name FloatingItem

@export_group("Settings")
@export var speed: float = 3.0
# Assuming your raft is at Z=0, spawning at -Z and flowing towards +Z
@export var float_direction: Vector3 = Vector3(0, 0, 1) 
@export var despawn_z: float = 30.0 # How far behind the raft before it deletes itself

func _process(delta):
	# Move the item continuously
	global_position += float_direction * speed * delta
	
	# Memory Management: Delete the item if the player missed it and it floated too far away
	if global_position.z > despawn_z:
		queue_free()

# We will call this later when the player's hook or body touches it!
func collect():
	# You can add a sound effect or particle here later
	queue_free()
