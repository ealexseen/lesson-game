class_name InteractablesDoor extends Area2D

@export var prompt := ''

var prompt_origin := ''

func set_prompt(value: String) -> void:
	prompt = value
	EventSystem.BUL_update_bulletin.emit(BulletinConfig.Keys.InteractionPrompt, self)
	

func set_origin_prompt() -> void:
	prompt = prompt_origin
