extends SceneTree

## Пишет шаблон настроек выделенного сервера в файл: сборка кладёт рядом с игрой
## тот же server.cfg, что сервер создаёт сам, поэтому шаблон живёт в одном месте —
## в ServerConfig.TEMPLATE.
##
## Запуск: --script res://core/dev_checks/write_server_config.gd -- <путь>

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	
	if args.is_empty():
		print("WRITE SERVER CONFIG: не указан путь")
		quit(1)
		return
	
	var path: String = str(args[0])
	var file := FileAccess.open(path, FileAccess.WRITE)
	
	if file == null:
		print("WRITE SERVER CONFIG: не удалось открыть «%s»" % path)
		quit(1)
		return
	
	file.store_string(ServerConfig.TEMPLATE)
	file.close()
	print("WRITE SERVER CONFIG: %s" % path)
	quit()
