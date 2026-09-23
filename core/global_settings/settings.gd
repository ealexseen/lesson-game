class_name GameSettings extends Node


signal settings_changed
signal settings_fullscreen_changed

const SUPPORTED_RESOLUTIONS = [
	Vector2i(1280, 720),   # 16:9 - HD
	Vector2i(1366, 768),   # 16:9 - HD / 720p
	Vector2i(1600, 900),   # 16:9 - HD+
	Vector2i(1920, 1080),   # 16:9 - Full HD / 1080p
	Vector2i(2560, 1440),   # 16:9 - 2K / QHD
	
	Vector2i(1920, 1200),   # 16:10
	
	Vector2i(800, 600),   # 4:3
	Vector2i(1024, 768),   # 4:3
	Vector2i(1152, 864),   # 4:3
	Vector2i(1280, 960),   # 4:3
	Vector2i(1400, 1050),   # 4:3
	Vector2i(1600, 1200),   # 4:3
]

var current_resolution := Vector2i(1920, 1080)
var fullscreen := true
var borderless := false
var vsync := false
var target_fps := 60

func _ready() -> void:
	load_settings()


func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		if event.is_pressed():
			if event.alt_pressed and event.keycode == KEY_ENTER:
				fullscreen = !fullscreen
				
				apply_fullscreen()
				
				settings_fullscreen_changed.emit(fullscreen)
				save_settings()


func save_settings():
	var config = ConfigFile.new()
	
	# Видео настройки
	config.set_value("video", "resolution_x", current_resolution.x)
	config.set_value("video", "resolution_y", current_resolution.y)
	config.set_value("video", "fullscreen", fullscreen)
	config.set_value("video", "borderless", borderless)
	config.set_value("video", "vsync", vsync)
	config.set_value("video", "target_fps", target_fps)
	
	var error = config.save("user://settings.cfg")
	if error != OK:
		push_error("Не удалось сохранить настройки: " + str(error))
	else:
		settings_changed.emit()


func load_settings():
	var config = ConfigFile.new()
	
	if config.load("user://settings.cfg") == OK:
		# Видео
		var res_x = config.get_value("video", "resolution_x", 1920)
		var res_y = config.get_value("video", "resolution_y", 1080)
		current_resolution = Vector2i(res_x, res_y)
		
		fullscreen = config.get_value("video", "fullscreen", true)
		borderless = config.get_value("video", "borderless", false)
		vsync = config.get_value("video", "vsync", true)
		target_fps = config.get_value("video", "target_fps", 60)
		
		apply_video_settings()
	else:
		save_settings()
		apply_video_settings()


func apply_video_settings():
	apply_fullscreen()
	apply_fps()
	apply_vsync()


func apply_fullscreen() -> void:
	if fullscreen:
		get_window().set_mode(Window.MODE_FULLSCREEN)
	else:
		current_resolution = SUPPORTED_RESOLUTIONS[7]
		
		get_window().set_mode(Window.MODE_WINDOWED)
		get_window().set_size(current_resolution)
		center_window()


func apply_vsync() -> void:
	# VSync
	DisplayServer.window_set_vsync_mode(
		DisplayServer.VSYNC_ENABLED if vsync 
		else DisplayServer.VSYNC_DISABLED
	)


func apply_fps() -> void:
	if target_fps == 0:
		target_fps = 60
	
	# FPS ограничение
	Engine.max_fps = target_fps


func center_window():
	var Center_Screen = DisplayServer.screen_get_position()+DisplayServer.screen_get_size()/2
	var Window_Size = get_window().get_size_with_decorations()
	get_window().set_position(Center_Screen - Window_Size/2)


func get_resolution_list() -> Array[String]:
	var list: Array[String] = []
	for res in SUPPORTED_RESOLUTIONS:
		list.append("%d x %d (%s)" % [res.x, res.y, get_aspect_ratio(res.x, res.y)])
	return list


# Установить разрешение по индексу
func set_resolution_by_index(index: int):
	if index >= 0 and index < SUPPORTED_RESOLUTIONS.size():
		current_resolution = SUPPORTED_RESOLUTIONS[index]
		
		get_window().set_size(current_resolution)
		center_window()
		save_settings()

# Получить текущий индекс разрешения
func get_current_resolution_index() -> int:
	return SUPPORTED_RESOLUTIONS.find(current_resolution)


# Проверка соотношения сторон
func get_aspect_ratio(width: int, height: int) -> String:
	var ratio = float(width) / height
	if abs(ratio - 1.777) < 0.01: return "16:9"
	if abs(ratio - 1.333) < 0.01: return "4:3"
	if abs(ratio - 1.6) < 0.01: return "16:10"
	if abs(ratio - 2.333) < 0.01: return "21:9"
	return "custom"
