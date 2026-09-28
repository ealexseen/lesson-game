extends Node

## Проверка изоляции игровых событий по игроку-владельцу (этап M0 плана мультиплеера).
##
## Загружает map_1, подселяет второго игрока и проверяет, что события чужого игрока
## не доходят до локального, а свои — доходят. Запуск:
##   godot --headless --path . res://core/dev_checks/players_isolation_check.tscn
## Успех — "M0 CHECK: OK" и код 0, иначе список провалов и код 1.

const CHECK_FRAME := 5

var _map: Node
var _failures: Array[String] = []
var _frames := 0


func _ready() -> void:
	_map = load("res://core/scenes/map_1/map_1.tscn").instantiate()
	add_child(_map)


func _process(_delta: float) -> void:
	_frames += 1
	if _frames < CHECK_FRAME:
		return
	
	set_process(false)
	_run_checks()
	_finish()


func _finish() -> void:
	remove_child(_map)
	_map.free()
	
	if _failures.is_empty():
		print("M0 CHECK: OK")
		get_tree().quit(0)
	else:
		for failure in _failures:
			print("M0 CHECK FAIL: ", failure)
		get_tree().quit(1)


func _need(_condition: bool, _message: String) -> void:
	if not _condition:
		_failures.append(_message)


func _run_checks() -> void:
	var player: Player = MatchState.local_player
	_need(player != null, "MatchState.local_player установлен")
	
	if player == null:
		return
	
	_need(MatchState.player_count() == 1, "в матче ровно один игрок, а не %d" % MatchState.player_count())
	_need(player.is_local(), "единственный игрок считается локальным")
	_need(player.camera.enabled, "камера локального игрока включена")
	
	var inventory: Node = player.get_node("Managers/ManagerInventory")
	var stats: Node = player.get_node("Managers/PlayerStatsManager")
	var holder: Node = player.get_node("EquippableItemHolder")
	
	var hotbar_slots: Node = _map.get_node_or_null(
		"UILayer/Hud/MarginContainer/HotBar/MarginContainer/HBoxContainer"
	)
	_need(hotbar_slots != null, "найден контейнер слотов хотбара в HUD")
	
	if hotbar_slots != null:
		_need(
			hotbar_slots.get_child(0).item_key == ItemConfig.Keys.Axe,
			"HUD-хотбар получил данные локального игрока"
		)
	
	# второй игрок: его события не должны доходить до первого
	var other: Player = load("res://shared/actors/player/player.tscn").instantiate()
	_map.add_child(other)
	
	_need(other.peer_id != player.peer_id, "второй игрок получил свободный peer_id")
	_need(MatchState.player_count() == 2, "в матче два игрока, а не %d" % MatchState.player_count())
	_need(not other.camera.enabled, "камера чужого игрока выключена")
	
	var free_slots_before: int = inventory.get_free_slots()
	var energy_before: float = stats.current_energy
	
	EventSystem.INV_add_item.emit(other, ItemConfig.Keys.Coin)
	EventSystem.PLA_change_energy.emit(other, -10.0)
	EventSystem.EQU_equip_item.emit(other, ItemConfig.Keys.Axe)
	
	_need(inventory.get_free_slots() == free_slots_before, "чужое событие не изменило мой инвентарь")
	_need(is_equal_approx(stats.current_energy, energy_before), "чужое событие не изменило мою энергию")
	_need(holder.current_item == null, "чужое событие не экипировало предмет у меня")
	
	EventSystem.INV_add_item.emit(player, ItemConfig.Keys.Coin)
	EventSystem.PLA_change_energy.emit(player, -10.0)
	EventSystem.EQU_equip_item.emit(player, ItemConfig.Keys.Axe)
	
	_need(
		inventory.get_free_slots() == free_slots_before - 1,
		"моё событие попало в мой инвентарь"
	)
	_need(
		is_equal_approx(stats.current_energy, energy_before - 10.0),
		"моё событие изменило мою энергию"
	)
	_need(holder.current_item != null, "моё событие экипировало предмет")
