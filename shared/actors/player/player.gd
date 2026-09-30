extends CharacterBody2D
class_name Player

## Игрок. Движение считает сервер: владелец присылает ввод и предсказывает
## результат у себя, чтобы управление не ждало сети. Если сервер посчитал иначе,
## владелец возвращается к его позиции и пересчитывает неподтверждённые кадры.

@export var speed: float = 500.0 # speed
@export var jump_velocity: float = -400.0 # скорость прыжка
@export var friction: float = 0.15 # трение
@export var acceleration: float = 0.1 # ускорение
@export var bullet_schene: PackedScene
@export var walking_energy_change_per_1m := -0.005 # walking - потребление
@export var spawn: Marker2D

const REMOTE_SMOOTH_SPEED := 15.0 # плавность чужого игрока
const REMOTE_TELEPORT_DISTANCE := 300.0 # скачок сетевой цели — это телепорт
const VISIBILITY_RADIUS := 1500.0 # дальше не шлём чужое движение
const VISIBILITY_HYSTERESIS := 250.0 # чтобы не мигало на границе
## Радиус интереса решает сервер (WorldSync): далёким игрокам чужое движение не уходит.
const INTEREST_RADIUS_ENABLED := true

const RECONCILE_INTERVAL := 0.5 # как часто сервер подтверждает позицию
const RECONCILE_IGNORE := 4.0 # мельче этого расхождение не исправляем
const REPLAY_LIMIT := 120 # сколько кадров истории держим (около 2 с)
const INPUT_TIMEOUT := 0.5 # молчание владельца считаем нулевым вводом
const RECONCILE_ERROR := 32.0 # с такого расхождения пишем в лог сервера
const TELEPORT_GRACE := 0.4 # столько владелец не слушает поправки после переноса

@onready var equippable_item_holder: EquippableItemHolder = %EquippableItemHolder
@onready var camera: Camera2D = $Camera2D
@onready var net_target: Node2D = $NetTarget
@onready var nameplate: Label = $Nameplate

var peer_id: int = MatchState.OFFLINE_PEER_ID
var save_equippable_item_holder_position = Vector2.ZERO

var abilities: Dictionary = {}
var can_shoot: bool = true

# ввод, который применяется к игроку в этом кадре: у владельца — с клавиатуры,
# на сервере — из последнего сообщения владельца
var input_axis := 0.0
var input_jump := false
var input_seq := 0 # владелец нумерует свои кадры
var acked_seq := 0 # последний кадр, который сервер точно применил

var _send_elapsed := 0.0
var _reconcile_elapsed := 0.0
var _last_input_at := 0.0 # сервер: когда пришёл последний ввод владельца
var _reported_position := Vector2.ZERO # сервер: что владелец считает своим местом
var _history: Array[Dictionary] = [] # владелец: кадры для пересчёта
var _pending_reconcile: Dictionary = {}
var _teleport_grace_left := 0.0 # окно, в котором поправки движения игнорируются

# Получаем гравитацию из проекта
var gravity: float = ProjectSettings.get_setting('physics/2d/default_gravity')


func _enter_tree() -> void:
	# peer_id выставляет спавнер до добавления в дерево
	MatchState.register_player(self, peer_id)
	EventSystem.PLA_freeze_player.connect(_on_freeze_player)
	EventSystem.PLA_unfreeze_player.connect(_on_unfreeze_player)


func _exit_tree() -> void:
	MatchState.unregister_player(self)


func _ready() -> void:
	save_equippable_item_holder_position = equippable_item_holder.position
	camera.enabled = is_local()
	
	# цель стартует на месте появления, иначе чужая копия сначала поедет к нулю:
	# место появления детерминированное, поэтому у всех пиров оно одинаковое
	net_target.position = position
	
	_setup_nameplate()


## Ник и цвет показываем только у чужих игроков: своя табличка перед глазами мешает.
func _setup_nameplate() -> void:
	if is_local() or not MatchState.participants.has(peer_id):
		nameplate.visible = false
		return
	
	nameplate.text = MatchState.participant_name(peer_id)
	nameplate.add_theme_color_override("font_color", MatchState.participant_color(peer_id))
	nameplate.visible = true


## Локальный игрок — тот, чьим вводом управляет этот клиент.
func is_local() -> bool:
	return MatchState.local_player == self


func _process(_delta: float) -> void:
	if is_local():
		return
	
	# чужой игрок плавно едет за сетевой целью: её пишет сервер
	if position.distance_to(net_target.position) > REMOTE_TELEPORT_DISTANCE:
		position = net_target.position
	else:
		position = position.lerp(
			net_target.position,
			clampf(_delta * REMOTE_SMOOTH_SPEED, 0.0, 1.0)
		)


func _unhandled_key_input(event: InputEvent) -> void:
	if not is_local():
		return
	
	if event.is_action_pressed("open_crafting_menu"):
		EventSystem.UI_create.emit(UIConfig.Keys.CraftingMenu)
	elif event.is_action_pressed("esc"):	
		EventSystem.UI_create.emit(UIConfig.Keys.MenuGame)
	elif event.is_action_pressed("input_hot_key"):
		EventSystem.EQU_hotkey_pressed.emit(self, int(event.as_text()))


func _physics_process(_delta: float) -> void:
	if is_local():
		_owner_tick(_delta)
		return
	
	# сервер двигает чужих игроков сам, по вводу их владельцев
	if WorldSync.is_server():
		_server_tick(_delta)


# Владелец: предсказание своего движения

func _owner_tick(_delta: float) -> void:
	if _teleport_grace_left > 0.0:
		_teleport_grace_left -= _delta
	else:
		_apply_pending_reconcile(_delta)
	
	input_axis = Input.get_axis("left", "right")
	input_jump = Input.is_action_just_pressed("jump")
	input_seq += 1
	
	_apply_input(_delta)
	check_walking_energy_change(_delta)
	save_player()
	_record_history()
	
	if WorldSync.is_server():
		# одиночная игра и хост: истину движения пишем сами
		acked_seq = input_seq
		net_target.position = position
	else:
		_send_input(_delta)
	
	if Input.is_action_pressed("use_item"):
		equippable_item_holder.try_to_use_item()


## Кадр владельца: по этой истории пересчитываем движение после поправки сервера.
func _record_history() -> void:
	_history.append({
		"seq": input_seq,
		"position": position,
		"velocity": velocity,
		"axis": input_axis,
		"jump": input_jump,
	})
	
	while _history.size() > REPLAY_LIMIT:
		_history.pop_front()


func _send_input(_delta: float) -> void:
	# шлём каждый тик: тогда сервер применяет ровно тот же ввод, что и предсказание,
	# и расхождение не растёт из-за разной частоты (пакет маленький, 60 Гц терпимо)
	_send_elapsed = 0.0
	WorldSync.send_input(input_seq, input_axis, input_jump, position)


# Сервер: истина движения

func _server_tick(_delta: float) -> void:
	if _silent_too_long():
		input_axis = 0.0
		input_jump = false
	
	_apply_input(_delta)
	# прыжок — одноразовое событие, дальше это просто удержание кнопки
	input_jump = false
	save_player()
	net_target.position = position
	
	_reconcile_elapsed += _delta
	
	if _reconcile_elapsed < RECONCILE_INTERVAL:
		return
	
	_reconcile_elapsed = 0.0
	WorldSync.send_reconcile(peer_id, acked_seq, position)
	_report_divergence()


## Владелец может разойтись с нами — из-за потерь ввода или потому, что соврал.
## Его присланная позиция на истину не влияет, но расхождение видно в логе сервера.
func _report_divergence() -> void:
	# игрок уже вышел или ввода давно нет: сравнивать не с чем, это не расхождение
	if not MatchState.participants.has(peer_id) or _last_input_at <= 0.0 or _silent_too_long():
		return
	
	var divergence := position.distance_to(_reported_position)
	
	if divergence < RECONCILE_ERROR:
		return
	
	ServerLog.line("SERVER: расхождение с %s — %.0f px (наша позиция %s)" % [
		MatchState.participant_name(peer_id), divergence, position
	], ServerLog.COLOR_NOTICE)


func _silent_too_long() -> bool:
	if _last_input_at <= 0.0:
		return false
	
	return float(Time.get_ticks_msec()) / 1000.0 - _last_input_at > INPUT_TIMEOUT


## Сервер принял очередной ввод владельца.
func apply_remote_input(_seq: int, _axis: float, _jump: bool, _position: Vector2) -> void:
	input_seq = _seq
	acked_seq = _seq
	input_axis = _axis
	input_jump = _jump
	_reported_position = _position
	_last_input_at = float(Time.get_ticks_msec()) / 1000.0


## Владелец получил поправку: запоминаем и применим в начале следующего кадра.
func reconcile(_seq: int, _position: Vector2) -> void:
	# сразу после своего переноса поправка ещё описывает старое место — она не нужна
	if _teleport_grace_left > 0.0:
		return
	
	_pending_reconcile = {"seq": _seq, "position": _position}


## Перенос игрока: дверь, способность телепорта, возврат после падения с карты.
## Об этом должен узнать сервер, иначе его поправка вернёт игрока на прежнее место.
func teleport(_position: Vector2) -> void:
	if not is_local() and not WorldSync.is_server():
		# чужим игроком распоряжается сервер, у себя его двигать нельзя
		return
	
	position = _position
	velocity = Vector2.ZERO
	# история и незакрытые поправки относятся к прежнему месту
	_history.clear()
	_pending_reconcile.clear()
	_reported_position = position
	_teleport_grace_left = TELEPORT_GRACE
	
	if is_local() and not WorldSync.is_server():
		WorldSync.send_teleport(position)
		return
	
	net_target.position = position


## Сервер применил перенос, о котором попросил владелец.
func apply_remote_teleport(_position: Vector2) -> void:
	teleport(_position)
	ServerLog.line("SERVER: %s перенесён в %s" % [
		MatchState.participant_name(peer_id), _position
	])


func _apply_pending_reconcile(_delta: float) -> void:
	if _pending_reconcile.is_empty():
		return
	
	var acked: int = int(_pending_reconcile["seq"])
	var server_position: Vector2 = _pending_reconcile["position"]
	_pending_reconcile.clear()
	
	var index := _history_index(acked)
	
	if index < 0:
		# истории не хватает: принимаем позицию сервера как есть
		position = server_position
		velocity = Vector2.ZERO
		_history.clear()
		return
	
	if _history[index]["position"].distance_to(server_position) < RECONCILE_IGNORE:
		return
	
	# возвращаемся к подтверждённому кадру и пересчитываем всё, что сервер не подтвердил
	_history = _history.slice(index)
	_history[0]["position"] = server_position
	position = server_position
	velocity = _history[0]["velocity"]
	
	for i in range(1, _history.size()):
		var frame: Dictionary = _history[i]
		input_axis = frame["axis"]
		input_jump = frame["jump"]
		_apply_input(_delta)
		frame["position"] = position
		frame["velocity"] = velocity


func _history_index(_seq: int) -> int:
	for i in _history.size():
		if int(_history[i]["seq"]) == _seq:
			return i
	
	return -1


## Движение по вводу: одна и та же функция у владельца, сервера и при пересчёте.
func _apply_input(_delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravity * _delta
	
	if input_jump and is_on_floor():
		velocity.y = jump_velocity
	
	if input_axis != 0:
		velocity.x = lerp(velocity.x, input_axis * speed, acceleration)
	else:
		velocity.x = lerp(velocity.x, 0.0, friction)
	
	equippable_item_holder.direction_flip(int(signf(input_axis)))
	
	move_and_slide()


func check_walking_energy_change(_delta: float) -> void:
	if velocity.x:
		EventSystem.PLA_change_energy.emit(
			self,
			_delta *
			walking_energy_change_per_1m *
			Vector2(velocity.x, 0).length()
		)


func save_player() -> void:
	if position.y >= 2500 and spawn:
		teleport(spawn.position)


func move(_delta: float) -> void:
	# оставлено для совместимости: движение идёт через _apply_input
	_apply_input(_delta)


func shoot() -> void:
	if bullet_schene == null:
		return 
	
	can_shoot = false
	
	var bullet: Bullet = bullet_schene.instantiate()
	get_parent().add_child(bullet)
	
	bullet.global_position = global_position
	
	var mouse_direction = (get_global_mouse_position() - global_position).normalized()
	
	bullet._move(mouse_direction)
	
	await get_tree().create_timer(0.3).timeout
	
	can_shoot = true


func _on_freeze_player(_player: Player) -> void:
	if _player != self:
		return
	
	set_freeze(true)


func _on_unfreeze_player(_player: Player) -> void:
	if _player != self:
		return
	
	set_freeze(false)


func set_freeze(_value: bool) -> void:
	set_process(!_value)
	set_physics_process(!_value)
	set_process_input(!_value)
	set_process_unhandled_input(!_value)
