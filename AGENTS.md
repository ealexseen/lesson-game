# AGENTS.md — LessonGame

2D-игра на **Godot 4.6** (GDScript). Целевая версия — только 4.6 (`config/features` в `project.godot`); API 3.x и ранних 4.x не использовать. Общение с пользователем — по-русски, код и имена — по-английски.

## Проверка изменений

Godot не в PATH; консольный вариант:

```
C:\Program Files\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe
```

Под песочницей DSH запуск требует перенаправить пользовательскую папку движка внутрь проекта, иначе Godot не сможет писать `user://` (логи, `settings.cfg`) и упадёт:

```powershell
$env:APPDATA = Join-Path (Get-Location) '.dsh_user'
```

Папка `.dsh_user/` в `.gitignore`. Без перенаправления прогоны возможны только с расширенными правами и запросом подтверждения.

- Загрузка проекта и всех достижимых скриптов: `--headless --path . --quit`. Это рабочий гейт: ошибки компиляции и импорта идут в stderr, успех — только баннер движка (проверено, exit 0).
- `--check-only --script res://<путь>.gd` для одиночного скрипта **даёт ложные ошибки** вида `Identifier not found: EventSystem` (автолоады в этом режиме недоступны) и возвращает exit 0 даже при ошибке — как проверка не годится.
- Запуск игры: тот же exe без `--headless`.
- Изоляция игровых событий по игроку (этап M0 мультиплеера): `--headless --path . res://core/dev_checks/players_isolation_check.tscn` — успех печатает `M0 CHECK: OK` (код 1 при провале).
- Сетевой смоук (этапы M1–M3): `res://core/dev_checks/network_smoke.tscn`, аргументы после `--` — `--autohost --name=Host --password=secret` [+ `--start-game`], `--autoconnect=127.0.0.1 --password=secret` [+ `--expect-game`], `--autoconnect=127.0.0.1 --password=wrong --expect-reject`, `--lan-search`. Успех — `SMOKE CLIENT CONNECTED`, `SMOKE CLIENT REJECTED: …`, `SMOKE LAN FOUND n`, `SMOKE CLIENT SEES MOTION`, `SMOKE CLIENT NAMEPLATE: ник цвет` (цвет обязан совпасть с `SMOKE HOST COLOR`). Новый `class_name` требует предварительного `--headless --import`, иначе движок его не видит. Два процесса одновременно запускаются двумя фоновыми заданиями по одному процессу в каждом: песочница запрещает `Start-Process` для второго.
- `--headless --quit` видит только то, что достижимо из главной сцены и автолоадов; скрипт из неиспользуемой сцены так не поймать.
- Два окна игры на одной машине конфликтуют за порт поиска в сети (8911): слушатель только один, второй ждёт освобождения и повторяет попытки каждые 2 с, поэтому список найденных игр может появиться на пару секунд позже. Подключение по адресу работает всегда.

Тестового фреймворка (GUT и подобных) в проекте нет — автотестов логики не существует, проверяй запуском.

## Не читать и не трогать

- `.godot/` — генерируемый кэш импорта (тысячи служебных файлов, шум в поиске).
- `build/` — экспортированные сборки (`v.0.0.X`), `.idea/` — IDE, `MyGame/` — хранилище заметок Obsidian (к игре не относится).
- Сцены и скрипты не переименовывать и не перемещать без необходимости: пути и `uid://` завязаны на сцены.

## Карта

- `project.godot` — автолоады `EventSystem` (`core/global_events/event_system.gd`, шина сигналов), `GlobalSettings` (`core/global_settings/settings.gd`), `MatchState` (`core/global_match/match_state.gd`, локальный игрок и участники матча) и `NetworkManager` (`core/global_network/network_manager.gd`, ENet: хостинг, подключение, пароль, LAN-поиск, порт 8910); главная сцена задана через `uid://`. InputMap: `jump`, `left`, `right`, `use_item`, `active`, `esc`, `open_crafting_menu`, `input_hot_key`. Слои 2D-физики: `player`, `ground`, `bullet`, `door`, `item`, `cursor`, `hitbox`, `big_rigid_pickuppable`, `small_rigid_pickuppable`, `static_body`, `actor`.
- `core/` — точки входа и этапы: `scenes/` (`menu`, `map_1`), `stages/` с `configs/`, `levels/`, `managers/` (`stage_manager`, `player_spawner`), `dev_checks/` (проверки запуском), `global_match/` (автолоад `MatchState`), `global_network/` (автолоад `NetworkManager` и `LanDiscovery`).
- `shared/` — вся игровая логика: `actors/` (player + `camera/`, `ray_cast/`, `managers/`, `equippable_item_holder/`; `animals/`), `objects/` (`abilities/`, `items/`, `blueprints/`, `environment/`, `door/`, `hitbox/`, `bullet/`, `ground/`), `gui/` (`components/`, `managers/`, `configs/`), `assets/`, `theme/`.
- Список игроков матча — `PlayerRoster` (`shared/gui/components/player_roster/`): ник, цвет, пинг, пометки «вы»/«хост»; общий узел для лобби и игрового меню, обновляется сам.
- Именование по роли: `configs/*_config.gd` — конфиги, `resources/*_resource.gd` — данные-ресурсы, `managers/*_manager/*.gd` — менеджеры, `*_base.gd` и `*_template.gd` — базовые классы.
- [`docs/multiplayer_plan.md`](docs/multiplayer_plan.md) — план мультиплеера (кооп, listen-server, до 20 игроков): согласованные решения, этапы M0–M5 (M0–M3 сделаны), следующий этап — M4.
- Мультиплеерный игрок: `PlayerSpawner` (`core/stages/managers/player_spawner/`) создаёт в узле `Players` (map_1) по игроку на каждого участника из `MatchState.participants` и отдаёт авторитет владельцу; позиция едет через `NetTarget` + `MultiplayerSynchronizer` внутри `player.tscn`, ник и цвет — через `Nameplate` (у локального игрока скрыт, цвет считает `MatchState.participant_color`), точка появления — маркер в группе `player_spawn`.

## Конвенции

- Отступы — табы, кодировка UTF-8 (`.editorconfig`).
- В начале файла `class_name X` + `extends`; типизируй поля и параметры (`var player: Player`, `_delta: float`), неиспользуемые параметры — с префиксом `_`.
- Экспортируемые поля группируй через `@export_category`; значения по умолчанию задавай в скрипте.
- Комментарии — короткие, по-русски; тексты в `assert()` — по-английски (образец: `shared/objects/abilities/components/ability_base/ability_base.gd`).
- Данные — через `Resource`/`@export`, а не хардкод в сценах.
- Межсистемные события — через автолоад `EventSystem`; локальные — обычными сигналами Node. Игровые сигналы (`PLA_*`, `INV_*`, `EQU_*`) первым аргументом несут игрока-владельца, подписчик обязан сравнить его со своим игроком (`MatchState.local_player` или `MatchState.find_owner_player(self)`) — иначе событие одного игрока сработает у всех.
- Ввод — только через действия InputMap, не через проверку клавиш; физика — через именованные слои, не через числа.
- Новый предмет или способность — копия ближайшего шаблона (`base_item`, `ability_base`), а не новая иерархия.
