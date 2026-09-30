class_name ServerConfig extends RefCounted

## Настройки выделенного сервера из файла конфигурации (server.cfg).
##
## Аргументы командной строки перекрывают файл: ярлык запускает сервер с одним
## --config, а разовый прогон может добавить своё сверху.

const FILE_NAME := "server.cfg"
const SECTION := "server"

const TEMPLATE := """; Настройки выделенного сервера LessonGame.
; Запуск: ярлык run_server.bat (или LessonGame.console.exe --headless -- --server).
; Аргументы командной строки перекрывают этот файл.

[server]
; как сервер виден в списке игр локальной сети
name="Выделенный сервер"

; игровой порт UDP; клиенты указывают адрес как host:port
port=8910

; пусто — вход свободный
password=""

; пусто — админ-команды выключены (см. docs/dedicated_server.md)
admin_token=""

; сколько игроков ждать до автостарта матча
min_players=1

; предел участников, не больше 20 (сервер не занимает место среди игроков)
max_players=20

; шифрование канала; клиенты при этом должны запускаться с --dtls
dtls=false

; писать журнал в файл logs/server-ГГГГ-ММ-ДД.log рядом с игрой
log_file=true

; цветные строки в консоли (в файл журнала цвета не попадают)
color=true
"""

var path := ""
var created := false
var config := ConfigFile.new()


## Где лежит файл: рядом с игрой, а при запуске из редактора — в корне проекта.
static func default_path() -> String:
	if OS.has_feature("editor"):
		return "res://" + FILE_NAME
	
	return OS.get_executable_path().get_base_dir().path_join(FILE_NAME)


## Прочитать настройки; если файла нет — написать шаблон с подсказками.
static func load_or_create(_path: String) -> ServerConfig:
	var loaded := ServerConfig.new()
	loaded.path = _path
	
	if not FileAccess.file_exists(_path):
		loaded.created = _write_template(_path)
	
	loaded.config.load(_path)
	return loaded


static func _write_template(_path: String) -> bool:
	var file := FileAccess.open(_path, FileAccess.WRITE)
	
	if file == null:
		return false
	
	file.store_string(TEMPLATE)
	file.close()
	return true


func get_string(_key: String, _default: String) -> String:
	return str(config.get_value(SECTION, _key, _default))


func get_int(_key: String, _default: int) -> int:
	return int(config.get_value(SECTION, _key, _default))


func get_bool(_key: String, _default: bool) -> bool:
	return bool(config.get_value(SECTION, _key, _default))
