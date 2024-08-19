extends Node2D
class_name BlockManager

@export var table: PackedScene
@export var table_preview: Texture2D
@export var chest: PackedScene
@export var chest_preview: Texture2D
@export var anvil: PackedScene
@export var anvil_preview: Texture2D
@export var cauldron: PackedScene
@export var cauldron_preview: Texture2D
@export var erase_preview: Texture2D

@onready var preview: Sprite2D = $preview

signal block_placed(mouse_position: Vector2, block: Block, scene: PackedScene)
signal block_removed(mouse_position: Vector2)

enum Block { NONE, TABLE, CHEST, ANVIL, CAULDRON, ERASE }

var block_map: Dictionary
var selected_block: Block = Block.NONE

func _ready() -> void:
	block_map = {
		Block.TABLE: { "scene": table, "preview": table_preview },
		Block.CHEST: { "scene": chest, "preview": chest_preview },
		Block.ANVIL: { "scene": anvil, "preview": anvil_preview },
		Block.CAULDRON: { "scene": cauldron, "preview": cauldron_preview },
		Block.ERASE: { "scene": null, "preview": erase_preview },
	}

func _input(event: InputEvent) -> void:
	if Input.is_action_just_pressed("ui_click"):
		print("click received", selected_block)
		if selected_block == Block.NONE:
			return
		elif selected_block == Block.ERASE:
			var mouse_pos = snap_to_grid(get_global_mouse_position())
			block_removed.emit(mouse_pos)
		else:
			var mouse_pos = snap_to_grid(get_global_mouse_position())
			var block_scene = block_map[selected_block]["scene"]
			block_placed.emit(mouse_pos, selected_block, block_scene)

func snap_to_grid(position: Vector2, grid_size: int = 16, center: bool = true) -> Vector2:
	var offset = grid_size / 2 if center else 0
	return Vector2(
		floor(position.x / grid_size) * grid_size + offset,
		floor(position.y / grid_size) * grid_size + offset,
	)

func _process(delta: float) -> void:
	preview.position = snap_to_grid(get_global_mouse_position())

func _on_hud_pallete_item_selected(pallete_item: Block) -> void:
	selected_block = pallete_item
	if pallete_item in [Block.NONE]:
		preview.texture = null
		return
	var dict = block_map[pallete_item]
	preview.texture = dict["preview"]
