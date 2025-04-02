extends Control

@onready var start_button: Button = $VBoxContainer/start
@onready var quit_button: Button = $VBoxContainer/quit
@onready var credits_button: Button = $VBoxContainer/credits
@onready var tilemap_layer = $TileMapLayer

var highlighted_tiles = [] # List to track highlighted tiles
var HIGHLIGHT_RADIUS = 1 # Radius around mouse to highlight

func _ready() -> void:
	start_button.pressed.connect(_on_start_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	credits_button.pressed.connect(_on_credits_pressed)
	
	set_process_input(true)

	# black color each
	for x in range(tilemap_layer.get_used_rect().position.x, tilemap_layer.get_used_rect().end.x):
		for y in range(tilemap_layer.get_used_rect().position.y, tilemap_layer.get_used_rect().end.y):
			var tile_data = tilemap_layer.get_cell_tile_data(Vector2i(x, y))
			if tile_data:
				tile_data.modulate = Color(0.8, 0.8, 0.8, 0.3) 

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
		var cell_pos = tilemap_layer.local_to_map(mouse_pos)

		highlighted_tiles.clear()
		# Highlight only individual tiles in the radius
		for x_offset in range(-HIGHLIGHT_RADIUS, HIGHLIGHT_RADIUS + 1):
			for y_offset in range(-HIGHLIGHT_RADIUS, HIGHLIGHT_RADIUS + 1):
				var check_pos = cell_pos + Vector2i(x_offset, y_offset)
				var current_tile_data = tilemap_layer.get_cell_tile_data(check_pos)
				
				# Ensure the tile exists and is the correct individual tile
				if current_tile_data and check_pos == cell_pos:
					current_tile_data.modulate = Color(0.8, 0.8, 0.8, 1) # Light gray
					highlighted_tiles.append(check_pos)
