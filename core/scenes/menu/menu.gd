extends Node2D


@onready var manager_ui: ManagerUI = %ManagerUi


func _ready() -> void:
	EventSystem.UI_create.emit(UIConfig.Keys.MenuBase)


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_ESCAPE:
				handle_escape()

func handle_escape() -> void:
	if manager_ui.items.has(UIConfig.Keys.MenuBase):
		return
	
	EventSystem.UI_replace.emit(UIConfig.Keys.MenuBase)
