extends Node

@onready var cursor_game: CursorGame = %CursorGame
@onready var cursor_menu: CursorMenu = %CursorMenu
@onready var stage_manager: Node = %StageManager


func _ready() -> void:
	EventSystem.UI_check_count.connect(on_ui_check_count)


func on_ui_check_count(_count: int) -> void:
	if _count: 
		_open_menu(true)
	else:
		_open_menu(false)

	
func _open_menu(value: bool) -> void:
	#get_tree().paused = value
	
	cursor_game.visible = !value
	cursor_menu.visible = value
