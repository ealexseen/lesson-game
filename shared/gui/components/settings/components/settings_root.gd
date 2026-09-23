extends MarginContainer

@onready var tabs: TabBar = %Tabs
@onready var settings_container: ScrollContainer = %SettingsContainer
@onready var controls_container: ScrollContainer = %ControlsContainer

func _ready() -> void:
	tabs.tab_selected.connect(_on_tab_selected)


func _on_tab_selected(tab: int) -> void:
	settings_container.hide()
	controls_container.hide()
	
	if tab == 0:
		settings_container.show()
	
	if tab == 1:
		controls_container.show()


func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("esc"):
		EventSystem.UI_last.emit()
