class_name GameSettings extends Node


signal settings_changed

const SUPPORTED_RESOLUTIONS = [
	Vector2i(1024, 576),   # 16:9
	Vector2i(1152, 648),   # 16:9
	Vector2i(1280, 720),   # HD
	Vector2i(1366, 768),   # HD
	Vector2i(1600, 900),   # HD+
	Vector2i(1920, 1080),  # Full HD
	Vector2i(2560, 1440),  # 2K
	Vector2i(3840, 2160),  # 4K
]

var current_resolution := Vector2i(1920, 1080)
var fullscreen := true
var borderless := false
var vsync := true
var target_fps := 0  # 0 = неограниченно

func _ready() -> void:
	load_settings()


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
		target_fps = config.get_value("video", "target_fps", 0)
		
		apply_video_settings()


func apply_video_settings():
	var window = get_window()
	
	# Режим окна
	if fullscreen:
		window.mode = Window.MODE_FULLSCREEN
	elif borderless:
		window.mode = Window.MODE_EXCLUSIVE_FULLSCREEN
		window.borderless = true
	else:
		window.mode = Window.MODE_WINDOWED
		window.borderless = false
		window.size = current_resolution
		center_window()
	
	# VSync
	DisplayServer.window_set_vsync_mode(
		DisplayServer.VSYNC_ENABLED if vsync 
		else DisplayServer.VSYNC_DISABLED
	)
	
	# FPS ограничение
	Engine.max_fps = target_fps if target_fps > 0 else 0


func center_window():
	var window = get_window()
	var screen_size = DisplayServer.screen_get_size()
	var window_size = window.size
	var centered_position = (screen_size - window_size) / 2
	window.position = centered_position


func get_resolution_list() -> Array[String]:
	var list: Array[String] = []
	for res in SUPPORTED_RESOLUTIONS:
		list.append("%d x %d" % [res.x, res.y])
	return list

# Установить разрешение по индексу
func set_resolution_by_index(index: int):
	if index >= 0 and index < SUPPORTED_RESOLUTIONS.size():
		current_resolution = SUPPORTED_RESOLUTIONS[index]
		apply_video_settings()
		save_settings()

# Получить текущий индекс разрешения
func get_current_resolution_index() -> int:
	return SUPPORTED_RESOLUTIONS.find(current_resolution)
