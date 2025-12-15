class_name ButtonNewGame extends ButtonBase

var start_scene: PackedScene

func _ready() -> void:
	super._ready()
	start_scene = preload("res://core/scenes/map_1/map_1.tscn")

func _on_pressed() -> void:
	get_tree().change_scene_to_packed(start_scene)
