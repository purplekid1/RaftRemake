extends Node
class_name InventoryManager

signal resources_changed(resource_type: String, amount: int)
signal crafted_changed(item_type: String, amount: int)
signal slots_changed(used_slots: int, total_slots: int)

@export_group("Starting Resources")
@export var wood: int = 0

@export_group("Crafting Costs")
@export var raft_tile_wood_cost: int = 2
@export var ladder_tile_wood_cost: int = 4
@export var wall_tile_wood_cost: int = 3
@export var backpack_wood_cost: int = 10

@export_group("Inventory")
@export var base_slot_count: int = 5
@export var backpack_slot_bonus: int = 3
@export var max_stack_per_slot: int = 20

var is_open: bool = false
var crafted_raft_tiles: int = 0
var crafted_ladder_tiles: int = 0
var backpack_count: int = 0

@export var inventory_ui: Control

@onready var wood_label: Label = inventory_ui.get_node("TabContainer/InventoryTab/MarginContainer/VBoxContainer/WoodLabel")
@onready var raft_count_label: Label = inventory_ui.get_node("TabContainer/InventoryTab/MarginContainer/VBoxContainer/RaftCountLabel")
@onready var wall_cost_label: Label = inventory_ui.get_node("TabContainer/InventoryTab/MarginContainer/VBoxContainer/WallCostLabel")
@onready var ladder_count_label: Label = inventory_ui.get_node("TabContainer/InventoryTab/MarginContainer/VBoxContainer/LadderCountLabel")
@onready var slot_label: Label = inventory_ui.get_node("TabContainer/InventoryTab/MarginContainer/VBoxContainer/SlotLabel")
@onready var slot_grid_label: Label = inventory_ui.get_node("TabContainer/InventoryTab/MarginContainer/VBoxContainer/SlotGridLabel")
@onready var backpack_label: Label = inventory_ui.get_node("TabContainer/InventoryTab/MarginContainer/VBoxContainer/BackpackLabel")

@onready var raft_craft_button: Button = inventory_ui.get_node("TabContainer/CraftingTab/MarginContainer/VBoxContainer/RaftCraftButton")
@onready var ladder_craft_button: Button = inventory_ui.get_node("TabContainer/CraftingTab/MarginContainer/VBoxContainer/LadderCraftButton")
@onready var backpack_craft_button: Button = inventory_ui.get_node("TabContainer/CraftingTab/MarginContainer/VBoxContainer/BackpackCraftButton")

func _ready():
	if not inventory_ui:
		push_warning("InventoryManager: No Inventory UI assigned.")
		return

	raft_craft_button.pressed.connect(_craft_raft_tile)
	ladder_craft_button.pressed.connect(_craft_ladder_tile)
	backpack_craft_button.pressed.connect(_craft_backpack)
	_update_ui()

func _input(event):
	if event.is_action_pressed("inventory"):
		toggle_inventory()

func toggle_inventory():
	if not inventory_ui:
		push_warning("InventoryManager: No Inventory UI assigned.")
		return

	is_open = not is_open
	inventory_ui.visible = is_open
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if is_open else Input.MOUSE_MODE_CAPTURED

func add_wood(amount: int) -> int:
	if amount <= 0:
		return 0

	var free_capacity = (get_total_slots() * max_stack_per_slot) - wood
	var wood_added = mini(amount, free_capacity)
	if wood_added <= 0:
		return 0

	wood += wood_added
	resources_changed.emit("wood", wood)
	_update_ui()
	return wood_added

func can_afford_wood(amount: int) -> bool:
	return wood >= amount

func spend_wood(amount: int) -> bool:
	if amount <= 0:
		return true
	if wood < amount:
		return false

	wood -= amount
	resources_changed.emit("wood", wood)
	_update_ui()
	return true

func has_crafted_piece(build_type: String) -> bool:
	match build_type:
		"raft":
			return crafted_raft_tiles > 0
		"ladder":
			return crafted_ladder_tiles > 0
		_:
			return false

func consume_crafted_piece(build_type: String) -> bool:
	if not has_crafted_piece(build_type):
		return false

	match build_type:
		"raft":
			crafted_raft_tiles -= 1
			crafted_changed.emit("raft", crafted_raft_tiles)
		"ladder":
			crafted_ladder_tiles -= 1
			crafted_changed.emit("ladder", crafted_ladder_tiles)
		_:
			return false

	_update_ui()
	return true

func get_total_slots() -> int:
	return base_slot_count + (backpack_count * backpack_slot_bonus)

func get_used_slots() -> int:
	return int(ceili(float(wood) / float(max_stack_per_slot)))

func get_build_mode_hint(build_type: String) -> String:
	match build_type:
		"raft":
			return "Raft: need 1 crafted tile (craft cost %d wood). You own %d." % [raft_tile_wood_cost, crafted_raft_tiles]
		"wall":
			return "Wall: place cost %d wood. You own %d wood." % [wall_tile_wood_cost, wood]
		"ladder":
			return "Ladder: need 1 crafted ladder (craft cost %d wood). You own %d." % [ladder_tile_wood_cost, crafted_ladder_tiles]
		"break":
			return "Break mode: remove existing structure."
		_:
			return "Select a build type."

func _craft_raft_tile():
	if not spend_wood(raft_tile_wood_cost):
		return
	crafted_raft_tiles += 1
	crafted_changed.emit("raft", crafted_raft_tiles)
	_update_ui()

func _craft_ladder_tile():
	if not spend_wood(ladder_tile_wood_cost):
		return
	crafted_ladder_tiles += 1
	crafted_changed.emit("ladder", crafted_ladder_tiles)
	_update_ui()

func _craft_backpack():
	if not spend_wood(backpack_wood_cost):
		return
	backpack_count += 1
	slots_changed.emit(get_used_slots(), get_total_slots())
	_update_ui()

func _slot_visual_text() -> String:
	var result := ""
	for i in range(get_total_slots()):
		var used = i < get_used_slots()
		result += "[%s]" % ("W" if used else " ")
		if (i + 1) % 5 == 0:
			result += "\n"
	return result

func _update_ui():
	if not inventory_ui:
		return

	wood_label.text = "Wood: %d" % wood
	raft_count_label.text = "Raft tiles: %d" % crafted_raft_tiles
	wall_cost_label.text = "Walls use wood directly: %d wood each" % wall_tile_wood_cost
	ladder_count_label.text = "Ladder tiles: %d" % crafted_ladder_tiles
	slot_label.text = "Slots used: %d / %d" % [get_used_slots(), get_total_slots()]
	slot_grid_label.text = _slot_visual_text()
	backpack_label.text = "Backpacks crafted: %d" % backpack_count

	raft_craft_button.text = "Craft Raft Tile (%d wood)" % raft_tile_wood_cost
	ladder_craft_button.text = "Craft Ladder Tile (%d wood)" % ladder_tile_wood_cost
	backpack_craft_button.text = "Craft Backpack (+%d slots, %d wood)" % [backpack_slot_bonus, backpack_wood_cost]

	raft_craft_button.disabled = wood < raft_tile_wood_cost
	ladder_craft_button.disabled = wood < ladder_tile_wood_cost
	backpack_craft_button.disabled = wood < backpack_wood_cost
	slots_changed.emit(get_used_slots(), get_total_slots())
