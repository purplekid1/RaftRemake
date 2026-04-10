extends Node
class_name InventoryManager

signal resources_changed(resource_type: String, amount: int)
signal crafted_changed(item_type: String, amount: int)

@export_group("Starting Resources")
@export var wood: int = 0

@export_group("Crafting Costs")
@export var raft_tile_wood_cost: int = 2
@export var wall_tile_wood_cost: int = 3
@export var ladder_tile_wood_cost: int = 4

var is_open: bool = false
var crafted_raft_tiles: int = 0
var crafted_wall_tiles: int = 0
var crafted_ladder_tiles: int = 0

@export var inventory_ui: Control

@onready var wood_label: Label = inventory_ui.get_node("TabContainer/InventoryTab/MarginContainer/VBoxContainer/WoodLabel")
@onready var raft_count_label: Label = inventory_ui.get_node("TabContainer/InventoryTab/MarginContainer/VBoxContainer/RaftCountLabel")
@onready var wall_count_label: Label = inventory_ui.get_node("TabContainer/InventoryTab/MarginContainer/VBoxContainer/WallCountLabel")
@onready var ladder_count_label: Label = inventory_ui.get_node("TabContainer/InventoryTab/MarginContainer/VBoxContainer/LadderCountLabel")

@onready var raft_craft_button: Button = inventory_ui.get_node("TabContainer/CraftingTab/MarginContainer/VBoxContainer/RaftCraftButton")
@onready var wall_craft_button: Button = inventory_ui.get_node("TabContainer/CraftingTab/MarginContainer/VBoxContainer/WallCraftButton")
@onready var ladder_craft_button: Button = inventory_ui.get_node("TabContainer/CraftingTab/MarginContainer/VBoxContainer/LadderCraftButton")

func _ready():
	if not inventory_ui:
		push_warning("InventoryManager: No Inventory UI assigned.")
		return

	raft_craft_button.pressed.connect(_craft_raft_tile)
	wall_craft_button.pressed.connect(_craft_wall_tile)
	ladder_craft_button.pressed.connect(_craft_ladder_tile)

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

	if is_open:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func add_wood(amount: int):
	if amount <= 0:
		return

	wood += amount
	resources_changed.emit("wood", wood)
	_update_ui()

func has_crafted_piece(build_type: String) -> bool:
	match build_type:
		"raft":
			return crafted_raft_tiles > 0
		"wall":
			return crafted_wall_tiles > 0
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
		"wall":
			crafted_wall_tiles -= 1
			crafted_changed.emit("wall", crafted_wall_tiles)
		"ladder":
			crafted_ladder_tiles -= 1
			crafted_changed.emit("ladder", crafted_ladder_tiles)

	_update_ui()
	return true

func _craft_raft_tile():
	if wood < raft_tile_wood_cost:
		return
	wood -= raft_tile_wood_cost
	crafted_raft_tiles += 1
	resources_changed.emit("wood", wood)
	crafted_changed.emit("raft", crafted_raft_tiles)
	_update_ui()

func _craft_wall_tile():
	if wood < wall_tile_wood_cost:
		return
	wood -= wall_tile_wood_cost
	crafted_wall_tiles += 1
	resources_changed.emit("wood", wood)
	crafted_changed.emit("wall", crafted_wall_tiles)
	_update_ui()

func _craft_ladder_tile():
	if wood < ladder_tile_wood_cost:
		return
	wood -= ladder_tile_wood_cost
	crafted_ladder_tiles += 1
	resources_changed.emit("wood", wood)
	crafted_changed.emit("ladder", crafted_ladder_tiles)
	_update_ui()

func _update_ui():
	if not inventory_ui:
		return

	wood_label.text = "Wood: %d" % wood
	raft_count_label.text = "Raft tiles: %d" % crafted_raft_tiles
	wall_count_label.text = "Wall tiles: %d" % crafted_wall_tiles
	ladder_count_label.text = "Ladder tiles: %d" % crafted_ladder_tiles

	raft_craft_button.text = "Craft Raft Tile (%d wood)" % raft_tile_wood_cost
	wall_craft_button.text = "Craft Wall Tile (%d wood)" % wall_tile_wood_cost
	ladder_craft_button.text = "Craft Ladder Tile (%d wood)" % ladder_tile_wood_cost

	raft_craft_button.disabled = wood < raft_tile_wood_cost
	wall_craft_button.disabled = wood < wall_tile_wood_cost
	ladder_craft_button.disabled = wood < ladder_tile_wood_cost
