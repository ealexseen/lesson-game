class_name ButtonStartMenu extends ButtonBase

func _on_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/menu.tscn")
	
