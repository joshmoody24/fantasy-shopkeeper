extends Camera2D

@export var pan_sensitivity: float = 1.0
@export var zoom_sensitivity: float = 0.1
@export var zoom_min: float = 0.5
@export var zoom_max: float = 5.0

var is_panning: bool = false
var last_mouse_position: Vector2 = Vector2.ZERO

func _ready() -> void:
	pass

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			is_panning = event.pressed
			last_mouse_position = event.position

	if event is InputEventMouseMotion and is_panning:
		position -= (event.relative * pan_sensitivity) / zoom
		last_mouse_position = event.position

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			adjust_zoom(-zoom_sensitivity, event.position)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			adjust_zoom(zoom_sensitivity, event.position)

func adjust_zoom(delta: float, mouse_position: Vector2) -> void:
	var new_zoom = Vector2(clamp(zoom.x + delta, zoom_min, zoom_max), clamp(zoom.y + delta, zoom_min, zoom_max))
	zoom = new_zoom
