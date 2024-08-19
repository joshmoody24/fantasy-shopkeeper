extends CharacterBody2D
class_name Worker

var movement_speed = 50.0
@onready var navigation_agent_2d: NavigationAgent2D = $NavigationAgent2D
@export var store: Store

signal needs_work(worker: Worker)
signal order_taken(customer: Customer)
signal item_fulfilled(customer: Customer, item: Product.Type)

var planned_action = null
var carrying = null

enum Responsibility { TAKE_ORDERS, FULFILL_ORDERS }

var priority_weights: Dictionary = {
	Responsibility.TAKE_ORDERS: 1,
	Responsibility.FULFILL_ORDERS: 1,
}

func _ready() -> void:
	store.store_updated.connect(select_optimal_task)
	store.hire_worker(self)
	navigation_agent_2d.navigation_finished.connect(_execute_planned_action)

func _execute_planned_action():
	if planned_action:
		planned_action.call()

func _process(delta: float) -> void:
	var current_agent_position = global_position
	var next_path_position = navigation_agent_2d.get_next_path_position()
	velocity = current_agent_position.direction_to(next_path_position) * movement_speed
	move_and_slide()

func set_target(pos: Vector2, on_finished: Callable):
	navigation_agent_2d.target_position = pos
	planned_action = on_finished
	
func find_nearest_shelf(type = null, has_inventory = false) -> Shelf:
	return (store.shelves
		.filter(func (s): return s.has_current_inventory(type) if type else s.has_any_inventory())
		.reduce(func (chosen, current):
			return chosen if global_position.distance_to(chosen.position) < global_position.distance_to(current.position) else current))
	
func estimate_time_to_fulfill_item(customer: Customer, item: Product.Type):
	if carrying and carrying == item:
		return global_position.distance_to(customer.position)
	else:
		var shelf = find_nearest_shelf(item, true)
		if not shelf:
			return INF
		return global_position.distance_to(shelf.position) + shelf.position.distance_to(customer.position)
		
func flatten_array(nested_array: Array) -> Array:
	var flat_array = []
	for element in nested_array:
		if element is Array:
			flat_array += flatten_array(element)
		else:
			flat_array.append(element)
	return flat_array
	
func take_order(customer: Customer):
	print(take_order)
	var register = store.get_register_serving_customer(customer)
	if not register:
		needs_work.emit(self)
		return
	set_target(register.position, func (): order_taken.emit(customer))
	
func try_take_item_off_shelf(shelf: Shelf, item: Product.Type):
	var success = shelf.try_remove_item(item)
	if success:
		if carrying:
			shelf.store_item(carrying)
		carrying = item
	return success
	
func fulfill_item(customer: Customer, item: Product.Type) -> void:
	print("fulfilling item")
	var register = store.get_register_serving_customer(customer)
	var hand_to_customer = func (): item_fulfilled.emit(self, customer, item)
	if not register:
		needs_work.emit(self)
		return
	if carrying == item:
		set_target(customer.position, hand_to_customer)
	else:
		var shelf = find_nearest_shelf(item, true)
		if shelf:
			set_target(shelf.position, func ():
				var success = try_take_item_off_shelf(shelf, item)
				if success:
					set_target(customer.position, hand_to_customer))
		else:
			needs_work.emit(self)
	
func select_optimal_task(unhelped_customers: Dictionary, orders: Dictionary):
	var take_order_tasks: Array = unhelped_customers.keys().map(func (c: Customer) -> Dictionary: return {
		"est_time": global_position.distance_to(c.position),
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
