extends Camera2D
class_name SmoothCamera

## Плавная камера: мёртвая зона (dead zone), границы уровня и сглаживание.
##
## Всё это — штатные свойства Camera2D, они настроены прямо в сцене игрока:
##
##   Position Smoothing — плавность догона (position_smoothing_speed, px/s);
##   Drag               — мёртвая зона: пока игрок внутри неё, камера стоит
##                        на месте, и он свободно уходит от центра экрана;
##   Limit              — Camera bounds: дальше этих границ камера не уезжает.
##
## Скрипт добавляет только то, чего у Camera2D нет: мгновенный перенос камеры,
## когда цель телепортируется (двери, падение в пропасть, телепорт-абилка),
## иначе камера летела бы за игроком через всю карту.

@export var target: Node2D ## За кем следим. Пусто — берётся родитель.
@export var teleport_distance: float = 400.0 ## Скачок цели за один кадр дальше этого — это телепорт.

var _last_target_position := Vector2.ZERO


func _ready() -> void:
	if target == null:
		target = get_parent() as Node2D

	if is_instance_valid(target):
		_last_target_position = target.global_position


func _process(_delta: float) -> void:
	if not is_instance_valid(target):
		return

	var target_position := target.global_position

	if target_position.distance_to(_last_target_position) > teleport_distance:
		snap()
	else:
		_last_target_position = target_position


## Мгновенно перенести камеру к цели: сбросить мёртвую зону и сглаживание.
func snap() -> void:
	if not is_instance_valid(target):
		return

	_last_target_position = target.global_position
	reset_smoothing()
	force_update_scroll()
