extends CharacterBody2D
class_name Customer

var movement_speed = 50.0
@onready var navigation_agent_2d: NavigationAgent2D = $NavigationAgent2D

signal service_requested(customer: Customer)
signal order_placed(customer: Customer, order: Order)

var planned_action = null

func _ready() -> void:
	navigation_agent_2d.navigation_finished.connect(_execute_planned_action)
		
func _execute_planned_action():
	if planned_action:
		planned_action.call()
	planned_action = null
		
func set_target(pos: Vector2, on_finished: Callable):
	navigation_agent_2d.target_position = pos
	planned_action = on_finished

func _process(_delta: float) -> void:
	if navigation_agent_2d.is_navigation_finished():
		return
	var current_agent_position = global_position
	var next_path_position = navigation_agent_2d.get_next_path_position()
	velocity = current_agent_position.direction_to(next_path_position) * movement_speed
	move_and_slide()
	
func arrived_at_waiting_pos(queue_pos: int):
	if(queue_pos == 0):
		service_requested.emit(self)

func place_order():
	print("order placed")
	var items: Array[Product.Type] = [Product.Type.SWORD]
	var order = Order.new(self, items)
	order_placed.emit(order)
