class_name Door extends InteractablesDoor


@export var door_to: Door

@onready var sprite_2d: Sprite2D = %Sprite2D
@onready var info: Label = %Info
@onready var point_prompt: Marker2D = %PointPrompt

var idle_color = Color(0.631, 0.271, 0.075)
var open_color = Color(1.0, 1.0, 1.0)

var player: Player = null

var _is_visit := false
var _is_open := false

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _input(event: InputEvent) -> void:
	if (!door_to): return
	if (event is InputEventKey):
		if not _is_visit: return
		
		if (event.pressed == true): return
		if (event.keycode == KEY_E):
			_open_door(!_is_open)
			
		if (event.keycode == KEY_UP or event.keycode == KEY_W):
			if (_is_open and player):
				player.position = Vector2(door_to.position.x, door_to.position.y - 70)
				
				_is_open = false
				_is_visit = false
				
				EventSystem.BUL_destroy_bulletin.emit(BulletinConfig.Keys.InteractionPrompt)
				
				door_to._open_door(true)
				door_to._init_prompt()
			


func _process(_delta: float) -> void:
	sprite_2d.modulate = open_color if _is_open else idle_color
	info.modulate = open_color if !_is_open else idle_color


func _init_prompt() -> void:
	if !_is_visit:
		set_prompt('Подойди к двери')
	elif _is_open:
		set_prompt('Hажми W или KEY_UP чтобы войти')
	else:
		set_prompt('Hажми E чтобы открыть')
		


func _open_door(value: bool) -> void:
	_is_open = value
	
	_init_prompt()


func _on_body_entered(_body: Node2D) -> void:
	if _body is Player:
		player = _body
		_is_visit = true
		
		_init_prompt()


func _on_body_exited(_body: Node2D) -> void:
	_is_visit = false
	player = null
	
	_init_prompt()
