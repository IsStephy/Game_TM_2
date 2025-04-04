extends Node2D

@export var noise_height_text: NoiseTexture2D
@export var second_noise: NoiseTexture2D
var noise: FastNoiseLite
var noise_2: FastNoiseLite
var width: int = 500
var height: int = 500
@onready var tile_map = $TileMapLayer

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

			tile_map.set_cell(Vector2i(x, y), source_id, tile_pos)
			

	# Force the tilemap to refresh
	tile_map.visible = true
	tile_map.modulate = Color(1, 1, 1, 1)  # Ensure visibility

	# Move camera to center of map
	
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
