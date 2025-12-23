extends MarginContainer


@onready var resolution_option: OptionButton = %ResolutionOption
@onready var fps_option: OptionButton = %FPSOption
@onready var fullscreen_check: CheckBox = %FullscreenCheck
@onready var borderless_check: CheckBox = %BorderlessCheck
@onready var v_sync_check: CheckBox = %VSyncCheck

@onready var apply_button: Button = %ApplyButton
@onready var reset_button: Button = %ResetButton
@onready var back_button: Button = %BackButton
@onready var message_label: Label = %MessageLabel

signal disabled_btn(value: bool)

var settings: GameSettings


func _ready() -> void:
	settings = get_node("/root/GlobalSettings")
	
	if not settings:
		push_error("GameSettings не найден!")
		return
	
	setup_ui()
	load_current_settings()
	
	resolution_option.item_selected.connect(_on_resolution_option_item_selected)
	fullscreen_check.toggled.connect(_on_fullscreen_check_toggled)
	borderless_check.toggled.connect(_on_borderless_check_toggled)
	v_sync_check.toggled.connect(_on_vsync_check_toggled)
	fps_option.item_selected.connect(_on_fps_option_item_selected)
	
	apply_button.pressed.connect(_on_apply_button_pressed)
	reset_button.pressed.connect(_on_reset_button_pressed)
	back_button.pressed.connect(_on_back_button_pressed)
	
	disabled_btn.connect(on_disabled_btn)


func on_disabled_btn(value: bool) -> void:
	apply_button.disabled = value
	reset_button.disabled = value
	back_button.disabled = value


func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("esc"):
		EventSystem.UI_last.emit()


func setup_ui():
	# Разрешения
	resolution_option.clear()
	for res_str in settings.get_resolution_list():
		resolution_option.add_item(res_str)
	
	# FPS ограничения
	fps_option.clear()
	fps_option.add_item("Неограниченно", 0)
	fps_option.add_item("30 FPS", 30)
	fps_option.add_item("60 FPS", 60)
	fps_option.add_item("120 FPS", 120)
	fps_option.add_item("144 FPS", 144)
	fps_option.add_item("240 FPS", 240)


func load_current_settings():
	# Разрешение
	var res_index = settings.get_current_resolution_index()
	
	if res_index != -1:
		resolution_option.selected = res_index
	
	# Видео настройки
	fullscreen_check.button_pressed = settings.fullscreen
	borderless_check.button_pressed = settings.borderless
	v_sync_check.button_pressed = settings.vsync
	
	# FPS
	for i in range(fps_option.item_count):
		if fps_option.get_item_id(i) == settings.target_fps:
			fps_option.selected = i
			break


# Сигналы UI элементов
func _on_resolution_option_item_selected(index: int):
	settings.set_resolution_by_index(index)


func _on_fullscreen_check_toggled(button_pressed: bool):
	settings.fullscreen = button_pressed
	if button_pressed:
		borderless_check.button_pressed = false
	settings.apply_video_settings()


func _on_borderless_check_toggled(button_pressed: bool):
	settings.borderless = button_pressed
	if button_pressed:
		fullscreen_check.button_pressed = false
	settings.apply_video_settings()


func _on_vsync_check_toggled(button_pressed: bool):
	settings.vsync = button_pressed
	settings.apply_video_settings()


func _on_fps_option_item_selected(index: int):
	settings.target_fps = fps_option.get_item_id(index)
	settings.apply_video_settings()


func _on_apply_button_pressed():
	settings.save_settings()
	show_message("Настройки применены!")


func show_message(text: String):
	message_label.text = text
	disabled_btn.emit(true)
	
	await get_tree().create_timer(2.0).timeout
	
	message_label.text = ''
	disabled_btn.emit(false)


func _on_reset_button_pressed():
	# Сброс к настройкам по умолчанию
	var default_settings: GameSettings = GameSettings.new()
	settings.current_resolution = default_settings.current_resolution
	settings.fullscreen = default_settings.fullscreen
	settings.borderless = default_settings.borderless
	settings.vsync = default_settings.vsync
	settings.target_fps = default_settings.target_fps
	
	load_current_settings()
	settings.apply_video_settings()
	show_message("Настройки сброшены!")


func _on_back_button_pressed():
	EventSystem.UI_last.emit()
