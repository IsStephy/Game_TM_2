extends Node2D
# ✅ Stats
var health: int = 100
var happiness: int = 100
var stamina: int = 100
var hunger: int = 100  # Hunger stat
var age: int = 0
var max_age: int = 15
var wood_amount: int = 0
var house_count: int = 0  # Track number of houses built
var food_amount: int = 0  # New variable for food, max 10
# ✅ Memory
var memory = {
	"last_food": null
}
# ✅ Movement + Brain
var path: Array = []
var move_index: int = 0
var is_moving: bool = false
var perception_radius: int = 8
var is_stamina_low: bool = false
# ✅ World data
var tile_map
var astar: AStar2D
var weight_map: Dictionary
# ✅ Constants
const GENERATION_TIME := 1
const STAMINA_REGEN_RATE := 10  # Stamina regeneration per cycle
var is_paused: bool = true  # Variable to control paused state
# ✅ Profession variables
enum Profession { NONE, FISHER, FARMER, HUNTER, BUILDER }
var profession: Profession
# Called when the node enters the scene tree for the first time.
func _ready():
	print("✅ Human ready.")
	# Add hover detection
	var hover_area = Area2D.new()
	hover_area.name = "HoverArea"
	add_child(hover_area)

	var collision_shape = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = Vector2(32, 32)
	collision_shape.shape = shape
	hover_area.add_child(collision_shape)

	hover_area.connect("mouse_entered", Callable(self, "_on_mouse_entered"))
	hover_area.connect("mouse_exited", Callable(self, "_on_mouse_exited"))

	if has_node("Cell"):
		var sprite = $Cell
		sprite.visible = true
		sprite.z_index = 10
		sprite.scale = Vector2(2, 2)
		sprite.position = Vector2.ZERO  # Ensure sprite's local position is reset to (0,0) in the parent Node2D
		# Update the sprite's position based on the global position
		sprite.global_position = global_position
	else:
		print("❌ Sprite node 'Cell' missing!")
	set_process(true)
var initialized = false
func initialize(map, astar_ref, weights, paused):
	tile_map = map
	astar = astar_ref
	weight_map = weights
	is_paused = paused  # Set paused flag from main.gd
	initialized = true
	age = 0
	max_age = 15
	print("✅ Human initialized!")
	# After initialization, move sprite to the correct position on the map
	if has_node("Cell"):
		var sprite = $Cell
		sprite.position = Vector2.ZERO  # Reset position to (0, 0) relative to the HumanCell node
func _process(_delta):
	
	# Skip everything if the game is paused
	if is_paused:
		return
	if not initialized or not is_inside_tree():
		return
	if age >= max_age or health <= 0 or hunger <= 0:
		die()
		return
	if not is_moving and stamina > 0:
		decide_action()

func die():
	print("❌ Human died at age:", age)
	# Remove from the humans array in main.gd
	var main = get_parent()
	if main and main.has_method("remove_human"):
		main.remove_human(self)
	is_moving = false
	# Remove the node itself
	queue_free()

func get_random_child_count() -> int:
	var rand_val = randf()  # Random float between 0.0 and 1.0
	if rand_val < 0.7:      # 70% chance no childe
		return 0
	elif rand_val < 0.85:    # 15% chance (50% + 30% = 80%) 1
		return 1
	elif rand_val < 0.95:   # 10% chance (80% + 15% = 95%) 2
		return 2
	else:                   # 5% chance (remaining) 3
		return 3
func decide_action():
	# Adjusting stats
	if is_moving:
		return
	
	age += 1
	hunger -= 3  # Decreases hunger over time
	stamina -= 1  # Decreases stamina over time
	happiness -= 2
	# If hunger is too high, search for food
	if hunger <= 30:
		var food_pos = scan_for_food(Profession.NONE)  # Search for food based on perception radius
		if food_pos:
			move_to(food_pos,profession)  # Move to the food
			return
	if happiness <= 30:
		var flower_pos = search_for_happy()  # Search for happiness (flowers) based on perception radius
		if flower_pos:
			move_to(flower_pos,profession)  # Move to the flower
			return
	if profession == Profession.NONE:
	# If hunger and happiness are not too low, gather wood from the forest
		if wood_amount < 30:
			var forest_pos = search_for_wood()  # Search for forest to gather wood
			if forest_pos:
				move_to(forest_pos,profession)  # Move to the forest to gather wood
				return
		if health >= 65 and happiness >= 65 and hunger >= 65:
			var church_pos = search_for_church()
			if church_pos:
				move_to(church_pos,profession)
				wait_for_profession_at_church()
				return
		# If the character has 20 wood, attempt to construct a house
		if wood_amount >= 20 and house_count < 1:
			build_house()
			return
	if profession == Profession.BUILDER:
		if wood_amount < 120:
			var forest_pos = search_for_wood()  # Search for forest to gather wood
			if forest_pos:
				move_to(forest_pos,profession)  # Move to the forest to gather wood
				return
		# If the character has 20 wood, attempt to construct a house
		if wood_amount >= 20 and house_count < 3:
			build_house()
			return
		
	elif profession == Profession.FARMER:
		var food_pos = scan_for_food(Profession.FARMER)  # Search for food based on perception radius
		if food_pos:
			move_to(food_pos,profession)  # Move to the food
			return
	elif profession == Profession.FISHER:
		var food_pos = scan_for_food(Profession.FISHER)  # Search for food based on perception radius
		if food_pos:
			move_to(food_pos,profession)  # Move to the food
			return
	# If no food, happiness, or wood found, wander randomly (as a fallback behavior)
	var current_pos = tile_map.local_to_map(global_position)
	var target_pos = current_pos + Vector2i(randi_range(-5, 5), randi_range(-5, 5))
	move_to(target_pos,profession)
	
	var hasreproduced = false
	if profession != Profession.NONE and !hasreproduced:
		if health > 50 and happiness > 50:
			current_pos = tile_map.local_to_map(global_position)
			var child_count = get_random_child_count() 
			print("✅", child_count, " Children are born")
			
			for i in range(child_count):
				var spawned = false
				for attempt in range(3):
					var nearby_pos = current_pos + Vector2i(randi_range(-1, 1), randi_range(-1, 1))
					if tile_map.get_cell_source_id(nearby_pos) == 0:  # Check if tile is empty (assuming 0 is empty)
						$"../".spawn_human(nearby_pos)
						spawned = true
						break
						
						if spawned:
							print("✅ Spawned child #", i + 1, " of ", child_count)
						else:
							print("❌ Failed to spawn child #", i + 1, " (no valid tile found)")
						
						happiness -= 20  # Reduce happiness after reproduction
						health -= 10 
						hasreproduced = true # the mark that humans can only reproduce once
				   # Reduce health after reproduction
						return
# Funciton to search for church(weight = 0)
func search_for_church() -> Vector2i:
	var current_cell = tile_map.local_to_map(global_position)
	for x_offset in range(-10, 11):
		for y_offset in range(-10, 11):
			var check_pos = current_cell + Vector2i(x_offset, y_offset)
			if weight_map.has(check_pos) and weight_map[check_pos] == 0:
				return check_pos
	return Vector2i(-1,-1)
	
func wait_for_profession_at_church():
	var church_pos = search_for_church()
	
	if tile_map.local_to_map(global_position) == church_pos:
		is_moving = false  # Stop further movement
		print("At church. Waiting for profession blessing...")
		# Wait 3 generations, then try to get profession
		await get_tree().create_timer(GENERATION_TIME * 1).timeout
		var new_prof = randi() % 4
		profession = new_prof
		match new_prof:
			0:
				profession = Profession.BUILDER
				$Cell.texture = load("res://assets/character/builder.png")
			1:
				profession = Profession.FARMER
				$Cell.texture = load("res://assets/character/farmer.png")
			2:
				profession = Profession.FISHER
				$Cell.texture = load("res://assets/character/fisher.png")
			3:
				profession = Profession.HUNTER
				$Cell.texture = load("res://assets/character/hunter.png")
# Function to search for forest (weight 2) within a radius of 10
func search_for_wood():
	var current_cell = tile_map.local_to_map(global_position)
	for x_offset in range(-10, 11):  # Searching within a radius of 10
		for y_offset in range(-10, 11):  # Searching within a radius of 10
			var check_pos = current_cell + Vector2i(x_offset, y_offset)
			# Check if the tile exists and if it has a forest (weight 2)
			if not weight_map.has(check_pos):
				continue
			var weight = weight_map[check_pos]
			if weight == 2:  # Forest (wood resource)
				return check_pos
	return null
# Function to gather wood when staying in a forest (weight 2)
func gather_wood(profession):
	var current_cell = tile_map.local_to_map(global_position)
	if profession == Profession.BUILDER:
		if wood_amount < 120:
			wood_amount = min(wood_amount + 3, 120)
			print("Gathered wood. Builder's current wood: ", wood_amount)
	else:
		if wood_amount < 30:
			wood_amount = min(wood_amount + 3, 30)
			print("Gathered wood. Current wood: ", wood_amount)

	# Deplete forest tile (turn into grass after gathering)
	if weight_map.has(current_cell) and weight_map[current_cell] == 2:
		weight_map[current_cell] = 1
		var grass_variants = get_parent().terrain_tiles["grass"]
		var random_grass = grass_variants[randi() % grass_variants.size()]
		tile_map.set_cell(current_cell, get_parent().source_id, random_grass)

# Preload the house texture
var house_texture = preload("res://assets/buildings/house.png")
# Function to build a house if the human has enough wood
func build_house():
	if house_count < 1:  # Ensure only one house is built
		var random_pos = get_random_position_for_house()
		print("Building house at position: ", random_pos)
		house_count += 1
		wood_amount -= 20  # Deduct 20 wood for building the house
		# Create a sprite node for the house
		var house_sprite = Sprite2D.new()
		house_sprite.texture = house_texture  # Set the house texture to the sprite
		# Set the house sprite position to the corresponding tile position
		house_sprite.position = tile_map.map_to_local(random_pos)  # Convert the map position to local position
		# Add the sprite to the scene (parent node)
		get_parent().add_child(house_sprite)
		print("House built! Total houses constructed: ", house_count)
# Get a random position within the map for constructing a house
# Get a random position within a 10-tile radius where the weight is 1 (e.g., grass area)
func get_random_position_for_house() -> Vector2i:
	var current_cell = tile_map.local_to_map(global_position)
	var valid_positions = []
	# Search within a radius of 10 tiles
	for x_offset in range(-10, 11):
		for y_offset in range(-10, 11):
			var check_pos = current_cell + Vector2i(x_offset, y_offset)
			# Ensure the position exists and has a weight of 1 (suitable for building a house)
			if weight_map.has(check_pos) and weight_map[check_pos] == 1:
				valid_positions.append(check_pos)
	# If valid positions are found, return a random one; otherwise, return current position
	if valid_positions.size() > 0:
		return valid_positions[randi() % valid_positions.size()]
	else:
		return current_cell  # Fallback to current position if no valid spot is found
func scan_for_food(profession):
	var current_cell = tile_map.local_to_map(global_position)
	for x_offset in range(-perception_radius, perception_radius + 1):
		for y_offset in range(-perception_radius, perception_radius + 1):
			var check_pos = current_cell + Vector2i(x_offset, y_offset)
			# Check if the tile exists and if it has food resources (forest = mushrooms, water/sand = fish)
			if not weight_map.has(check_pos):
				continue
			var weight = weight_map[check_pos]
			if weight == 1 and profession == Profession.FARMER: # Farmer search grass
				return check_pos
			if weight == 2 and (profession == Profession.NONE or Profession.HUNTER): # If the human do not have a professiion can search for food in the forest
				return check_pos
			if weight == 2.5 and randi() % 2 == 0 and (profession == Profession.FARMER or profession == Profession.NONE):  # Water/Sand (fish)
				return check_pos
	return null
# Function to search for happiness (flowers) within a radius of 10 and weight of 1.5
func search_for_happy():
	var current_cell = tile_map.local_to_map(global_position)
	for x_offset in range(-10, 11):  # Searching within a radius of 10
		for y_offset in range(-10, 11):  # Searching within a radius of 10
			var check_pos = current_cell + Vector2i(x_offset, y_offset)
			# Check if the tile exists and if it has a flower (weight 1.5)
			if not weight_map.has(check_pos):
				continue
			var weight = weight_map[check_pos]
			if weight == 1.5:  # Flower (happiness resource)
				return check_pos
	return null
func move_to(target: Vector2i,profession):
	# Ensure the current and target positions are valid
	if tile_map == null or astar == null:
		return
	var current = tile_map.local_to_map(global_position)  # Current tile position
	var start_id = current.x * tile_map.get_used_rect().size.y + current.y
	var goal_id = target.x * tile_map.get_used_rect().size.y + target.y
	# Get the path if points are valid
	if astar.has_point(start_id) and astar.has_point(goal_id):
		path = astar.get_point_path(start_id, goal_id)
		move_index = 0
		is_moving = true
		_move_along_path(profession)  # Call the move logic
var is_happiness_low:bool = false
var is_hunger_low: bool = false
# Existing function: _move_along_path()
func _move_along_path(profession):
	if move_index >= path.size():
		is_moving = false  # End movement when path is exhausted
		return
		
	if happiness <= 0:
		health -= 2
	if happiness >= 97:
		is_happiness_low = false
		
	# Check if happiness is too low
	if happiness <= 30 or is_happiness_low:
		is_happiness_low = true
		print("Happiness exhausted, waiting for recovery...")
		# Regenerate happiness until it reaches 100
		happiness = min(happiness + 10, 100)
		happiness -= 2
		health += 2
		await get_tree().create_timer(GENERATION_TIME).timeout
		_move_along_path(profession)  # Call again after regenerating happiness
		return
		
	if hunger <= 0:
		health -= 2
	if hunger >= 94:
		is_hunger_low = false
		
	# Check if hunger is too low
	if hunger <= 30 or is_hunger_low:
		is_hunger_low = true
		print("Hunger exhausted, waiting for recovery...")
		# Regenerate hunger until it reaches 100
		hunger = min(hunger + 10, 100)
		if health <= 100:
			hunger -= 5
			health += 5
		await get_tree().create_timer(GENERATION_TIME).timeout
		_move_along_path(profession)  # Call again after regenerating hunger
		return
		
	if stamina >= 99:
		is_stamina_low = false
	# Check if stamina is too low
	if stamina <= 30 or is_stamina_low:
		is_stamina_low = true
		print("Stamina exhausted, waiting for recovery...")
		# Regenerate stamina until it reaches 100
		stamina = min(stamina + STAMINA_REGEN_RATE, 100)
		await get_tree().create_timer(GENERATION_TIME).timeout
		_move_along_path(profession)  # Call again after regenerating stamina
		return
	if is_stamina_low == false:
		var next_pos = Vector2i(path[move_index])  # Get the next point in path
		var cost = weight_map.get(next_pos, 1)
		# Decrease stamina based on tile weight
		stamina -= cost
		# Handle out of stamina
		if stamina <= 0:
			print("A human ran out of stamina!")
			is_moving = false
			return
		
		# Check if the human is on a forest tile (weight 2) and gather wood
		if weight_map.get(next_pos) == 2:  # Forest tile
			gather_wood(profession)
		# Check if the human is on a food tile (weight 1 for farmer, 2 for others)
		if weight_map.get(next_pos) == 1 or weight_map.get(next_pos) == 2.5:  # Food (farmer = grass, others = fish or mushrooms)
			gather_food(profession)
		# Update global position to move the human
		global_position = tile_map.map_to_local(next_pos)
		# Update the sprite position relative to the human node
		$Cell.global_position = global_position  # Correct sprite's global position
		move_index += 1
		# Call again after some delay
		await get_tree().create_timer(GENERATION_TIME).timeout
		_move_along_path(profession)  # Recursively move along the path

# New function to gather food when on a food resource tile
func gather_food(profession):
	if profession == Profession.FISHER or profession == Profession.FARMER or profession == Profession.HUNTER:
		if food_amount < 20:  # Check if the human can still gather food (max 10)
			food_amount = min(food_amount + 1, 20)  # Increase food by 1 per generation, max 10
			print("Gathered food. Current food amount: ", food_amount)
			if happiness<=100:
				happiness+= 3
	else:
		if food_amount < 10:  # Check if the human can still gather food (max 10)if food_amount < 10:  # Check if the human can still gather food (max 10
			food_amount = min(food_amount + 1, 10)  # Increase food by 1 per generation, max 10
			print("Gathered food. Current food amount: ", food_amount)

		food_amount = min(food_amount + 1, 10)  # Increase food by 1 per generation, max 10

func _on_mouse_entered():
	get_parent().show_human_stats(self)

func _on_mouse_exited():
	get_parent().hide_human_stats()
