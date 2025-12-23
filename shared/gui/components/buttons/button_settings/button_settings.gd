extends ButtonBase

func _on_pressed() -> void:
	EventSystem.UI_replace.emit(UIConfig.Keys.MenuSettings)
