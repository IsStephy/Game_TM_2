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

# TileSet atlas coordinates
var source_id = 0  
var water = Vector2i(5, 24)
var sand = Vector2i(0, 0)
var grass = Vector2i(14, 9)
var mountain = Vector2i(17, 4)
var flower = Vector2i(19, 33)
var snow = Vector2i(2, 29)
var forest = Vector2i(11, 14)
var count = 0
# Noise data storage
var noise_values = []
var min_noise: float = INF
var max_noise: float = -INF


# Thresholds based on the image
var thresholds = [
	0.0,    # Water
	0.314,  # Sand
	0.364,  # Grass
	0.522,  # Mountain
	0.602,  # Flower
	0.647,  # Forest
	0.8   # Snow
]

#Game of life variables
var cell_states = [] # for storing current states
var next_states = [] # for storing next states

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
func merge_noises():
	for x in range(width):
		for y in range (height):
			noise_values.append((noise.get_noise_2d(x,y) + noise_2.get_noise_2d(x,y))/2)
# Step 1: Store all noise values and find min/max
func _unhandled_input(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var cell_coords = tile_map.local_to_map(get_local_mouse_position())
		
		# Check if the click is within the bounds of the grid
		if cell_coords.x >= 0 and cell_coords.x < width and cell_coords.y >= 0 and cell_coords.y < height:
			# Spawn the human cell at the clicked node
			spawn_human_cell(cell_coords)

# Function to spawn the human cell at the grid coordinates
func spawn_human_cell(pos: Vector2i):
	# Create a new sprite for the human cell
	var sprite = Sprite2D.new()
	sprite.texture = preload("res://assets/character/default.png")  # Replace with the actual path to your texture
	add_child(sprite)
	
	# Scale the sprite to make it 2 times bigger (32x32)
	sprite.scale = Vector2(2, 2)

	# Position the sprite at the correct location based on the tile coordinates
	# Convert the grid coordinates to world position using map_to_local
	sprite.position = tile_map.map_to_local(pos)
	
	# Add the sprite to the human cells list
	human_cells.append({"sprite": sprite, "pos": pos})


# Step 2: Generate world using actual min/max noise range
func generate_world():
	for x in range(width):
		for y in range(height):
			var index = x * height + y
			var base_noise = noise_values[index]
			var normalized_noise = (base_noise - min_noise) / (max_noise - min_noise)

			# Sample "feature noise" using warped coords (no extra noise objects)
			var mountain_chance = noise.get_noise_2d(x + 1000, y - 1000)
			var flower_chance = noise.get_noise_2d(x - 2000, y + 1500)
			var forest_chance = noise.get_noise_2d(x + 3000, y + 3000)

			# Biome base
			var tile_pos: Vector2i
			if normalized_noise < thresholds[1]:
				tile_pos = water
			elif normalized_noise < thresholds[2]:
				tile_pos = sand
			else:
				tile_pos = grass

				if mountain_chance > 0.25:
					tile_pos = mountain
				elif flower_chance > 0.45:
					tile_pos = flower
				elif forest_chance > 0.2:
					tile_pos = forest
				elif normalized_noise > thresholds[6]:
					tile_pos = snow
			count += 1
			tile_map.set_cell(Vector2i(x, y), source_id, tile_pos)

			# Add tile to the AStar2D graph
			var node_id = x * height + y
			astar.add_point(node_id, Vector2(x, y))

			# Connect the tile to its six neighbors (hexagonal grid adjacency)
			# Top-left, Top-right, Left, Right, Bottom-left, Bottom-right
	for x in range(width):
		for y in range(height):
			var node_id = x * height + y
			connect_hex_neighbors(x, y, node_id)

	print(count)
	# Force the tilemap to refresh
	tile_map.visible = true
	tile_map.modulate = Color(1, 1, 1, 1)  # Ensure visibility

func connect_hex_neighbors(x: int, y: int, node_id: int):
	# Directions for hexagonal adjacency (6 neighbors)
	var directions = [
		Vector2(-1, 0),  # Left
		Vector2(1, 0),   # Right
		Vector2(0, -1),  # Top-left
		Vector2(0, 1),   # Bottom-right
		Vector2(-1, 1),  # Bottom-left
		Vector2(1, -1)   # Top-right
	]
	
	# For each direction, check if the neighbor exists and connect
	for dir in directions:
		var neighbor_x = x + dir.x
		var neighbor_y = y + dir.y
		
		# Check if the neighbor is within bounds
		if neighbor_x > 0 and neighbor_x < width and neighbor_y > 0 and neighbor_y < height:
			# Calculate the neighbor's node ID
			var neighbor_id = neighbor_x * height + neighbor_y
			# Connect the current tile to the neighbor
			astar.connect_points(node_id, neighbor_id, true)

func find_path(start: Vector2i, goal: Vector2i) -> Array:
	var start_id = start.x * height + start.y
	var goal_id = goal.x * height + goal.y
	var path = astar.get_point_path(start_id, goal_id)
	return path
	
func step_game_of_life():
	next_states.clear()
	for x in range(width):
		var row = []
		for y in range(height):
			var alive_neighbors = get_alive_neighbors(x, y)
			var is_alive = cell_states[x * height + y]
			var next_state = is_alive
			if is_alive and (alive_neighbors < 2 or alive_neighbors > 3):
				next_state = false
			elif not is_alive and alive_neighbors == 3:
				next_state = true
			row.append(next_state)
		next_states.append(row)
		cell_states = next_states
	update_cells()

func get_alive_neighbors(x, y):
	var directions = [[-1, 0], [1, 0], [0, -1], [0, 1], [-1, 1], [1, -1]]
	var count = 0
	for dir in directions:
		var nx = x + dir[0]
		var ny = y + dir[1]
		if nx >= 0 and nx < width and ny >= 0 and ny < height:
			if cell_states[nx * height + ny]:
				count += 1
	return count

func update_cells():
	for x in range(width):
		for y in range(height):
			human_cells[x][y].modulate = Color(0, 1, 0) if cell_states[x * height + y] else Color(1, 0, 0)
