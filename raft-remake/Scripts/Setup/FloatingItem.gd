extends Area3D
class_name FloatingItem

@export_group("Settings")
@export var speed: float = 3.0
@export var float_direction: Vector3 = Vector3(0, 0, 1)
@export var despawn_z: float = 30.0
@export var wood_amount: int = 1

func _ready():
	body_entered.connect(_on_body_entered)

func _process(delta):
	global_position += float_direction * speed * delta

	if global_position.z > despawn_z:
		queue_free()

func _on_body_entered(body: Node3D):
	if not body is CharacterBody3D:
		return

	var inventory_manager: InventoryManager = body.get_node_or_null("CanvasLayer")
	if inventory_manager:
		inventory_manager.add_wood(wood_amount)
		queue_free()
