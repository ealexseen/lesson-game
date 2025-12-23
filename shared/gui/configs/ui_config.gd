class_name UIConfig

enum Keys {
	CraftingMenu = 1,
	MenuGame = 2,
	MenuBase = 3,
	MenuSettings = 4,
}

const UI_PATHS = {
	Keys.CraftingMenu: "res://shared/gui/components/player_menu/components/crafting_menu/crafting_menu.tscn",
	Keys.MenuGame: "res://shared/gui/components/navigations/navigation_game/navigation_game.tscn",
	Keys.MenuBase: "res://shared/gui/components/navigations/navigation_menu/navigation_menu.tscn",
	Keys.MenuSettings: "res://shared/gui/components/settings/settings.tscn"
}

static func get_ui(key: Keys) -> Control:
	return load(UI_PATHS.get(key)).instantiate()
