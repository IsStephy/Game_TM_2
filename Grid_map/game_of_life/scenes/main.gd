extends Node2D

@export var noise_height_text: NoiseTexture2D
@export var second_noise: NoiseTexture2D
var noise: FastNoiseLite
var noise_2: FastNoiseLite
var width: int = 500
var height: int = 500
@onready var tile_map = $TileMapLayer

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
	0.214,  # Sand
	0.364,  # Grass
	0.522,  # Mountain
	0.602,  # Flower
	0.647,  # Forest
	0.8   # Snow
]

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
			var noise_val = noise_values[index]

			# Normalize noise to range [0, 1]
			var normalized_noise = (noise_val - min_noise) / (max_noise - min_noise)

			# Assign tile type
			var tile_pos: Vector2i
			if normalized_noise < thresholds[1]:
				tile_pos = water
			elif normalized_noise < thresholds[2]:
				tile_pos = sand
			elif normalized_noise < thresholds[3]:
				var n = randi()%2 
				if n == 0:
					tile_pos = grass
				elif n == 1:
					tile_pos = mountain
				else:
					tile_pos = flower
			elif normalized_noise < thresholds[4]:
				tile_pos = mountain
			elif normalized_noise < thresholds[5]:
				tile_pos = flower
			elif normalized_noise < thresholds[6]:
				tile_pos = forest
			else:
				tile_pos = snow

			# Set tile in TileMap
			tile_map.set_cell(Vector2i(x, y), source_id, tile_pos)
			

	# Force the tilemap to refresh
	tile_map.visible = true
	tile_map.modulate = Color(1, 1, 1, 1)  # Ensure visibility

	# Move camera to center of map
