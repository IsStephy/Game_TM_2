extends Node2D

@export var noise_height_text: NoiseTexture2D
@export var second_noise: NoiseTexture2D

var noise: FastNoiseLite
var noise_2: FastNoiseLite
var width: int = 200
var height: int = 200
@onready var tile_map = $TileMapLayer
@onready var astar = AStar2D.new()
@onready var human_cells = []

var source_id = 0  
var water = Vector2i(5, 24)
var sand = Vector2i(0, 0)
var grass = Vector2i(14, 9)
var mountain = Vector2i(17, 4)
var flower = Vector2i(19, 33)
var snow = Vector2i(2, 29)
var forest = Vector2i(11, 14)

var count = 0
var noise_values = []
var min_noise: float = INF
var max_noise: float = -INF
var tile_weights = {}

var tile_weights_map = {
	"water": 3,
	"sand": 1,
	"grass": 1,
	"forest": 2,
	"mountain": 3,
	"snow": 3,
	"flower": 1
}

var thresholds = [
	0.0,
	0.314,
	0.364,
	0.522,
	0.602,
	0.647,
	0.8
]

var cell_states = []
var next_states = []

@onready var details_label = Label.new()

var weight = 0
var weight_map = {}

# Movement control
var is_moving = false
var current_path = []
var move_index = 0

func _ready():
	if noise_height_text and noise_height_text.noise:
		noise_height_text.noise.seed = randi()
		second_noise.noise.seed = randi()
		noise = noise_height_text.noise
		noise_2 = second_noise.noise
		print(noise_height_text.noise.seed)
		merge_noises()
		min_noise = noise_values.min()
		max_noise = noise_values.max()
		generate_world()
	else:
		push_error("NoiseTexture2D is not set correctly!")

	add_child(details_label)
	details_label.hide()

func merge_noises():
	for x in range(width):
		for y in range(height):
			noise_values.append((noise.get_noise_2d(x, y) + noise_2.get_noise_2d(x, y)) / 2)

func _unhandled_input(event):
	if event is InputEventMouseButton and event.pressed:
		var cell_coords = tile_map.local_to_map(get_local_mouse_position())
		if event.button_index == MOUSE_BUTTON_LEFT:
			if cell_coords.x >= 0 and cell_coords.x < width and cell_coords.y >= 0 and cell_coords.y < height:
				spawn_human_cell(cell_coords)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			var clicked_cell = get_clicked_human_cell(cell_coords)
			if clicked_cell:
				display_human_cell_details(clicked_cell)

func get_clicked_human_cell(coords: Vector2i) -> Dictionary:
	for human_cell in human_cells:
		if Vector2i(human_cell["pos"]) == coords:
			return human_cell
	return human_cells[0]

func spawn_human_cell(pos: Vector2i):
	var sprite = Sprite2D.new()
	sprite.texture = preload("res://assets/character/default.png")
	add_child(sprite)
	sprite.scale = Vector2(2, 2)
	sprite.position = tile_map.map_to_local(pos)

	var human_cell = {
		"sprite": sprite,
		"pos": pos,
		"food": 60,
		"happiness": 60,
		"stamina": 100,
		"is_moving": false,
		"path": [],
		"move_index": 0
	}
	human_cells.append(human_cell)

func generate_world():
	for x in range(width):
		for y in range(height):
			var index = x * height + y
			var base_noise = noise_values[index]
			var normalized_noise = (base_noise - min_noise) / (max_noise - min_noise)
			var mountain_chance = noise.get_noise_2d(x + 1000, y - 1000)
			var flower_chance = noise.get_noise_2d(x - 2000, y + 1500)
			var forest_chance = noise.get_noise_2d(x + 3000, y + 3000)

			var tile_pos: Vector2i
			if normalized_noise < thresholds[1]:
				tile_pos = water
				weight = 2
			elif normalized_noise < thresholds[2]:
				tile_pos = sand
				weight = 1
			else:
				tile_pos = grass
				weight = 1
				if mountain_chance > 0.25:
					tile_pos = mountain
					weight = 3
				elif flower_chance > 0.45:
					tile_pos = flower
					weight = 1
				elif forest_chance > 0.2:
					tile_pos = forest
					weight = 2
				elif normalized_noise > thresholds[6]:
					tile_pos = snow
					weight = 3

			weight_map[Vector2i(x, y)] = weight
			tile_map.set_cell(Vector2i(x, y), source_id, tile_pos)
			var node_id = x * height + y
			astar.add_point(node_id, Vector2(x, y), weight)

	for x in range(width):
		for y in range(height):
			var node_id = x * height + y
			connect_hex_neighbors(x, y, node_id)

func connect_hex_neighbors(x: int, y: int, node_id: int):
	var directions = [
		Vector2(-1, 0),
		Vector2(-2, 0),
		Vector2(-1, 1),
		Vector2(1, 1),
		Vector2(0, 2),
		Vector2(1, 0)
	]
	for dir in directions:
		var neighbor_x = x + dir.x
		var neighbor_y = y + dir.y
		if neighbor_x >= 0 and neighbor_x < width and neighbor_y >= 0 and neighbor_y < height:
			var neighbor_id = neighbor_x * height + neighbor_y
			astar.connect_points(node_id, neighbor_id, true)

func find_path(start: Vector2i, goal: Vector2i) -> Array:
	var start_id = start.x * height + start.y
	var goal_id = goal.x * height + goal.y
	return astar.get_point_path(start_id, goal_id)

func display_human_cell_details(human_cell: Dictionary):
	details_label.text = "Food: %d\nHappiness: %d\nStamina: %d" % [
		human_cell["food"], 
		human_cell["happiness"], 
		human_cell["stamina"]
	]
	details_label.position = human_cell["sprite"].position + Vector2(0, -50)
	details_label.show()

func _process(_delta):
	for human_cell in human_cells:
		if not human_cell["is_moving"] and human_cell["stamina"] > 0:
			var start_pos = human_cell["pos"]
			var goal_pos = Vector2i(10, 10)  # You can change this goal dynamically
			var path = find_path(start_pos, goal_pos)
			if path.size() > 0:
				human_cell["path"] = path
				human_cell["move_index"] = 0
				human_cell["is_moving"] = true
				move_along_path(human_cell)

func move_along_path(cell: Dictionary) -> void:
	var index = cell["move_index"]
	var path = cell["path"]

	if index >= path.size():
		cell["is_moving"] = false
		return

	var next_position = Vector2i(path[index])
	var current_tile_weight = weight_map.get(next_position, 1)
	cell["stamina"] -= current_tile_weight

	if cell["stamina"] <= 0:
		print("A human ran out of stamina!")
		cell["is_moving"] = false
		return

	cell["pos"] = next_position
	cell["sprite"].position = tile_map.map_to_local(next_position)
	cell["move_index"] += 1

	await get_tree().create_timer(1.0).timeout
	move_along_path(cell)
