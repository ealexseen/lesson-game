class_name ButtonBase extends Button

const ANIMATION_DURATION := 0.1

var _tween: Tween

func _ready() -> void:
	connect("mouse_entered", _on_mouse_entered)
	connect("mouse_exited", _on_mouse_exited)
	connect("pressed", _on_pressed)


func _on_mouse_entered() -> void:
	pivot_offset = size / 2
	_set_scale(1.1)


func _on_mouse_exited() -> void:
	_set_scale(1)


func _on_pressed() -> void:
	print_debug('pressed')


func _get_tween() -> Tween:
	if _tween:
		_tween.kill()
	_tween = create_tween()
	return _tween


func _set_scale(_size: float) -> void:
	var _scale = Vector2(_size, _size)
	var tween = _get_tween()
	
	tween.tween_property(self, 'scale', _scale, ANIMATION_DURATION)
	tween.set_ease(Tween.EASE_OUT)
