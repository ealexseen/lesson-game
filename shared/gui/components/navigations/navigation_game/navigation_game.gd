class_name NavigationGame extends NavigationBase

@onready var players_title: Label = $PanelContainer/VBoxContainer/PlayersTitle
@onready var players_list: ItemList = $PanelContainer/VBoxContainer/PlayersList


func _ready() -> void:
	# в одиночной игре состава игроков нет
	var in_match := NetworkManager.is_connected_to_game()
	players_title.visible = in_match
	players_list.visible = in_match


func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("esc"):
		EventSystem.UI_destroy.emit(UIConfig.Keys.MenuGame)
