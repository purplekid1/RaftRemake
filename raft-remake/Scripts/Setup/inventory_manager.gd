extends Node

signal resources_changed(type, amount)

# Adding @export allows you to set the starting wood in the Inspector
@export_group("Starting Resources")
@export var wood: int = 40 

var is_open: bool = false

# It's safer to use @export for the UI too, so you can drag and drop it
@export var inventory_ui: Control 

func _input(event):
	# event.is_action_pressed handles the "just down" state for specific events
	if event.is_action_pressed("inventory"):
		toggle_inventory()

func toggle_inventory():
	if not inventory_ui:
		print("Warning: No Inventory UI assigned to the Inventory script!")
		return
		
	is_open = !is_open
	inventory_ui.visible = is_open
	
	# Pause/Unpause mouse look
	if is_open:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func has_resources(amount: int) -> bool:
	return wood >= amount

func spend_resources(amount: int):
	wood -= amount
	resources_changed.emit("wood", wood)
