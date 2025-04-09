extends Node2D

# ✅ Stats
var health: int = 60
var happiness: int = 60
var stamina: int = 100
var hunger: int = 100
var age: int = 0
var max_age: int = 400

# ✅ Memory
var memory = {
	"last_food": null
}

# ✅ Movement + Brain
var path: Array = []
var move_index: int = 0
var is_moving: bool = false
var perception_radius: int = 8

# ✅ World data
var tile_map
var astar: AStar2D
var weight_map: Dictionary

# ✅ Constants
const GENERATION_TIME := 0.5

var is_paused: bool = false  # Variable to control paused state

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
	hunger -= 1  # Decreases hunger over time
	stamina -= 1  # Decreases stamina over time

	# If hunger is too high, search for food
	if hunger <= 60:
		var food_pos = scan_for_food()  # Search for food based on perception radius
		if food_pos:
			move_to(food_pos)  # Move to the food
			return

	# If no food found, wander randomly (as a fallback behavior)
	var current_pos = tile_map.local_to_map(global_position)
	var target_pos = current_pos + Vector2i(randi_range(-5, 5), randi_range(-5, 5))
	move_to(target_pos)


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
			if weight == 3 and randi() % 2 == 0:  # Water/Sand (fish)
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


func _move_along_path():
	if move_index >= path.size():
		is_moving = false  # End movement when path is exhausted
		return

	var next_pos = Vector2i(path[move_index])  # Get the next point in path
	var cost = weight_map.get(next_pos, 1)

	# Decrease stamina based on tile weight
	stamina -= cost

	# Handle out of stamina
	if stamina <= 0:
		print("A human ran out of stamina!")
		is_moving = false
		return

	# Update global position to move the human
	global_position = tile_map.map_to_local(next_pos)

	# Update the sprite position relative to the human node
	$Cell.global_position = global_position  # Correct sprite's global position
	move_index += 1

	# Call again after some delay
	await get_tree().create_timer(GENERATION_TIME).timeout
	_move_along_path()  # Recursively move along the path
