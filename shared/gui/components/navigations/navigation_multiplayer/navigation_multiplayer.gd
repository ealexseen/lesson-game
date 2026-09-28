class_name NavigationMultiplayer extends NavigationBase

## Лобби: создать игру или подключиться к ней.
## Игроки появляются в мире на следующем этапе (M2), пока лобби показывает только состав.

const DEFAULT_ADDRESS := "127.0.0.1"

@onready var name_input: LineEdit = $PanelContainer/VBoxContainer/NameRow/NameInput
@onready var address_input: LineEdit = $PanelContainer/VBoxContainer/AddressRow/AddressInput
@onready var password_input: LineEdit = $PanelContainer/VBoxContainer/PasswordRow/PasswordInput
@onready var host_button: ButtonBase = $PanelContainer/VBoxContainer/ButtonsRow/HostButton
@onready var join_button: ButtonBase = $PanelContainer/VBoxContainer/ButtonsRow/JoinButton
@onready var status_label: Label = $PanelContainer/VBoxContainer/StatusLabel
@onready var players_list: ItemList = $PanelContainer/VBoxContainer/PlayersList
@onready var lan_list: ItemList = $PanelContainer/VBoxContainer/LanList
@onready var back_button: ButtonBase = $PanelContainer/VBoxContainer/BackButton


func _ready() -> void:
	name_input.text = NetworkManager.player_name
	address_input.text = DEFAULT_ADDRESS
	_set_status("")
	
	host_button.pressed.connect(_on_host_pressed)
	join_button.pressed.connect(_on_join_pressed)
	back_button.pressed.connect(_on_back_pressed)
	lan_list.item_activated.connect(_on_lan_host_activated)
	
	NetworkManager.server_started.connect(_on_server_started)
	NetworkManager.server_stopped.connect(_on_server_stopped)
	NetworkManager.connection_succeeded.connect(_on_connection_succeeded)
	NetworkManager.connection_failed.connect(_on_connection_failed)
	NetworkManager.server_disconnected.connect(_on_server_disconnected)
	NetworkManager.join_rejected.connect(_on_join_rejected)
	NetworkManager.lan.servers_changed.connect(_refresh_servers)
	MatchState.participants_changed.connect(_refresh_players)
	
	NetworkManager.start_lan_search()
	_refresh_buttons()
	_refresh_players()
	_refresh_servers(NetworkManager.lan.get_servers())


func _exit_tree() -> void:
	NetworkManager.stop_lan_search()


func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("esc"):
		_leave_lobby()


func _on_host_pressed() -> void:
	_apply_name()
	_set_status("")
	
	var error := NetworkManager.host_game(name_input.text, password_input.text)
	
	if error != "":
		_set_status(error)
		return
	
	_refresh_buttons()


func _on_join_pressed() -> void:
	_apply_name()
	_set_status("Подключение к %s…" % address_input.text.strip_edges())
	
	var error := NetworkManager.join_game(address_input.text, name_input.text, password_input.text)
	
	if error != "":
		_set_status(error)
		return
	
	_refresh_buttons()


func _on_back_pressed() -> void:
	_leave_lobby()


func _on_lan_host_activated(_index: int) -> void:
	var address = lan_list.get_item_metadata(_index)
	
	if address is String:
		address_input.text = address
		_set_status("Адрес найденной игры: %s" % address)


func _leave_lobby() -> void:
	if NetworkManager.is_connected_to_game():
		NetworkManager.disconnect_game()
	
	NetworkManager.stop_lan_search()
	EventSystem.UI_last.emit()


func _apply_name() -> void:
	NetworkManager.player_name = name_input.text


func _set_status(_text: String) -> void:
	status_label.text = _text


func _refresh_buttons() -> void:
	var connected := NetworkManager.is_connected_to_game()
	
	host_button.disabled = connected
	join_button.disabled = connected
	name_input.editable = not connected
	address_input.editable = not connected
	password_input.editable = not connected


func _refresh_players() -> void:
	players_list.clear()
	
	var ids := MatchState.participants.keys()
	ids.sort()
	
	for peer_id in ids:
		var host_mark := " (хост)" if peer_id == 1 else ""
		players_list.add_item("%s%s" % [MatchState.participants[peer_id], host_mark])


func _refresh_servers(_servers: Dictionary) -> void:
	lan_list.clear()
	
	var addresses := _servers.keys()
	addresses.sort()
	
	for address in addresses:
		var info: Dictionary = _servers[address]
		var lock_mark := " (с паролем)" if info.get("has_password", false) else ""
		
		lan_list.add_item("%s — %s (%d/%d)%s" % [
			info.get("name", "Игра"),
			address,
			int(info.get("players", 1)),
			int(info.get("max", MatchState.MAX_PLAYERS)),
			lock_mark,
		])
		lan_list.set_item_metadata(lan_list.item_count - 1, address)


func _on_server_started() -> void:
	_set_status("Игра создана, порт %d. Ожидание игроков…" % NetworkManager.DEFAULT_PORT)
	_refresh_buttons()


func _on_server_stopped() -> void:
	_set_status("Игра остановлена")
	_refresh_buttons()


func _on_connection_succeeded() -> void:
	_set_status("Подключено")
	_refresh_buttons()


func _on_connection_failed(_reason: String) -> void:
	_set_status(_reason)
	_refresh_buttons()


func _on_server_disconnected(_reason: String) -> void:
	_set_status(_reason)
	_refresh_buttons()


func _on_join_rejected(_reason: String) -> void:
	_set_status(_reason)
	_refresh_buttons()
