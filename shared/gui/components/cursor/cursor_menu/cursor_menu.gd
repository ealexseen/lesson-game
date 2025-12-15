class_name CursorMenu extends Node2D


func _process(_delta: float) -> void:
	DisplayServer.mouse_set_mode(DisplayServer.MOUSE_MODE_HIDDEN)
	global_position = get_global_mouse_position()
