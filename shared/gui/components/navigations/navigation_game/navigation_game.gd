class_name NavigationGame extends NavigationBase

func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("esc"):
		EventSystem.UI_destroy.emit(UIConfig.Keys.MenuGame)
