extends Node2D

@export var noise_height_text: NoiseTexture2D
@export var second_noise: NoiseTexture2D
@onready var ui_layer := CanvasLayer.new()
@onready var terrain_panel := PanelContainer.new()
@onready var terrain_buttons := VBoxContainer.new()
@onready var camera = $CharacterBody2D/Camera2D
@onready var tile_map = $TileMapLayer
@onready var astar = AStar2D.new()
@onready var reset_button = $CanvasLayer/ResetBtn
@onready var info_button = $CanvasLayer/InfoBtn

var current_brush: String = ""
var terrain_mode: bool = false
var terrain_toggle_cooldown := 0.2
var terrain_toggle_timer := 0.0
var terrain_index_map: Dictionary = {}
var flower_decay_timer := 0.0
var flower_life_queue := [] 
const FLOWER_DECAY_INTERVAL := 15.0 
const FLOWER_LIFESPAN := 25.0

var noise: FastNoiseLite
var noise_2: FastNoiseLite
var width: int = 200
var height: int = 200
var brush_radius := 1 
var humans = [] 

var source_id = 0  

var churches = []
var church_check_timer := 0.0
var church_check_interval := 10.0

var houses = []
var house_sprites = []
var house_count = 0

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
	humans = []
	churches = []
	houses = []
	house_sprites = []
	house_count = 0
	
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
		
	add_child(details_label)
	details_label.hide()
	
	camera.make_current()
	setup_camera_limits()
	camera.zoom = Vector2(2, 2)
	camera.limit_left = 1
	camera.limit_top = 1

	var tile_size = tile_map.tile_set.tile_size
	var map_rect = tile_map.get_used_rect()
	var map_size = map_rect.size * tile_size
	var center_pos = tile_map.map_to_local(Vector2i(width / 2, height / 2))
	$CharacterBody2D.global_position = center_pos
	camera.limit_right = map_size.x - 1
	camera.limit_bottom = map_size.y - 1

	camera.make_current()
	
	reset_button.pressed.connect(reset_simulation)
	info_button.pressed.connect(show_info_popup)
	
func setup_camera_limits():
	var tile_size: Vector2i = tile_map.tile_set.tile_size  
	var used_rect: Rect2i = tile_map.get_used_rect()
	var map_tiles_x = used_rect.size.x
	var map_tiles_y = used_rect.size.y

	var total_map_width = (map_tiles_x + 0.5) * tile_size.x
	var total_map_height = (map_tiles_y * 0.75 + 0.25) * tile_size.y 

	var viewport_size = get_viewport().get_visible_rect().size

	var min_zoom_x = viewport_size.x / total_map_width
	var min_zoom_y = viewport_size.y / total_map_height
	var min_zoom = max(min_zoom_x, min_zoom_y)

	var max_zoom = 2.0 

	camera.zoom = Vector2(min_zoom + 0.1, min_zoom + 0.1)
	camera.set_meta("min_zoom", min_zoom)
	camera.set_meta("max_zoom", max_zoom)

	var margin_x = tile_size.x
	var margin_y = tile_size.y

	camera.limit_left = 0 + margin_x
	camera.limit_top = 0 + margin_y
	camera.limit_right = int(total_map_width) - margin_x
	camera.limit_bottom = int(total_map_height) - margin_y


	


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
	
		# Create brush size selector
	var brush_label = Label.new()
	brush_label.text = "Brush Size:"
	terrain_buttons.add_child(brush_label)

	var brush_size_selector = OptionButton.new()
	for i in range(1, 11):
		brush_size_selector.add_item(str(i), i)

	# Set default brush size
	brush_size_selector.selected = 0
	brush_radius = 1  # Ensure this exists at the top of your script

	# Connect signal to update brush_radius
	brush_size_selector.item_selected.connect(func(index):
		brush_radius = brush_size_selector.get_item_id(index)
		print("Brush radius set to:", brush_radius)
	)

	terrain_buttons.add_child(brush_size_selector)



func paint_brush(center: Vector2i):
	for dx in range(-brush_radius + 1, brush_radius):
		for dy in range(-brush_radius + 1, brush_radius):
			var pos = center + Vector2i(dx, dy)
			if pos.x >= 0 and pos.x < width and pos.y >= 0 and pos.y < height:
				var variants = terrain_tiles[current_brush]
				var random_tile = variants[randi() % variants.size()]
				tile_map.set_cell(pos, source_id, random_tile)
				weight_map[pos] = tile_weights_map[current_brush]


# Add this function to handle removing humans from the array
func remove_human(human):
	if humans.has(human):
		humans.erase(human)
		print("Human removed from tracking array")
# Build the church at a specific position
func build_church(pos: Vector2i):
	print("Attempting to build church at position:", pos) 
	if can_build_church(pos):
		print("Building church at position:", pos)

		tile_map.set_cell(pos, source_id, terrain_tiles['grass'][0]) 

		var church_sprite = Sprite2D.new()
		church_sprite.texture = preload("res://assets/buildings/church.png")
		var world_pos = tile_map.map_to_local(pos)
		church_sprite.position = world_pos
		church_sprite.z_index = 4 
		add_child(church_sprite)

		churches.append(pos)
		weight_map[pos] = 0
		print("Church successfully built at position:", pos)  
	else:
		print("Cannot build church. Conditions not met.") 

func can_build_church(pos: Vector2i) -> bool:
	print("Checking if church can be built at position:", pos) 

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
					paint_brush(cell_coords)
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
		var center = tile_map.local_to_map(get_local_mouse_position())

		for dx in range(-brush_radius, brush_radius + 1):
			for dy in range(-brush_radius, brush_radius + 1):
				var offset = Vector2i(dx, dy)
				var target = center + offset
				if tile_map.get_cell_source_id(target) != -1:
					var variants = terrain_tiles[current_brush]
					var random_tile = variants[randi() % variants.size()]
					tile_map.set_cell(target, source_id, random_tile)
					weight_map[target] = tile_weights_map[current_brush]


	
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
				
		if event.pressed and event.keycode == KEY_T:
			var half_count = humans.size() / 2
			print("Removing half the human population: ", int(half_count), " humans")

			for i in range(int(half_count)):
				var human = humans.pop_back()
				if human:
					human.queue_free()
	
func withering_flowers(delta):
	if is_paused:
		return

	var to_remove := []
	for flower in flower_life_queue:
		flower.age += delta
		if flower.age >= flower.decay_time:
			var pos = flower.pos
			if weight_map.has(pos) and weight_map[pos] == 1.5:
				var grass_variants = terrain_tiles["grass"]
				var random_grass = grass_variants[randi() % grass_variants.size()]
				tile_map.set_cell(pos, source_id, random_grass)
				weight_map[pos] = 1
				to_remove.append(flower)

	for f in to_remove:
		flower_life_queue.erase(f)


func update_flower_decay(delta):
	var updated_queue = []
	for flower_data in flower_life_queue:
		flower_data["age"] += delta
		if flower_data["age"] >= FLOWER_LIFESPAN:
			var pos = flower_data["pos"]
			if weight_map.has(pos) and weight_map[pos] == 1.5:
				tile_map.set_cell(pos, source_id, terrain_tiles["grass"].pick_random())
				weight_map[pos] = 1
				print("💐 A flower has withered at ", pos)
		else:
			updated_queue.append(flower_data)
	flower_life_queue = updated_queue


func spread_flowers():
	for pos in weight_map.keys():
		if weight_map[pos] == 1.5:
			for offset in [
				Vector2i(1, 0), Vector2i(-1, 0),
				Vector2i(0, 1), Vector2i(0, -1)
			]:
				var neighbor = pos + offset
				if weight_map.has(neighbor) and weight_map[neighbor] == 1:
					if randf() < 0.001:
						var random_tile = terrain_tiles["flower"].pick_random()
						tile_map.set_cell(neighbor, source_id, random_tile)
						weight_map[neighbor] = 1.5
						flower_life_queue.append({
							"pos": pos,
							"age": 0.0,
							"decay_time": randf_range(10.0, 25.0) 
						})
						print("🌸 A new flower grew at ", neighbor)


func regrow_forest():
	if is_paused:
		return

	var directions = [
		Vector2i(1, 0), Vector2i(-1, 0),
		Vector2i(0, 1), Vector2i(0, -1),
		Vector2i(1, 1), Vector2i(-1, -1),
		Vector2i(1, -1), Vector2i(-1, 1)
	]

	for pos in weight_map.keys():
		if weight_map[pos] == 1 and randf() < 0.0005: 
			var has_forest_neighbor := false
			for offset in directions:
				var neighbor = pos + offset
				if weight_map.has(neighbor) and weight_map[neighbor] == 2:
					has_forest_neighbor = true
					break

			if has_forest_neighbor:
				tile_map.set_cell(pos, source_id, terrain_tiles["forest"].pick_random())
				weight_map[pos] = 2
				print("🌲 Forest regrew at ", pos)




func _process(delta):
	if not is_paused:
		withering_flowers(delta)
		spread_flowers()
		regrow_forest()
		update_flower_decay(delta)
		
	var tile_size = tile_map.tile_set.tile_size
	var used_rect = tile_map.get_used_rect()
	var map_pixel_size = used_rect.size * tile_size
	var screen_size = get_viewport().size

	if terrain_toggle_timer > 0.0:
		terrain_toggle_timer -= delta

	var min_zoom = camera.get_meta("min_zoom")
	var max_zoom = camera.get_meta("max_zoom")
	camera.zoom.x = clamp(camera.zoom.x, min_zoom, max_zoom)
	camera.zoom.y = clamp(camera.zoom.y, min_zoom, max_zoom)
	if is_paused:
		return
	print(len(humans))

	church_check_timer += delta
	if church_check_timer >= church_check_interval:
		church_check_timer = 0.0  # Reset the timer
		
		 # Create a copy of the humans array to safely iterate
		var valid_humans = humans.duplicate()
		for human_cell in valid_humans:
			if is_instance_valid(human_cell) and human_cell.is_inside_tree():
				var human_pos = tile_map.local_to_map(human_cell.global_position)
				build_church(human_pos)

	# Create a copy of the humans array to safely iterate
	var humans_to_check = humans.duplicate()
	for i in range(humans_to_check.size() - 1, -1, -1):
		var human_cell = humans_to_check[i]
		if is_instance_valid(human_cell) and human_cell.is_inside_tree():
			if not human_cell.is_moving:
				human_cell.decide_action()
		else:
			# If human is no longer valid, remove it from the original array
			if humans.has(human_cell):
				humans.erase(human_cell)


		

var used_tiles = {}


func spawn_human(pos: Vector2i):
	if pos.x < 0 or pos.x >= width or pos.y < 0 or pos.y >= height:
		print("❌ Cannot spawn human outside map boundaries")
		return
	var human_scene = preload("res://scenes/human_cell.tscn")
	var human = human_scene.instantiate()
	var world_pos = tile_map.map_to_local(pos)
	human.global_position = world_pos
	human.initialize(tile_map, astar, weight_map, is_paused)
	add_child(human)
	humans.append(human)
	print("✅ Spawned human at tile:", pos, " | World pos:", world_pos)

func show_human_stats(human):

	details_label.text = "Health: " + str(human.health) + "\n Happiness: " + str(human.happiness) + "\nStamina: " + str(human.stamina) + "\n Hunger: " + str(human.hunger) + "\nAge: " + str(human.age) + "\n Wood amount: "+str(human.wood_amount)+ "\nProfession: "+str(human.profession)+"\nFood Amount: "+str(human.food_amount)
	details_label.position = get_local_mouse_position() + Vector2(10, 10)
	details_label.show() 


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
				elif flower_chance > 0.45:
					tile_type = "flower"
					weight = tile_weights_map[tile_type]
				elif forest_chance > 0.2:
					tile_type = "forest"
					weight = tile_weights_map[tile_type]
				elif normalized_noise > thresholds[6]:
					tile_type = "snow"
					weight = tile_weights_map[tile_type] 


			var pos = Vector2i(x, y)
			if tile_type == "flower":
				flower_life_queue.append({
					"pos": pos,
					"age": 0.0,
					"decay_time": randf_range(10.0, 25.0) 
				})

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

func hide_human_stats():
	details_label.hide()

func register_house(house_position: Vector2i, house_sprite: Sprite2D):
	houses.append(house_position)
	house_sprites.append(house_sprite)
	house_count += 1
	add_child(house_sprite)

func reset_simulation():
	print("Resetting simulation...")
	
	# Clear all humans
	for human in humans:
		if is_instance_valid(human):
			human.queue_free()
	humans.clear()
	
	flower_life_queue.clear()
	print("Simulation reset complete")

var popup_font = preload("res://assets/fonts/Tox Typewriter.ttf")	

func show_info_popup():
	var info_popup = AcceptDialog.new()
	info_popup.title = "Game controls and shortcuts"
	info_popup.size = Vector2(300, 200)
	
	var rich_text = RichTextLabel.new()
	rich_text.bbcode_enabled = true
	rich_text.fit_content = true
	rich_text.scroll_active = false
	rich_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rich_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rich_text.add_theme_font_override("normal_font", popup_font)
	rich_text.add_theme_font_size_override("normal_font_size", 16)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 5)
	margin.add_theme_constant_override("margin_bottom", 20)
	margin.add_child(rich_text)
	info_popup.add_child(margin)
	
	rich_text.text = "	
	[font_size=18][u]Keyboard Shortcuts:[/u][/font_size]
	[table=2][cell]Space:[/cell][cell]Pause/Unpause[/cell]
	[cell]~ (Tilde):[/cell][cell]Toggle terrain editor[/cell]
	[cell]1-9:[/cell][cell]Select terrain type[/cell]
	[cell]T key:[/cell][cell]Thanos snap. Half the current population of the people[/cell]
	[cell]O key:[/cell][cell]Zoom in[/cell]
	[cell]P key:[/cell][cell]Zoom out[/cell]
	[cell]Arrow keys:[/cell][cell]Navigate on the map[/cell][/table]
	
	[font_size=18][u]Mouse Controls:[/u][/font_size]
	[table=2][cell]Left-click:[/cell][cell]Spawn human/Paint terrain[/cell]
	[cell]Right-click/Hover:[/cell][cell]Inspect human[/cell][/table]
	
	[font_size=18][u]Terrain Types:[/u][/font_size]
	[table=2][cell]1. Water[/cell][cell]5. Flower[/cell]
	[cell]2. Sand[/cell][cell]6. Snow[/cell]
	[cell]3. Grass[/cell][cell]7. Forest[/cell]
	[cell]4. Mountain[/cell][/table]
	"
	
	var vbox = VBoxContainer.new()
	vbox.add_child(rich_text)
	vbox.add_child(Control.new())  # Empty spacer
	margin.add_child(vbox)
	
	add_child(info_popup)
	info_popup.popup_centered()
	
