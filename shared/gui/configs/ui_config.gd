class_name UIConfig

enum Keys {
	CraftingMenu,
	MenuGame
}

const UI_PATHS = {
	Keys.CraftingMenu: "res://shared/gui/components/player_menu/components/crafting_menu/crafting_menu.tscn",
	Keys.MenuGame: "res://shared/gui/components/navigations/navigation_game/navigation_game.tscn"
}

static func get_ui(key: Keys) -> Control:
	return load(UI_PATHS.get(key)).instantiate()
