class_name ServerLog extends RefCounted

## Журнал сервера: метка времени, единый формат, цвет в консоли и копия в файл.
##
## Функции статические: их можно звать и до готовности автолоадов, и в режиме --script.
## Пишет только серверная сторона — клиентские строки идут обычным print.

const LOG_DIR_NAME := "logs"
const KEEP_FILES := 14 # сколько файлов журнала храним
const COLOR_EVENTS := "green" # вход
const COLOR_LEAVE := "red" # выход
const COLOR_NOTICE := "yellow" # отказы и предупреждения
const COLOR_SUMMARY := "cyan" # сводка

## Цвет в консоли включается настройкой `color`, файл — настройкой `log_file`.
static var color_enabled := true
static var file_enabled := true

static var _file: FileAccess = null
static var _file_path := ""
static var _file_date := ""
static var _started := false


## Открыть файл журнала. Вызывает сервер при старте; повторные вызовы ничего не делают.
static func start() -> void:
	if _started:
		return
	
	_started = true
	_open_file()
	
	if _file_path != "":
		line("SERVER: журнал: %s" % _file_path)


static func stop() -> void:
	_started = false
	
	if _file != null:
		_file.close()
		_file = null


## Строка журнала: «[12:34:56] текст». Цвет виден только в консоли, в файл идёт текст.
static func line(_text: String, _color: String = "") -> void:
	var text := "[%s] %s" % [_stamp(), _text]
	
	if color_enabled and _color != "":
		print_rich("[color=%s]%s[/color]" % [_color, text])
	else:
		print(text)
	
	_write(text)


## Кто сейчас на сервере — для тех, кто смотрит в консоль.
static func summary(_text: String) -> void:
	line("SERVER: сводка — %s" % _text, COLOR_SUMMARY)


static func _stamp() -> String:
	var now := Time.get_time_dict_from_system()
	return "%02d:%02d:%02d" % [now["hour"], now["minute"], now["second"]]


static func _today() -> String:
	var date := Time.get_date_dict_from_system()
	return "%04d-%02d-%02d" % [date["year"], date["month"], date["day"]]


static func _open_file() -> void:
	if not file_enabled:
		return
	
	_file_date = _today()
	var path := _log_path(_file_date)
	
	# дописываем в сегодняшний файл: перезапуск сервера не должен стирать день,
	# а окно, которое следит за журналом, не должно терять позицию чтения
	if FileAccess.file_exists(path):
		_file = FileAccess.open(path, FileAccess.READ_WRITE)
		
		if _file != null:
			_file.seek_end()
	else:
		_file = FileAccess.open(path, FileAccess.WRITE)
	
	if _file != null:
		_file_path = _file.get_path()
		_separator()
		return
	
	# рядом с игрой писать не вышло (нет прав или папка только для чтения) —
	# уходим в пользовательскую папку движка, она writable всегда
	_file_path = "user://%s/server-%s.log" % [LOG_DIR_NAME, _file_date]
	DirAccess.make_dir_recursive_absolute(_file_path.get_base_dir())
	_file = FileAccess.open(_file_path, FileAccess.WRITE)
	
	if _file != null:
		_file_path = _file.get_path()
		_separator()
	else:
		_file_path = ""


## Метка без времени: по ней в файле видно, где начался очередной запуск сервера.
static func _separator() -> void:
	if _file == null:
		return
	
	if _file.get_length() > 0:
		_file.store_line("")
	
	_file.store_line("--- сервер запущен, журнал дописывается ---")
	_file.flush()


static func _log_path(_date: String) -> String:
	var file_name := "server-%s.log" % _date
	
	if OS.has_feature("editor"):
		var folder := "res://" + LOG_DIR_NAME
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
		return "%s/%s" % [folder, file_name]
	
	var folder := OS.get_executable_path().get_base_dir().path_join(LOG_DIR_NAME)
	DirAccess.make_dir_recursive_absolute(folder)
	return folder.path_join(file_name)


static func _write(_text: String) -> void:
	if _file == null:
		return
	
	# сервер живёт сутками: на смене даты заводим новый файл
	if _file_date != _today():
		_rotate()
	
	_file.store_line(_text)
	_file.flush()


static func _rotate() -> void:
	stop()
	_remove_old_files()
	_open_file()


## Держим последние KEEP_FILES файлов: старые удаляем, чтобы папка не росла вечно.
static func _remove_old_files() -> void:
	var dir := DirAccess.open(_log_path(_today()).get_base_dir())
	
	if dir == null:
		return
	
	var names: Array[String] = []
	
	for name in dir.get_files():
		if name.begins_with("server-") and name.ends_with(".log"):
			names.append(name)
	
	if names.size() <= KEEP_FILES:
		return
	
	names.sort()
	
	for index in names.size() - KEEP_FILES:
		dir.remove(names[index])
