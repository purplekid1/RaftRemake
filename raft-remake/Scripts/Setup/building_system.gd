extends Node3D

enum BuildType { TILE, WALL, LADDER, BREAK }
var current_mode: BuildType = BuildType.TILE
var is_build_mode: bool = false

@export_group("Scenes")
@export var raft_tile_scene: PackedScene
@export var wall_scene: PackedScene
@export var ladder_scene: PackedScene

@export_group("Settings")
@export var tile_size: float = 2.0
@export var wall_height: float = 1.5
@export var max_place_distance: float = 7.0
@export var ladder_offset: float = 0.1

@onready var player: CharacterBody3D = get_node("../Player")
@onready var camera: Camera3D = get_node("../Player/Head/Camera3D")
@onready var inventory_manager: InventoryManager = get_node("../Player/CanvasLayer")
@onready var raft: Node3D = get_node("../Raft")

var raft_tiles: Dictionary = {}
var edge_structures: Dictionary = {}
var ghost_tile: Node3D = null
var last_highlighted_mesh: MeshInstance3D = null

var current_grid_pos_3d: Vector3i
var current_place_pos: Vector3 = Vector3.ZERO
var ghost_rotation: float = 0.0
var can_place: bool = false

func _ready():
	_setup_ghost()
	_place_starting_tile(Vector3i(roundi(player.global_position.x / tile_size), 0, roundi(player.global_position.z / tile_size)))

func _process(_delta):
	if inventory_manager.is_open:
		can_place = false
		_update_ghost_visibility()
		_update_build_info()
		return

	_handle_mode_input()
	_update_ghost()
	_update_build_info()

	if not is_build_mode:
		return

	if Input.is_action_just_pressed("interact"):
		if current_mode == BuildType.BREAK:
			_break_structure()
		elif can_place:
			match current_mode:
				BuildType.TILE:
					if inventory_manager.consume_crafted_piece("raft"):
						_place_tile(current_grid_pos_3d)
				BuildType.WALL:
					if inventory_manager.consume_crafted_piece("wall"):
						_place_structure(current_place_pos, ghost_rotation)
				BuildType.LADDER:
					if inventory_manager.consume_crafted_piece("ladder"):
						_place_structure(current_place_pos, ghost_rotation)

func _handle_mode_input():
	if Input.is_key_pressed(KEY_1): _switch_mode(BuildType.TILE)
	if Input.is_key_pressed(KEY_2): _switch_mode(BuildType.WALL)
	if Input.is_key_pressed(KEY_3): _switch_mode(BuildType.LADDER)
	if Input.is_key_pressed(KEY_4): _switch_mode(BuildType.BREAK)

	if Input.is_action_just_pressed("build_mode"):
		is_build_mode = not is_build_mode
		if not is_build_mode:
			_highlight_for_break(null)
		_update_ghost_visibility()

func _switch_mode(new_mode):
	if current_mode == new_mode:
		return
	if current_mode == BuildType.BREAK:
		_highlight_for_break(null)
	current_mode = new_mode
	if ghost_tile:
		ghost_tile.queue_free()
	_setup_ghost()
	_update_ghost_visibility()

func _setup_ghost():
	if current_mode == BuildType.BREAK:
		ghost_tile = Node3D.new()
		add_child(ghost_tile)
		return

	var scene = raft_tile_scene
	if current_mode == BuildType.WALL: scene = wall_scene
	elif current_mode == BuildType.LADDER: scene = ladder_scene

	ghost_tile = scene.instantiate()
	add_child(ghost_tile)
	for child in ghost_tile.find_children("*", "CollisionShape3D"): child.disabled = true

	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 1.0, 0.2, 0.4)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	for child in ghost_tile.find_children("*", "MeshInstance3D"):
		child.material_override = mat

func _update_ghost_visibility():
	if not ghost_tile:
		return
	ghost_tile.visible = is_build_mode and current_mode != BuildType.BREAK

func _update_ghost():
	if not is_build_mode:
		can_place = false
		_update_ghost_visibility()
		_highlight_for_break(null)
		return

	var origin = camera.global_position
	var direction = -camera.global_transform.basis.z
	var end = origin + direction * max_place_distance

	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(origin, end)
	query.exclude = [player.get_rid()]
	var result = space_state.intersect_ray(query)

	if current_mode == BuildType.BREAK:
		if result:
			_highlight_for_break(result.collider)
		else:
			_highlight_for_break(null)
		can_place = result.size() > 0
		_update_ghost_visibility()
		return

	_highlight_for_break(null)
	var hit_pos: Vector3
	var hit_normal: Vector3 = Vector3.UP
	var is_valid_hit: bool = false

	if result:
		hit_pos = result.position
		hit_normal = result.normal
		is_valid_hit = true
	elif direction.y < -0.001:
		var t = (0.0 - origin.y) / direction.y
		hit_pos = origin + direction * t
		if origin.distance_to(hit_pos) <= max_place_distance:
			is_valid_hit = true

	ghost_tile.visible = is_valid_hit and is_build_mode
	if not is_valid_hit:
		can_place = false
		return

	if current_mode == BuildType.TILE:
		var biased_pos = hit_pos + (hit_normal * 0.1)
		current_grid_pos_3d = Vector3i(roundi(biased_pos.x / tile_size), roundi(biased_pos.y / wall_height), roundi(biased_pos.z / tile_size))
		current_place_pos = Vector3(current_grid_pos_3d.x * tile_size, current_grid_pos_3d.y * wall_height, current_grid_pos_3d.z * tile_size)
		ghost_rotation = 0.0
		can_place = _can_place_tile_3d(current_grid_pos_3d) and inventory_manager.has_crafted_piece("raft")
	elif current_mode == BuildType.WALL:
		_calculate_edge_snap(hit_pos)
		can_place = _can_place_on_edge(current_place_pos) and inventory_manager.has_crafted_piece("wall")
	else:
		_calculate_edge_snap(hit_pos)
		can_place = _can_place_on_edge(current_place_pos) and inventory_manager.has_crafted_piece("ladder")

	ghost_tile.global_position = current_place_pos
	ghost_tile.rotation.y = ghost_rotation
	_update_ghost_color()

func _update_build_info():
	if inventory_manager.is_open:
		build_info_label.visible = false
		return

	if not is_build_mode:
		build_info_label.visible = true
		build_info_label.text = "Press B to enter Build Mode"
		return

	build_info_label.visible = true
	var mode_text = ""
	match current_mode:
		BuildType.TILE:
			mode_text = inventory_manager.get_build_mode_hint("raft")
		BuildType.WALL:
			mode_text = inventory_manager.get_build_mode_hint("wall")
		BuildType.LADDER:
			mode_text = inventory_manager.get_build_mode_hint("ladder")
		BuildType.BREAK:
			mode_text = inventory_manager.get_build_mode_hint("break")
	build_info_label.text = "Build Mode [1:Raft 2:Wall 3:Ladder 4:Break]\n%s" % mode_text

func _calculate_edge_snap(hit_pos: Vector3):
	var snapped_x = round(hit_pos.x / tile_size) * tile_size
	var snapped_z = round(hit_pos.z / tile_size) * tile_size
	var snapped_y = round(hit_pos.y / wall_height) * wall_height

	var diff_x = hit_pos.x - snapped_x
	var diff_z = hit_pos.z - snapped_z
	var offset = (tile_size / 2.0) - (ladder_offset if current_mode == BuildType.LADDER else 0.0)

	if abs(diff_x) > abs(diff_z):
		current_place_pos = Vector3(snapped_x + (sign(diff_x) * offset), snapped_y, snapped_z)
		ghost_rotation = PI / 2.0
	else:
		current_place_pos = Vector3(snapped_x, snapped_y, snapped_z + (sign(diff_z) * offset))
		ghost_rotation = 0.0

func _place_starting_tile(grid_pos: Vector3i):
	if raft_tiles.has(grid_pos):
		return
	var tile = raft_tile_scene.instantiate()
	raft.add_child(tile)
	tile.global_position = Vector3(grid_pos.x * tile_size, grid_pos.y * wall_height, grid_pos.z * tile_size)
	raft_tiles[grid_pos] = tile

func _place_tile(grid_pos: Vector3i):
	if raft_tiles.has(grid_pos):
		return
	var tile = raft_tile_scene.instantiate()
	raft.add_child(tile)
	tile.global_position = Vector3(grid_pos.x * tile_size, grid_pos.y * wall_height, grid_pos.z * tile_size)
	raft_tiles[grid_pos] = tile

func _place_structure(pos: Vector3, rot: float):
	var key = _generate_edge_key(pos, rot)
	if edge_structures.has(key):
		return
	var item = (wall_scene if current_mode == BuildType.WALL else ladder_scene).instantiate()
	raft.add_child(item)
	item.global_position = pos
	item.rotation.y = rot
	edge_structures[key] = item

func _break_structure():
	var origin = camera.global_position
	var end = origin + (-camera.global_transform.basis.z * max_place_distance)
	var query = PhysicsRayQueryParameters3D.create(origin, end)
	query.exclude = [player.get_rid()]
	var result = get_world_3d().direct_space_state.intersect_ray(query)

	if result:
		var hit = result.collider
		for k in raft_tiles.keys():
			if raft_tiles[k] == hit or raft_tiles[k] == hit.get_parent():
				raft_tiles[k].queue_free(); raft_tiles.erase(k); return
		for k in edge_structures.keys():
			if edge_structures[k] == hit or edge_structures[k] == hit.get_parent():
				edge_structures[k].queue_free(); edge_structures.erase(k); return

func _highlight_for_break(target_node: Node):
	if last_highlighted_mesh and is_instance_valid(last_highlighted_mesh):
		last_highlighted_mesh.material_overlay = null

	if target_node:
		var mesh_instance: MeshInstance3D = null
		if target_node is MeshInstance3D:
			mesh_instance = target_node
		else:
			var meshes = target_node.find_children("*", "MeshInstance3D", true, false)
			if meshes.size() > 0:
				mesh_instance = meshes[0]

		if mesh_instance:
			var mat = StandardMaterial3D.new()
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			mat.albedo_color = Color(1.0, 0.5, 0.0, 0.4)
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.grow = true
			mat.grow_amount = 0.02
			mesh_instance.material_overlay = mat
			last_highlighted_mesh = mesh_instance

func _can_place_tile_3d(grid_pos: Vector3i) -> bool:
	if raft_tiles.has(grid_pos): return false
	if grid_pos.y == 0:
		if raft_tiles.is_empty(): return true
		for off in [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1)]:
			if raft_tiles.has(grid_pos + off): return true
		return false

	var world_center = Vector3(grid_pos.x * tile_size, grid_pos.y * wall_height, grid_pos.z * tile_size)
	var supported = false
	for e in [{"p": Vector3(0.5, 0, 0), "r": PI / 2}, {"p": Vector3(-0.5, 0, 0), "r": PI / 2}, {"p": Vector3(0, 0, 0.5), "r": 0}, {"p": Vector3(0, 0, -0.5), "r": 0}]:
		var key = _generate_edge_key((world_center + e.p * tile_size) - Vector3(0, wall_height, 0), e.r)
		if edge_structures.has(key):
			if "Ladder" in edge_structures[key].name: return false
			supported = true
	return supported

func _can_place_on_edge(pos: Vector3) -> bool:
	var gy = roundi(pos.y / wall_height)

	var has_floor = false
	for off in [Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 0, -1)]:
		var check_grid = Vector3i(roundi((pos.x + off.x * (tile_size / 2)) / tile_size), gy, roundi((pos.z + off.z * (tile_size / 2)) / tile_size))
		if raft_tiles.has(check_grid):
			has_floor = true
			break

	var has_support_wall = false
	if pos.y > 0:
		var wall_below_pos = pos - Vector3(0, wall_height, 0)
		var key_below = _generate_edge_key(wall_below_pos, ghost_rotation)
		if edge_structures.has(key_below):
			has_support_wall = true

	return (has_floor or has_support_wall) and not edge_structures.has(_generate_edge_key(pos, ghost_rotation))

func _generate_edge_key(pos: Vector3, rot: float) -> String:
	return str(pos.snapped(Vector3(0.1, 0.1, 0.1))) + "_" + str(round(rot))

func _update_ghost_color():
	var color = Color(0.2, 1.0, 0.2, 0.4) if can_place else Color(1.0, 0.2, 0.2, 0.4)
	for child in ghost_tile.find_children("*", "MeshInstance3D"):
		child.material_override.albedo_color = color
