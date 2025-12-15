extends RigidBody2D
class_name Bullet

@export var size = 2
@export var speed = 800
@export_enum('parent', 'child', 'child_level_2') var type = 'parent'
@onready var bullet: PackedScene = preload("res://shared/objects/bullet/bullet.tscn")

var first = true
var countMax = 2
var countCurrent = 0

func _ready() -> void:
	_setSize()
	pass


func _setSize() -> void:
	var value = Vector2(size, size)
	
	set_global_scale(value)


func _move(vector: Vector2) -> void:
	apply_impulse(vector * speed)


func _physics_process(_delta: float) -> void:
	_setSize()
	pass


func _bam(_size: float, vector: Vector2, _type: String) -> void:
	var _bullet: Bullet = bullet.instantiate()
	
	_bullet.size = _size
	_bullet.type = _type
	
	get_parent().add_child(_bullet)
	
	_bullet.global_position = global_position
	_bullet._move(vector)

func _bums(_type: String) -> void:
	if (countMax == countCurrent): return
	
	const UP = -90
	
	if (type == 'parent'):
		_bam(1.5, Vector2.from_angle(deg_to_rad(UP - 20)), _type)
		_bam(1.5, Vector2.from_angle(deg_to_rad(UP - 10)), _type)
		_bam(1.5, Vector2.from_angle(deg_to_rad(UP + 10)), _type)
		_bam(1.5, Vector2.from_angle(deg_to_rad(UP + 20)), _type)
	
	if (type == 'child'):
		_bam(1, Vector2.from_angle(deg_to_rad(UP - 10)), _type)
		_bam(1, Vector2.from_angle(deg_to_rad(UP + 10)), _type)
	
	countCurrent += 1

func _on_area_2d_body_entered(_body: Node2D) -> void:
	if type == 'parent':
		_bums('child')
		queue_free()
		
	if type == 'child':
		if (!first): 
			_bums('child_level_2')
			queue_free()
		
		first = false
	if type == 'child_level_2':
		if (!first): 
			queue_free()
		
		first = false
	pass
