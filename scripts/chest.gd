extends StaticBody2D
class_name Chest

var supported_types: Dictionary = {
	Product.Type.SWORD: true,
}
var inventory: Dictionary = {}
	
func get_supported_types() -> Array:
	return supported_types.keys()

func supports(type: Product.Type):
	return type in supported_types and supported_types[type]

func get_current_inventory(type: Product.Type) -> int:
	return inventory[type]
	
func has_current_inventory(type: Product.Type) -> bool:
	return inventory[type] > 0
	
func has_any_inventory() -> bool:
	return inventory.values().any(func (quantity): return quantity > 0)

func store_item(type: Product.Type) -> void:
	if type not in inventory:
		inventory[type] = 1
	else:
		inventory[type] += 1
		
func try_remove_item(type: Product.Type) -> bool:
	if inventory[type] > 0:
		inventory[type] -= 1
		return true
	else:
		return false
		
func get_block_type() -> BlockManager.Block:
	return BlockManager.Block.CHEST
