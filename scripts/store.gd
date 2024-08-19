extends Node2D
class_name Store

@onready var tilemap: TileMapLayer = $NavigationRegion2D/tilemap
@export var customer_scene: PackedScene
@onready var timer: Timer = $customer_spawner
@onready var spawn_location: Node2D = $spawn_location

const SPEEDUP_FACTOR = .98
const INIT_WAIT_TIME = 3
const MIN_WAIT_TIME = 1
const MAX_CUSTOMERS = 100

var registers: Array[Register] = []
var shelves: Array[Shelf] = []
var unhelped_customers: Dictionary = {}
var orders: Dictionary = {}

signal store_updated(unhelped_customers: Array[Customer], orders: Dictionary)

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	registers = create_registers()
	shelves = create_shelves()
	timer.start(INIT_WAIT_TIME)

# the word "register" is overloaded
func hire_worker(worker: Worker):
	worker.order_taken.connect(_on_order_taken)
	worker.item_fulfilled.connect(_on_item_fulfilled)
	worker.needs_work.connect(func (): store_updated.emit(unhelped_customers, registers))

func create_registers() -> Array[Register]:
	var register_positions = tilemap.get_used_cells_by_id(-1, Vector2(0, 6))
	var register_list: Array[Register] = []
	for position in register_positions:
		var world_position = to_global(tilemap.map_to_local(position))
		register_list.append(Register.new(world_position))
	return register_list
	
func create_shelves() -> Array[Shelf]:
	var shelf_positions = tilemap.get_used_cells_by_id(-1, Vector2(3, 5))
	var shelf_list: Array[Shelf] = []
	for position in shelf_positions:
		var world_position = to_global(tilemap.map_to_local(position))
		shelf_list.append(Shelf.new(world_position, {
			Product.Type.SWORD: 5
		}))
	return shelf_list

func dequeue_customer_from_register(register_index):
	if register_index >= 0 and register_index < registers.size():
		registers[register_index].dequeue_customer()
		
func spawn_customer():
	print("Spawning customer")
	var customer: Customer = customer_scene.instantiate()
	customer.position = spawn_location.position
	add_child(customer)
	var least_busy_register: Register = registers.reduce(func (register1: Register, register2: Register):
		if not register1 or not register2:
			return register1 or register2
		if register1.size() < register2.size():
			return register1
		elif register1.size() > register2.size():
			return register2
		else:
			return register1 if customer.position.distance_to(register1.position) < customer.position.distance_to(register2.position) else register2)
	var queue_pos = least_busy_register.enqueue_customer(customer)
	_move_customer_to_waiting_pos(customer, queue_pos)

func _move_customer_to_waiting_pos(customer: Customer, queue_pos: int):
	var register = get_register_containing_customer(customer)
	var register_tile_pos = tilemap.local_to_map(to_local(register.position))
	var wait_pos_tile = Vector2(register_tile_pos.x, register_tile_pos.y - queue_pos - 1)
	var wait_pos_world = to_global(tilemap.map_to_local(wait_pos_tile))
	customer.set_target(wait_pos_world, func (): customer.arrived_at_waiting_pos(queue_pos))
	customer.order_placed.connect(_on_order_placed)
	customer.service_requested.connect(_on_service_requested)	
	
func _on_order_placed(order: Order) -> void:
	orders[order.customer] = order
	store_updated.emit(unhelped_customers, orders)
	
func _on_order_taken(customer: Customer) -> void:
	unhelped_customers.erase(customer)
	customer.place_order()
	
func _on_item_fulfilled(worker: Worker, customer: Customer, item: Product.Type) -> void:
	if customer not in orders:
		print("fulfilling old order: this should never happen")
		return
	var index = orders[customer].items.find(item)
	if index == -1:
		print("the customer didn't want this item")
	else:
		orders[customer].items.pop_at(index)
		worker.carrying = null
	if orders[customer].items.size() == 0:
		orders.erase(customer)
		customer.set_target(spawn_location.position, func (): customer.queue_free())
		var register: Register = get_register_serving_customer(customer)
		register.dequeue_customer()
		for i in len(register.queue):
			customer = register.queue[i]
			_move_customer_to_waiting_pos(customer, i)
	store_updated.emit(unhelped_customers, orders)
	
func _on_service_requested(customer: Customer) -> void:
	unhelped_customers[customer] = true
	store_updated.emit(unhelped_customers, orders)
	
func get_register_containing_customer(customer: Customer):
	for register in registers:
		if register.contains(customer):
			return register
	return null
	
func get_register_serving_customer(customer: Customer):
	for register in registers:
		if register.is_currently_serving(customer):
			return register
	return null

func _on_timer_timeout() -> void:
	spawn_customer()
	timer.start(timer.wait_time * SPEEDUP_FACTOR)
