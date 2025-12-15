class_name StagesConfig extends Node

enum Keys {
	Level1
}

const STAGES_PATHS := {
	Keys.Level1: "res://core/stages/levels/level_1.tscn"
}

static func get_stage(key: Keys) -> Node:
	return load(STAGES_PATHS.get(key)).instantiate()
