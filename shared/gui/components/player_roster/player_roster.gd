class_name PlayerRoster extends ItemList

## Список игроков матча: ник, цвет, пинг и пометки «вы»/«хост».
##
## Сам обновляется при изменении состава и раз в секунду — пинг живой.

const REFRESH_INTERVAL := 1.0

var _elapsed := 0.0


func _ready() -> void:
	MatchState.participants_changed.connect(refresh)
	refresh()


func _process(_delta: float) -> void:
	if not is_visible_in_tree():
		return
	
	_elapsed += _delta
	
	if _elapsed < REFRESH_INTERVAL:
		return
	
	_elapsed = 0.0
	refresh()


func refresh() -> void:
	clear()
	
	# на выделенном сервере «хоста» среди участников нет — поясняем это строкой
	if MatchState.is_dedicated_server:
		add_item("Выделенный сервер — игроков %d" % MatchState.participants.size())
		set_item_selectable(item_count - 1, false)
		set_item_custom_fg_color(item_count - 1, Color(0.7, 0.7, 0.7))
	
	var ids := MatchState.participants.keys()
	ids.sort()
	
	for peer_id in ids:
		add_item(_line(peer_id))
		set_item_custom_fg_color(item_count - 1, MatchState.participant_color(peer_id))


func _line(_peer_id: int) -> String:
	var marks: Array[String] = []
	
	if MatchState.is_local_peer(_peer_id):
		marks.append("вы")
	
	if _peer_id == 1:
		marks.append("хост")
	
	var mark_text := " (%s)" % ", ".join(marks) if marks.size() else ""
	var ping := NetworkManager.peer_ping(_peer_id)
	var ping_text := "—" if ping < 0 else "%d мс" % ping
	
	return "%s%s — %s" % [MatchState.participant_name(_peer_id), mark_text, ping_text]
