extends Node2D
class_name Store

@onready var tilemap: TileMapLayer = $NavigationRegion2D/tilemap
@export var customer_scene: PackedScene
@onready var timer: Timer = $customer_spawner
@onready var spawn_location: Node2D = $spawn_location
@onready var objects: Node2D = $NavigationRegion2D/objects

const SPEEDUP_FACTOR = .98
const MIN_WAIT_TIME = 1
const MAX_CUSTOMERS = 100
const MAX_BLOCKS = 20

var registers: Array[Register] = []
var chests: Array[Chest] = []
var unhelped_customers: Dictionary = {}
var orders: Dictionary = {}

signal store_updated(unhelped_customers: Array[Customer], orders: Dictionary)

func _ready() -> void:
	pass
	
func start_game() -> void:
	timer.start()
	
# the word "register" is overloaded
func hire_worker(worker: Worker):
	worker.order_taken.connect(_on_order_taken)
	worker.item_fulfilled.connect(_on_item_fulfilled)
	worker.needs_work.connect(func (): store_updated.emit(unhelped_customers, registers))

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
	
func _get_objects_at_pos(position: Vector2) -> Array:
	var space_state = get_world_2d().direct_space_state
	var params = PhysicsPointQueryParameters2D.new()
	params.position = position
	var result = space_state.intersect_point(params)
	return result

func can_position_receive_block(position: Vector2):
	var objs = _get_objects_at_pos(position)
	print(objs)
	if objs.size() > 0:
		return false
	var tile = tilemap.get_cell_atlas_coords(tilemap.local_to_map(to_local(position)))
	if tile.x != 0 and tile.y != 4:
		return false
	return get_total_blocks() < MAX_BLOCKS

func _on_block_manager_block_placed(position: Vector2, block: BlockManager.Block, scene: PackedScene) -> void:
	if not can_position_receive_block(position):
		return
	var obj = scene.instantiate()
	obj.position = position
	objects.add_child(obj)
	if obj is Register:
		var register = obj as Register
		registers.append(register)
	elif obj is Chest:
		var chest = obj as Chest
		chests.append(chest)
		# temp
		chest.store_item(Product.Type.SWORD)
		chest.store_item(Product.Type.SWORD)
		chest.store_item(Product.Type.SWORD)
		chest.store_item(Product.Type.SWORD)


func _on_block_manager_block_removed(position: Vector2) -> void:
	var objs = _get_objects_at_pos(position)
	for obj in objs.map(func(d: Dictionary): return d["collider"]):
		if obj is Chest:
			chests.erase(obj)
		elif obj is Register:
			registers.erase(obj)
		else:
			print("unrecognized")
		obj.queue_free()

func get_total_blocks() -> int:
	return registers.size() + chests.size() # + anvils.size() + cauldrons.size()


func _on_hud_game_started() -> void:
	start_game()
