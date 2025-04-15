extends Node2D

@export var noise_height_text: NoiseTexture2D
@export var second_noise: NoiseTexture2D
@onready var ui_layer := CanvasLayer.new()
@onready var terrain_panel := PanelContainer.new()
@onready var terrain_buttons := VBoxContainer.new()

var current_brush: String = ""
var terrain_mode: bool = false
var terrain_toggle_cooldown := 0.2
var terrain_toggle_timer := 0.0
var terrain_index_map: Dictionary = {}

var noise: FastNoiseLite
var noise_2: FastNoiseLite
var width: int = 200
var height: int = 200
@onready var tile_map = $TileMapLayer
@onready var astar = AStar2D.new()
var humans = []  # Keep track of humans

var source_id = 0  

# Church positions (to ensure only one per 100x100 area)
var churches = []
var church_check_timer := 0.0
var church_check_interval := 10.0

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
	setup_terrain_ui()
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
	
	# After world generation, try building the church for each human
	

	add_child(details_label)
	details_label.hide()  # Hide the label initially
	


func setup_terrain_ui():
	add_child(ui_layer)

	terrain_panel.visible = false
	terrain_panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	terrain_panel.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)

	terrain_buttons.alignment = BoxContainer.ALIGNMENT_BEGIN
	terrain_panel.add_child(terrain_buttons)
	ui_layer.add_child(terrain_panel)

	var idx = 1
	for terrain_name in terrain_tiles.keys():
		var button = Button.new()
		button.text = str(idx) + ". " + terrain_name.capitalize()
		button.name = terrain_name
		button.pressed.connect(func():
			current_brush = terrain_name
			print("Selected terrain:", current_brush)
		)
		terrain_buttons.add_child(button)
		terrain_index_map[idx] = terrain_name
		idx += 1

# Build the church at a specific position
# Build the church at a specific position
func build_church(pos: Vector2i):
	print("Attempting to build church at position:", pos)  # Debug print
	if can_build_church(pos):
		# Proceed with church placement
		print("Building church at position:", pos)  # Debug print

		# Place the church tile (adjust as needed)
		tile_map.set_cell(pos, source_id, terrain_tiles['grass'][0])  # Adjust tile ID if needed

		# Create and position the church sprite
		var church_sprite = Sprite2D.new()
		church_sprite.texture = preload("res://assets/buildings/church.png")
		var world_pos = tile_map.map_to_local(pos)
		church_sprite.position = world_pos
		church_sprite.z_index = 4  # Ensure it's drawn on top
		add_child(church_sprite)

		# Add the church position to the list
		churches.append(pos)
		weight_map[pos] = 0
		print("Church successfully built at position:", pos)  # Debug print
	else:
		print("Cannot build church. Conditions not met.")  # Debug print

# Function to check if a church can be built in the given area
func can_build_church(pos: Vector2i) -> bool:
	print("Checking if church can be built at position:", pos)  # Debug print

	# Check for the number of humans in the 10x10 tile range
	var human_count = 0
	var range = 5  # 5 tiles in each direction to make a 10x10 area
	for human in humans:
		var human_pos = tile_map.local_to_map(human.global_position)
		if abs(human_pos.x - pos.x) <= range and abs(human_pos.y - pos.y) <= range:
			human_count += 1

	# Debugging: Print human count in the area
	print("Human count in area for position", pos, ": ", human_count)

	# If there are more than 6 humans in the 10x10 area, check the church distance
	if human_count > 6:
		print("Sufficient humans in the area to build a church.")  # Debug print
		# Check if the new position is within 100 tiles of any existing church
		for church_pos in churches:
			if pos.distance_to(church_pos) < 100:
				print("Church is too close to another church. Distance: ", pos.distance_to(church_pos))  # Debug print
				return false  # Too close to another church
		print("Enough space for the church!")  # Debug print
		return true
	else:
		print("Not enough humans in the area to build a church.")  # Debug print
		return false


# Merge two noise sources for terrain generation
func merge_noises():
	for x in range(width):
		for y in range(height):
			noise_values.append((noise.get_noise_2d(x, y) + noise_2.get_noise_2d(x, y)) / 2)

var is_painting := false  # ← place this at the top level of your script

func _unhandled_input(event):
	if event is InputEventMouseButton:
		var mouse_pos = get_local_mouse_position()
		var cell_coords = tile_map.local_to_map(mouse_pos)

		if event.button_index == MOUSE_BUTTON_LEFT:
			is_painting = event.pressed  # true when pressed, false when released

			if event.pressed:
				if terrain_mode and current_brush != "":
					var variants = terrain_tiles[current_brush]
					var random_tile = variants[randi() % variants.size()]
					tile_map.set_cell(cell_coords, source_id, random_tile)
					weight_map[cell_coords] = tile_weights_map[current_brush]
				else:
					spawn_human(cell_coords)

		elif event.button_index == MOUSE_BUTTON_RIGHT:
			print("Right-clicked at tile:", cell_coords)
			for human in humans:
				if human.global_position == tile_map.map_to_local(cell_coords):
					show_human_stats(human)
					return
			details_label.hide()

	elif event is InputEventMouseMotion and is_painting and terrain_mode and current_brush != "":
		var cell_coords = tile_map.local_to_map(get_local_mouse_position())
		var variants = terrain_tiles[current_brush]
		var random_tile = variants[randi() % variants.size()]
		tile_map.set_cell(cell_coords, source_id, random_tile)
		weight_map[cell_coords] = tile_weights_map[current_brush]

	
var is_paused = true

func _input(event):
	if event is InputEventKey:
		if event.pressed and event.keycode == KEY_SPACE:
			is_paused = !is_paused
			print("Game is ","paused" if is_paused else "running")
		if event.keycode == KEY_QUOTELEFT and terrain_toggle_timer <= 0.0:
			terrain_mode = !terrain_mode
			terrain_toggle_timer = terrain_toggle_cooldown
			terrain_panel.visible = terrain_mode

		if terrain_mode and event.keycode >= KEY_1 and event.keycode <= KEY_9:
			var index = event.keycode - KEY_0
			if terrain_index_map.has(index):
				current_brush = terrain_index_map[index]
	

func _process(delta):
	if terrain_toggle_timer > 0.0:
		terrain_toggle_timer -= delta
	if is_paused:
		return
	

	church_check_timer += delta
	if church_check_timer >= church_check_interval:
		church_check_timer = 0.0  # Reset the timer
		for human_cell in humans:
			var human_pos = tile_map.local_to_map(human_cell.global_position)
			build_church(human_pos)

	for human_cell in humans:
		if not human_cell["is_moving"]:
			human_cell.decide_action()


		

var used_tiles = {}

# Function to spawn a human at a given position
func spawn_human(pos: Vector2i):
	var human_scene = preload("res://scenes/human_cell.tscn")
	var human = human_scene.instantiate()
	var world_pos = tile_map.map_to_local(pos)
	human.global_position = world_pos
	human.initialize(tile_map, astar, weight_map, is_paused)
	add_child(human)
	humans.append(human)
	print("✅ Spawned human at tile:", pos, " | World pos:", world_pos)

# Function to show the human's stats when clicked
func show_human_stats(human):
	# Update the label text with human stats using string interpolation
	details_label.text = "Health: " + str(human.health) + "\n Happiness: " + str(human.happiness) + "\nStamina: " + str(human.stamina) + "\n Hunger: " + str(human.hunger) + "\nAge: " + str(human.age) + "\nMax Age: " + str(human.max_age)+"\n Wood amount: "+str(human.wood_amount)+ "\nProfession: "+str(human.profession)+"\nFood Amount: "+str(human.food_amount)
	details_label.position = get_local_mouse_position() + Vector2(10, 10)  # Position the label near the mouse click
	details_label.show()  # Make the label visible


# Generate the world using noise values
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

# Function to connect hexagonal neighbors for A* pathfinding
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
