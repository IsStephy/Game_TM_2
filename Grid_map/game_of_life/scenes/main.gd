extends Node2D

@export var noise_height_text: NoiseTexture2D
@export var second_noise: NoiseTexture2D

var noise: FastNoiseLite
var noise_2: FastNoiseLite
var width: int = 200
var height: int = 200
@onready var tile_map = $TileMapLayer
@onready var astar = AStar2D.new()
var humans = []

var source_id = 0  
var water = Vector2i(5, 24)
var sand = Vector2i(0, 0)
var grass = Vector2i(14, 9)
var mountain = Vector2i(17, 4)
var flower = Vector2i(19, 33)
var snow = Vector2i(2, 29)
var forest = Vector2i(11, 14)

var noise_values = []
var min_noise: float = INF
var max_noise: float = -INF
var weight_map = {}

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
	0.0, 0.314, 0.364, 0.522, 0.602, 0.647, 0.8
]

@onready var details_label = Label.new()

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
		if event.button_index == MOUSE_BUTTON_LEFT:
			var mouse_pos = get_local_mouse_position()
			var cell_coords = tile_map.local_to_map(mouse_pos)
			print("Clicked at tile:", cell_coords)
			spawn_human(cell_coords)


var is_paused = false  # Flag to track pause state

func _input(event):
	if event is InputEventKey:
		if event.pressed and event.keycode == KEY_SPACE:
			is_paused = !is_paused  
			print("Game is ","paused" if is_paused else "runing")



func _process(delta):
	if is_paused:
		return  

	# All your normal processing here...
	for human_cell in humans:
		if not human_cell["is_moving"] and human_cell["stamina"] > 0:
			human_cell.decide_action()


var used_tiles = {}

# Add the is_paused flag to each human's initialization
func spawn_human(pos: Vector2i):
	var human_scene = preload("res://scenes/human_cell.tscn")
	var human = human_scene.instantiate()  # Create a new instance!

	var world_pos = tile_map.map_to_local(pos)
	human.global_position = world_pos

	human.initialize(tile_map, astar, weight_map, is_paused)  # Pass is_paused to each human
	add_child(human)

	print("✅ Spawned human at tile:", pos, " | World pos:", world_pos)
	humans.append(human)



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
			var weight = 1

			if normalized_noise < thresholds[1]:
				tile_pos = water
				weight = 3
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

			var tile = Vector2i(x, y)
			weight_map[tile] = weight
			tile_map.set_cell(tile, source_id, tile_pos)
			var node_id = x * height + y
			astar.add_point(node_id, Vector2(x, y), weight)

	for x in range(width):
		for y in range(height):
			var node_id = x * height + y
			connect_hex_neighbors(x, y, node_id)

func connect_hex_neighbors(x: int, y: int, node_id: int):
	var directions = [
		Vector2(-1, 0), Vector2(-2, 0), Vector2(-1, 1),
		Vector2(1, 1), Vector2(0, 2), Vector2(1, 0)
	]
	for dir in directions:
		var nx = x + dir.x
		var ny = y + dir.y
		if nx >= 0 and nx < width and ny >= 0 and ny < height:
			var neighbor_id = nx * height + ny
			astar.connect_points(node_id, neighbor_id, true)
