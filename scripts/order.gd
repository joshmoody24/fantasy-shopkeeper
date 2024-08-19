class_name Order

var customer: Customer
var items: Array[Product.Type]

func _init(customer: Customer, items: Array[Product.Type]):
	self.customer = customer
	self.items = items
