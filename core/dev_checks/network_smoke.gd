extends Node

## Раннер сетевого смоука.
##
## Создаёт пробу в корне дерева и сразу отдаёт ей управление: сама сцена раннера
## исчезает при переходе на карту, а проба должна пережить смену сцены.
## Отложенное добавление и страховочный таймаут нужны потому, что добавлять детей
## во время достройки сцены нельзя, а без пробы процесс иначе висел бы вечно.

const RUNNER_TIMEOUT := 30.0

var _elapsed := 0.0


func _ready() -> void:
	var probe := NetworkSmokeProbe.new()
	probe.name = "NetworkSmokeProbe"
	get_tree().root.add_child.call_deferred(probe)


func _process(_delta: float) -> void:
	# если проба так и не появилась, смены сцены не будет и раннер доживёт до этой страховки
	_elapsed += _delta
	
	if _elapsed >= RUNNER_TIMEOUT:
		print("SMOKE FAIL: раннер не передал управление пробе")
		get_tree().quit(1)
