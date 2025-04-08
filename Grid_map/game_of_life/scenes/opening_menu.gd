extends Control

@onready var start_button: Button = $VBoxContainer/start
@onready var quit_button: Button = $VBoxContainer/quit
@onready var credits_button: Button = $VBoxContainer/credits
@onready var tilemap_layer = $TileMapLayer

var highlighted_tiles = []  # Track previously highlighted cells
const HIGHLIGHT_RADIUS = 3  # The radius of tiles to highlight

# Modulate color for highlighting
const HIGHLIGHT_COLOR = Color(1, 1, 0, 0.5)  # Yellow highlight with transparency

func _ready() -> void:
	start_button.pressed.connect(_on_start_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	credits_button.pressed.connect(_on_credits_pressed)
	set_process_input(true)

	# Set the modulate color for the entire TileMapLayer to dim it initially
	tilemap_layer.modulate = Color(0.8, 0.8, 0.8, 1)  # Dim all tiles by default

	get_node("VBoxContainer/start").grab_focus()

func _on_start_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main.tscn")
	
func _on_quit_pressed() -> void:
	get_tree().quit()
	
func _on_credits_pressed() -> void:
	pass

func _input(event):
	if event is InputEventMouseMotion:
		var mouse_pos = tilemap_layer.get_local_mouse_position()
		var center_cell = tilemap_layer.local_to_map(mouse_pos)

		# Reset previously highlighted tiles to default state
		for pos in highlighted_tiles:
			var tile_data = tilemap_layer.get_cell_tile_data(pos)
			if tile_data:
				tile_data.modulate = Color(1, 1, 1, 1)  # Reset to original color

		highlighted_tiles.clear()

		# Highlight tiles in radius
		for x_offset in range(-HIGHLIGHT_RADIUS, HIGHLIGHT_RADIUS + 1):
			for y_offset in range(-HIGHLIGHT_RADIUS, HIGHLIGHT_RADIUS + 1):
				var pos = center_cell + Vector2i(x_offset, y_offset)
				# Ensure the tile is valid (doesn't exceed the map bounds)
				if tilemap_layer.get_cell_source_id(pos) != -1:  # Check if the tile exists
					var tile_data = tilemap_layer.get_cell_tile_data(pos)
					if tile_data:
						tile_data.modulate = HIGHLIGHT_COLOR  # Apply yellow highlight
						highlighted_tiles.append(pos)
