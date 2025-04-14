extends Node2D

@export var noise_height_text: NoiseTexture2D
@export var second_noise: NoiseTexture2D

var noise: FastNoiseLite
var noise_2: FastNoiseLite
var width: int = 200
var height: int = 200
@onready var tile_map = $TileMapLayer
@onready var astar = AStar2D.new()
var humans = []  # Keep track of humans

var source_id = 0  

# Multiple tile variants for each terrain type
var terrain_tiles = {
	"water": [Vector2i(5, 24)],
	"sand": [Vector2i(0, 17), Vector2i(1, 17), Vector2i(2, 17), Vector2i(3, 17), Vector2i(4, 17), Vector2i(0, 18), Vector2i(1, 18), Vector2i(2, 18), Vector2i(4, 19), Vector2i(4, 19), Vector2i(4, 0)],
	"grass": [Vector2i(9, 9), Vector2i(13, 10), Vector2i(11, 9),Vector2i(4, 7)],
	"mountain": [Vector2i(7, 7), Vector2i(6, 7), Vector2i(4, 14), Vector2i(10, 14), Vector2i(9, 14), Vector2i(11, 14)],
	"flower": [Vector2i(5, 30), Vector2i(7, 30), Vector2i(8, 30), Vector2i(9, 30), Vector2i(17, 31), Vector2i(17, 31), Vector2i(14, 33), Vector2i(19, 33)],
	"snow": [Vector2i(2, 29)],
	"forest": [Vector2i(4, 5), Vector2i(3, 5), Vector2i(0, 7), Vector2i(15, 8), Vector2i(17, 4)]
}

var noise_values = []
var min_noise: float = INF
var max_noise: float = -INF
var weight_map = {}

var tile_weights_map = {
	"water": 2.5,
	"sand": 2.5,
	"grass": 1,
	"forest": 2,
	"mountain": 3,
	"snow": 3.5,
	"flower": 1.5
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
	details_label.hide()  # Hide the label initially

func merge_noises():
	for x in range(width):
		for y in range(height):
			noise_values.append((noise.get_noise_2d(x, y) + noise_2.get_noise_2d(x, y)) / 2)

func _unhandled_input(event):
	if event is InputEventMouseButton and event.pressed:
		var mouse_pos = get_local_mouse_position()
		var cell_coords = tile_map.local_to_map(mouse_pos)
		
		if event.button_index == MOUSE_BUTTON_LEFT:
			print("Clicked at tile:", cell_coords)
			spawn_human(cell_coords)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			print("Right-clicked at tile:", cell_coords)
			for human in humans:
				if human.global_position == tile_map.map_to_local(cell_coords):
					show_human_stats(human)
					return
			details_label.hide()

var is_paused = true

func _input(event):
	if event is InputEventKey:
		if event.pressed and event.keycode == KEY_SPACE:
			is_paused = !is_paused
			print("Game is ","paused" if is_paused else "running")

func _process(delta):
	if is_paused:
		return

	for human_cell in humans:
		if not human_cell["is_moving"]:
			human_cell.decide_action()

var used_tiles = {}

func spawn_human(pos: Vector2i):
	var human_scene = preload("res://scenes/human_cell.tscn")
	var human = human_scene.instantiate()
	var world_pos = tile_map.map_to_local(pos)
	human.global_position = world_pos
	human.initialize(tile_map, astar, weight_map, is_paused)
	add_child(human)
	humans.append(human)
	print("✅ Spawned human at tile:", pos, " | World pos:", world_pos)

func show_human_stats(human):

	# Update the label text with human stats using string interpolation
	details_label.text = "Health: " + str(human.health) + "\n Happiness: " + str(human.happiness) + "\nStamina: " + str(human.stamina) + "\n Hunger: " + str(human.hunger) + "\nAge: " + str(human.age) + "\nMax Age: " + str(human.max_age)+"\n Wood amount: "+str(human.wood_amount)
	details_label.position = get_local_mouse_position() + Vector2(10, 10)  # Position the label near the mouse click
	details_label.show()  # Make the label visible


func generate_world():
	for x in range(width):
		for y in range(height):
			var index = x * height + y
			var base_noise = noise_values[index]
			var normalized_noise = (base_noise - min_noise) / (max_noise - min_noise)
			var mountain_chance = noise.get_noise_2d(x + 1000, y - 1000)
			var flower_chance = noise.get_noise_2d(x - 2000, y + 1500)
			var forest_chance = noise.get_noise_2d(x + 3000, y + 3000)

			var tile_type = "grass"
			var weight = 1

			if normalized_noise < thresholds[1]:
				tile_type = "water"
				weight = tile_weights_map[tile_type]
			elif normalized_noise < thresholds[2]:
				tile_type = "sand"
				weight = tile_weights_map[tile_type]
			else:
				tile_type = "grass"
				weight = tile_weights_map[tile_type]
				if mountain_chance > 0.25:
					tile_type = "mountain"
					weight = tile_weights_map[tile_type]
				elif flower_chance > 0.65:
					tile_type = "flower"
					weight = tile_weights_map[tile_type]
				elif forest_chance > 0.2:
					tile_type = "forest"
					weight = tile_weights_map[tile_type]
				elif normalized_noise > thresholds[6]:
					tile_type = "snow"
					weight = tile_weights_map[tile_type]


			var pos = Vector2i(x, y)
			weight_map[pos] = weight
			var variants = terrain_tiles[tile_type]
			var random_tile = variants[randi() % variants.size()]
			tile_map.set_cell(pos, source_id, random_tile)
			var node_id = x * height + y
			astar.add_point(node_id, Vector2(x, y), weight)

	for x in range(width):
		for y in range(height):
			var node_id = x * height + y
			connect_hex_neighbors(x, y, node_id)

func connect_hex_neighbors(x: int, y: int, node_id: int):
	var directions_1 = [
		Vector2(-1, 0), Vector2(0 , -1), Vector2(1, 0),
		Vector2(-1, 1), Vector2(0, 1), Vector2(1, 1)
	]
	var directions_2 = [
		Vector2(-1, -1), Vector2(0 , -1), Vector2(1, -1),
		Vector2(-1, 0), Vector2(0, 1), Vector2(0, 1)
	]
	if x % 2 == 1: 
		for dir in directions_1:
			var nx = x + dir.x
			var ny = y + dir.y
			if nx >= 0 and nx < width and ny >= 0 and ny < height:
				var neighbor_id = nx * height + ny
				astar.connect_points(node_id, neighbor_id, true)
	else:
		for dir in directions_2:
			var nx = x + dir.x
			var ny = y + dir.y
			if nx >= 0 and nx < width and ny >= 0 and ny < height:
				var neighbor_id = nx * height + ny
				astar.connect_points(node_id, neighbor_id, true)
