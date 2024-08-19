extends Control

signal pallete_item_selected(pallete_item: BlockManager.Block)
signal game_started()

func _on_register_pallette_pressed() -> void:
	pallete_item_selected.emit(BlockManager.Block.TABLE)

func _on_chest_pallette_pressed() -> void:
	pallete_item_selected.emit(BlockManager.Block.CHEST)

func _on_craft_pallette_pressed() -> void:
	pallete_item_selected.emit(BlockManager.Block.ANVIL)

func _on_brew_pallette_pressed() -> void:
	pallete_item_selected.emit(BlockManager.Block.CAULDRON)
	
func _on_erase_button_pressed() -> void:
	pallete_item_selected.emit(BlockManager.Block.ERASE)

func _on_start_button_pressed() -> void:
	game_started.emit()
