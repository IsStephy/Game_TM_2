extends Node2D

# ✅ Stats
var health: int = 60
var happiness: int = 60
var stamina: int = 100
var hunger: int = 100  # Hunger stat
var age: int = 0
var max_age: int = 400
var wood_amount: int = 0

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
	is_paused = paused
	print(is_paused)  # Set paused flag from main.gd
	initialized = true
	print("✅ Human initialized!")

	# After initialization, move sprite to the correct position on the map
	if has_node("Cell"):
		var sprite = $Cell
		sprite.position = Vector2.ZERO  # Reset position to (0, 0) relative to the HumanCell node

func _process(_delta):
	print(is_paused)
	# Skip everything if the game is paused
	if is_paused:
		return
	
	if not initialized or not is_inside_tree():
		return

	if not is_moving and stamina > 0:
		decide_action()

func decide_action():
	# Skip action logic if paused
	if is_paused:
		return

	# Adjusting stats
	age += 1
	hunger -= 5  # Decreases hunger over time
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
func check_for_happiness():
	if happiness <= 0:
		health -= 2
	if happiness >= 100:
		is_happiness_low = false
	# Check if happiness is too low
	if happiness <= 30 or is_happiness_low:
		is_happiness_low = true
		print("Happiness exhausted, waiting for recovery...")
		# Regenerate happiness until it reaches 100
		happiness = min(happiness + 10, 100)
		happiness -= 2
		health += 5
		await get_tree().create_timer(GENERATION_TIME).timeout
		_move_along_path()  # Call again after regenerating happiness
		return

var is_hunger_low: bool = false
func check_for_hunger():
	if hunger <= 0:
		health -= 2
	if hunger >= 100:
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

func check_for_stamina():
	if stamina <= 0:
		health -= 2
	if stamina >= 100:
		is_stamina_low = false
	# Check if stamina is too low
	if stamina <= 30 or is_stamina_low:
		is_stamina_low = true
		print("Stamina exhausted, waiting for recovery...")
		# Regenerate stamina until it reaches 100
		stamina = min(stamina + STAMINA_REGEN_RATE, 100)
		stamina -= 1
		health += 5
		await get_tree().create_timer(GENERATION_TIME).timeout
		_move_along_path()  # Call again after regenerating stamina
		return

func _move_along_path():
	# Ensure movement stops if the game is paused
	if is_paused:
		is_moving = false
		return
	
	# If no movement is left to perform, end it
	if move_index >= path.size():
		is_moving = false  # End movement when path is exhausted
		return
	
	check_for_stamina()
	check_for_happiness()
	check_for_hunger()

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

<<<<<<< HEAD
		# Update the sprite position relative to the human node
		$Cell.global_position = global_position  # Correct sprite's global position
		move_index += 1

		# Call again after some delay
		await get_tree().create_timer(GENERATION_TIME).timeout
		_move_along_path()  # Recursively move along the path
=======
	# Call the next step of movement after delay (if not paused)
	if is_paused == false:
		print(is_paused)
		await get_tree().create_timer(GENERATION_TIME).timeout
		_move_along_path()  # Proceed with the next path step
>>>>>>> d5bcba37fa892f9aeb0d4853ee83cccb1791ee5f
