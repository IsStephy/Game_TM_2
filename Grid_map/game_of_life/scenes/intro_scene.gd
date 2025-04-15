extends Node

var double_press_timer = 0
var double_press_threshold = 0.5  # Increased threshold for easier detection
var pressed_once = false
var main_scene = "res://scenes/opening_menu.tscn"  # Update this path as needed

func _ready():
	# Connect to the finished signal
	if has_node("VideoStreamPlayer"):
		$VideoStreamPlayer.connect("finished", Callable(self, "_on_video_finished"))

func _process(delta):
	# Handle the timer for double press
	if pressed_once:
		double_press_timer += delta
		if double_press_timer > double_press_threshold:
			pressed_once = false
			double_press_timer = 0

func _input(event):
	# Check for any key press or mouse click
	if (event is InputEventKey or event is InputEventMouseButton) and event.pressed:
		print("Input detected")
		
		if pressed_once and double_press_timer < double_press_threshold:
			# Double press detected, skip video
			_on_video_finished()
		else:
			# First press
			print("First press detected - waiting for second press")
			pressed_once = true
			double_press_timer = 0

func _on_video_finished():
	print("Changing to main scene: " + main_scene)
	# Change to the main game scene
	get_tree().change_scene_to_file(main_scene)
