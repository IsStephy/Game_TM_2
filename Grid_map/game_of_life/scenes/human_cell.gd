extends Node2D

# ✅ Stats
var health: int = 60
var happiness: int = 60
var stamina: int = 100
var hunger: int = 100  # Hunger stat
var age: int = 0
var max_age: int = 400
var wood_amount: int = 0
var house_count: int = 0  # Track number of houses built

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

# Called when the node enters the scene tree for the first time.
func _ready():
	print("✅ Human ready.")
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

	if not is_moving and stamina > 0:
		decide_action()

func decide_action():
	# Adjusting stats
	age += 1
	hunger -= 3  # Decreases hunger over time
	stamina -= 1  # Decreases stamina over time
	happiness -= 2

	# If hunger is too high, search for food
	if hunger <= 30:
		var food_pos = scan_for_food()  # Search for food based on perception radius
		if food_pos:
			move_to(food_pos)  # Move to the food
			return
	if happiness <= 30:
		var flower_pos = search_for_happy()  # Search for happiness (flowers) based on perception radius
		if flower_pos:
			move_to(flower_pos)  # Move to the flower
			return

	# If hunger and happiness are not too low, gather wood from the forest
	if wood_amount < 30:
		var forest_pos = search_for_wood()  # Search for forest to gather wood
		if forest_pos:
			move_to(forest_pos)  # Move to the forest to gather wood
			return

	# If the character has 20 wood, attempt to construct a house
	if wood_amount >= 20 and house_count < 1:
		build_house()
		return

	# If no food, happiness, or wood found, wander randomly (as a fallback behavior)
	var current_pos = tile_map.local_to_map(global_position)
	var target_pos = current_pos + Vector2i(randi_range(-5, 5), randi_range(-5, 5))
	move_to(target_pos)

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
func gather_wood():
	if wood_amount < 30:  # Check if the human can still gather wood (max 30)
		wood_amount = min(wood_amount + 3, 30)  # Increase wood by 3 per generation, max 30
		print("Gathered wood. Current wood amount: ", wood_amount)

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


func scan_for_food():
	var current_cell = tile_map.local_to_map(global_position)
	for x_offset in range(-perception_radius, perception_radius + 1):
		for y_offset in range(-perception_radius, perception_radius + 1):
			var check_pos = current_cell + Vector2i(x_offset, y_offset)

			# Check if the tile exists and if it has food resources (forest = mushrooms, water/sand = fish)
			if not weight_map.has(check_pos):
				continue

			var weight = weight_map[check_pos]
			if weight == 2:  # Forest (food resource)
				return check_pos
			if weight == 2.5 and randi() % 2 == 0:  # Water/Sand (fish)
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

func move_to(target: Vector2i):
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
		_move_along_path()  # Call the move logic

var is_happiness_low:bool = false
var is_hunger_low: bool = false

func _move_along_path():
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
		_move_along_path()  # Call again after regenerating happiness
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
		hunger -= 5
		health += 5
		await get_tree().create_timer(GENERATION_TIME).timeout
		_move_along_path()  # Call again after regenerating hunger
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
		_move_along_path()  # Call again after regenerating stamina
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
			gather_wood()

		# Update global position to move the human
		global_position = tile_map.map_to_local(next_pos)

		# Update the sprite position relative to the human node
		$Cell.global_position = global_position  # Correct sprite's global position
		move_index += 1

		# Call again after some delay
		await get_tree().create_timer(GENERATION_TIME).timeout
		_move_along_path()  # Recursively move along the path
