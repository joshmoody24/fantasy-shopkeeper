extends CharacterBody2D
class_name Worker

@onready var navigation_agent_2d: NavigationAgent2D = $NavigationAgent2D
@export var store: Store
@onready var timer: Timer = $Timer

signal needs_work(worker: Worker)
signal order_taken(customer: Customer)
signal item_fulfilled(customer: Customer, item: Product.Type)

var planned_action = null
var carrying = null
var act

enum Responsibility { TAKE_ORDERS, FULFILL_ORDERS }
var priority_weights: Dictionary = {
	Responsibility.TAKE_ORDERS: 1,
	Responsibility.FULFILL_ORDERS: 1,
}

enum CommittedState { NONE, HANDING_TO_CUSTOMER, TAKING_FROM_SHELF, TAKING_ORDER }
const CommittedStateSeconds = {
	CommittedState.HANDING_TO_CUSTOMER: 0.15,
	CommittedState.TAKING_FROM_SHELF: 0.3,
	CommittedState.TAKING_ORDER: 0.5,
}
var committed_state: CommittedState = CommittedState.NONE

const MOVEMENT_SPEED = 50

func _ready() -> void:
	store.store_updated.connect(select_optimal_task)
	store.hire_worker(self)
	navigation_agent_2d.navigation_finished.connect(_execute_planned_action)

func _execute_planned_action():
	if planned_action:
		planned_action.call()

func _process(delta: float) -> void:
	if navigation_agent_2d.is_navigation_finished():
		return
	var current_agent_position = global_position
	var next_path_position = navigation_agent_2d.get_next_path_position()
	velocity = current_agent_position.direction_to(next_path_position) * MOVEMENT_SPEED
	move_and_slide()

func set_target(pos: Vector2, on_finished: Callable):
	navigation_agent_2d.target_position = pos
	planned_action = on_finished
	
func commit_to_state(state: CommittedState, on_finished: Callable):
	committed_state = state
	timer.stop()
	for dict in timer.timeout.get_connections():
		timer.timeout.disconnect(dict["callable"])
	timer.timeout.connect(func ():
		committed_state = CommittedState.NONE
		on_finished.call()
		timer.stop()) # very important line, not sure why
	timer.start(CommittedStateSeconds[state])
	
func find_nearest_chest(type = null, has_inventory = false) -> Chest:
	return (store.chests
		.filter(func (c): return c.has_current_inventory(type) if type else c.has_any_inventory())
		.reduce(func (chosen, current):
			return chosen if global_position.distance_to(chosen.position) < global_position.distance_to(current.position) else current))
	
func estimate_time_to_fulfill_item(customer: Customer, item: Product.Type):
	var register = store.get_register_serving_customer(customer)
	if carrying and carrying == item:
		return global_position.distance_to(register.position) + CommittedStateSeconds[CommittedState.HANDING_TO_CUSTOMER]
	else:
		var chest = find_nearest_chest(item, true)
		if not chest:
			return INF
		return (((global_position.distance_to(chest.position) + chest.position.distance_to(register.position)) / MOVEMENT_SPEED)
				+ CommittedStateSeconds[CommittedState.TAKING_FROM_SHELF]
				+ CommittedStateSeconds[CommittedState.HANDING_TO_CUSTOMER])
		
func flatten_array(nested_array: Array) -> Array:
	var flat_array = []
	for element in nested_array:
		if element is Array:
			flat_array += flatten_array(element)
		else:
			flat_array.append(element)
	return flat_array
	
func take_order(customer: Customer):
	var register = store.get_register_serving_customer(customer)
	if not register:
		needs_work.emit(self)
		return
	set_target(register.position, func(): commit_to_state(CommittedState.TAKING_ORDER, func (): order_taken.emit(customer)))
	
func try_take_item_from_chest(chest: Chest, item: Product.Type):
	var success = chest.try_remove_item(item)
	if success:
		if carrying:
			chest.store_item(carrying)
		carrying = item
	return success
	
func fulfill_item(customer: Customer, item: Product.Type) -> void:
	print("fulfilling item")
	var register = store.get_register_serving_customer(customer)
	var hand_to_customer = func(): commit_to_state(CommittedState.HANDING_TO_CUSTOMER, func (): item_fulfilled.emit(self, customer, item))
	if not register:
		needs_work.emit(self)
		return
	if carrying == item:
		set_target(register.position, hand_to_customer)
	else:
		var chest = find_nearest_chest(item, true)
		if chest:
			set_target(chest.position, func ():
				var success = try_take_item_from_chest(chest, item)
				if success:
					commit_to_state(CommittedState.TAKING_FROM_SHELF, func (): set_target(register.position, hand_to_customer)))
		else:
			needs_work.emit(self)
	
func select_optimal_task(unhelped_customers: Dictionary, orders: Dictionary):
	if committed_state != CommittedState.NONE:
		return
		
	var take_order_tasks: Array = unhelped_customers.keys().map(func (c: Customer) -> Dictionary: return {
		"est_time": (global_position.distance_to(c.position) / MOVEMENT_SPEED) + CommittedStateSeconds[CommittedState.TAKING_ORDER],
		"weight": priority_weights[Responsibility.TAKE_ORDERS],
		"execute": func (): take_order(c),
		"type": "take_order",
	})
	
	print(orders)
	
	var fulfill_order_items: Array = (orders.values()
		.map(func (o: Order): return o.items.map(func (li): return {
			"customer": o.customer,
			"item": li,
		})))
		
	var fulfill_item_tasks = flatten_array(fulfill_order_items).map(func (d: Dictionary): return {
			"est_time": estimate_time_to_fulfill_item(d["customer"], d["item"]),
			"weight": priority_weights[Responsibility.FULFILL_ORDERS],
			"execute": func (): fulfill_item(d["customer"], d["item"]),
			"type": "fulfill_item",
		})
	
	var all_tasks = take_order_tasks + fulfill_item_tasks
	
	var optimal_task = all_tasks.map(func (task: Dictionary): return {
		"priority": task["weight"] / task["est_time"],
		"type": task["type"],
		"execute": task["execute"],
	}).reduce(func (current, chosen): return current if current["priority"] > chosen["priority"] else chosen)
	
	print("Chosen optimal task", optimal_task)
	
	if optimal_task:
		optimal_task["execute"].call()
