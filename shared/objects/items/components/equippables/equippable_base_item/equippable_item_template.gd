class_name EquippableItemTemplate extends Node2D

## Предмет в руках. Анимацию использования видят все, а эффекты (урон, лечение)
## применяет только владелец: их вызывают дорожки анимации, поэтому каждая
## эффектная функция сама проверяет, чья это копия.

@onready var animation_player: AnimationPlayer = $AnimationPlayer

var owner_player: Player


## true, если анимация действительно началась: по этому признаку владелец
## рассылает остальным «я использую предмет».
func try_to_use() -> bool:
	if animation_player.is_playing():
		return false
	
	animation_player.play('use_item')
	return true


func is_owner_local() -> bool:
	return owner_player != null and owner_player.is_local()
