extends CharacterBody2D

@export var speed: float = 1500.0  # Adjust speed as needed
@onready var camera = $Camera2D
@export var zoom_speed: float = 0.04  # Adjust zoom speed as needed

func _ready() -> void:
	pass

func _process(delta):
	var direction = Vector2.ZERO

	# Movement input
	if Input.is_action_pressed("ui_right"):
		direction.x += 1
	if Input.is_action_pressed("ui_left"):
		direction.x -= 1
	if Input.is_action_pressed("ui_down"):
		direction.y += 1
	if Input.is_action_pressed("ui_up"):
		direction.y -= 1

	# Normalize to prevent faster diagonal movement
	if direction.length() > 0:
		direction = direction.normalized()

	# Apply movement
	velocity = direction * speed
	move_and_slide()

	# Zoom control with + and - keys
	if Input.is_key_pressed(KEY_P):
		camera.zoom -= Vector2(zoom_speed, zoom_speed)  # Zoom in
	elif Input.is_key_pressed(KEY_O):
		camera.zoom += Vector2(zoom_speed, zoom_speed)  # Zoom out

	# Ensure zoom stays within reasonable bounds
	camera.zoom.x = clamp(camera.zoom.x, 0.05, 3)  # Min and Max zoom values
	camera.zoom.y = clamp(camera.zoom.y, 0.05, 3)
