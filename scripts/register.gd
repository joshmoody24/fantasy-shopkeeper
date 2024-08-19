class_name Register
var position: Vector2
var queue: Array = []

func _init(position: Vector2):
	self.position = position

func enqueue_customer(customer) -> int:
	queue.append(customer)
	return queue.size() - 1

func dequeue_customer():
	if queue.size() > 0:
		queue.pop_front()
		update_queue_positions()

func update_queue_positions():
	pass

func size():
	return queue.size()
	
func is_currently_serving(customer: Customer):
	return queue.size() > 0 and queue[0] == customer

func contains(customer: Customer):
	return customer in queue
