# AGENTS.md — LessonGame

2D-игра на **Godot 4.6** (GDScript). Целевая версия — только 4.6 (`config/features` в `project.godot`); API 3.x и ранних 4.x не использовать. Общение с пользователем — по-русски, код и имена — по-английски.

## Мультиплеер: где мы сейчас

Кооп до 20 игроков на listen-server (порт 8910), этапы M0–M5 из `docs/multiplayer_plan.md` закрыты:

- лобби: ник, адрес, необязательный пароль, список игроков, поиск в локальной сети (порт 8911);
- игроки в мире: детерминированный спавн, репликация движения, ники и цвета;
- мир живёт на сервере: урон, смерть объектов и мобов, спавн лута, подбор предмета (кто первый), снапшот для позднего входа;
- своё движение рассылается только тем, кто ближе `VISIBILITY_RADIUS = 1500` px и уже на карте;
- экипировка, сторона взгляда и анимация использования репликуются, а эффекты предметов применяет только владелец;
- выход игрока убирает персонажа, выход хоста возвращает клиента в меню.

Не синхронизируются: пули (в игре пока не используются) и запасы здоровья/маны чужих игроков (они нигде не показываются). Подробности, замеры трафика и открытые идеи — в `docs/multiplayer_plan.md`.

Дальше по плану — **M6 «Выделенный сервер»**: пока только описание этапа (M6.1 режим `--server` без локального игрока, M6.2 обвязка и эксплуатация, M6.3 DTLS и аутентификация, M6.4 серверная симуляция движения). Кода ещё нет.

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
- Сетевой смоук (этапы M1–M5): `res://core/dev_checks/network_smoke.tscn`, аргументы после `--` — `--autohost --name=Host --password=secret` [+ `--start-game` | `--solo-start` | `--stress`] [+ `--world`], `--autoconnect=127.0.0.1 --password=secret` [+ `--expect-game`] [+ `--world`], `--autoconnect=127.0.0.1 --password=wrong --expect-reject`, `--lan-search`, `--bot --hold=N` (бот для стресса). Успех — `SMOKE CLIENT CONNECTED`, `SMOKE CLIENT REJECTED: …`, `SMOKE LAN FOUND n`, `SMOKE CLIENT SEES MOTION`, `SMOKE CLIENT NAMEPLATE: ник цвет` (цвет обязан совпасть с `SMOKE HOST COLOR`), `SMOKE CLIENT SEES TREE GONE`, `SMOKE CLIENT WORLD OK`, `SMOKE STRESS OK`, `SMOKE BOT DONE`. Новый `class_name` требует предварительного `--headless --import`, иначе движок его не видит.
- Итог прогона пишется файлом: `--report=<имя>.txt` → `res://_dsh_reports/<имя>.txt` (папку создать заранее). Это надёжнее stdout: у процессов под `Start-Process` stdout буферизуется и хвост теряется. Много процессов удобно поднимать одним заданием (`Start-Process` в цикле), но одиночные прогоны надёжнее гонять через `& $godot ... *> файл` по одному процессу на задание.
- Урон и уничтожение в мире применяет только сервер (`WorldSync.is_server()`); в одиночной игре сервером считается сам игрок, поэтому логика одна на оба режима.
- Своё движение игрок рассылает только тем, кто ближе `VISIBILITY_RADIUS = 1500` px и уже на карте (`WorldSync.is_peer_in_world`), серверу — всегда. Радиус меняется в `shared/actors/player/player.gd`.
- Экипировка, сторона взгляда и использование предмета — тоже сетевое состояние: `EquippableItemHolder` рассылает `_remote_equip`/`_remote_unequip`/`_remote_flip`/`_remote_use` от владельца игрока. Эффекты предмета (урон, лечение) применяет только владелец: их вызывают дорожки анимации, поэтому `check_hit`/`consume`/`destroy_self` проверяют `is_owner_local()` — не убирай эту проверку, иначе чужая копия оружия бьёт второй раз. Проверки в смоуке: `SMOKE EQUIP CLIENT: <узел> face_right=<bool> own_empty=<bool>` и `SMOKE USE CLIENT: <узел> playing=true`.
- `--headless --quit` видит только то, что достижимо из главной сцены и автолоадов; скрипт из неиспользуемой сцены так не поймать.
- Два окна игры на одной машине конфликтуют за порт поиска в сети (8911): слушатель только один, второй ждёт освобождения и повторяет попытки каждые 2 с, поэтому список найденных игр может появиться на пару секунд позже. Подключение по адресу работает всегда.

Тестового фреймворка (GUT и подобных) в проекте нет — автотестов логики не существует, проверяй запуском.

## Не читать и не трогать

- `.godot/` — генерируемый кэш импорта (тысячи служебных файлов, шум в поиске).
- `build/` — экспортированные сборки (`v.0.0.X`), `.idea/` — IDE, `MyGame/` — хранилище заметок Obsidian (к игре не относится).
- Сцены и скрипты не переименовывать и не перемещать без необходимости: пути и `uid://` завязаны на сцены.

## Карта

- `project.godot` — автолоады `EventSystem` (`core/global_events/event_system.gd`, шина сигналов), `GlobalSettings` (`core/global_settings/settings.gd`), `MatchState` (`core/global_match/match_state.gd`, локальный игрок и участники матча), `NetworkManager` (`core/global_network/network_manager.gd`, ENet: хостинг, подключение, пароль, LAN-поиск, порт 8910) и `WorldSync` (`core/global_world/world_sync.gd`, авторитет над миром: удары, уничтожение, спавн лута, подбор, снапшот); главная сцена задана через `uid://`. InputMap: `jump`, `left`, `right`, `use_item`, `active`, `esc`, `open_crafting_menu`, `input_hot_key`. Слои 2D-физики: `player`, `ground`, `bullet`, `door`, `item`, `cursor`, `hitbox`, `big_rigid_pickuppable`, `small_rigid_pickuppable`, `static_body`, `actor`.
- `core/` — точки входа и этапы: `scenes/` (`menu`, `map_1`), `stages/` с `configs/`, `levels/`, `managers/` (`stage_manager`, `player_spawner`), `dev_checks/` (проверки запуском), `global_match/` (автолоад `MatchState`), `global_network/` (автолоад `NetworkManager` и `LanDiscovery`), `global_world/` (автолоад `WorldSync`).
- `shared/` — вся игровая логика: `actors/` (player + `camera/`, `ray_cast/`, `managers/`, `equippable_item_holder/`; `animals/`), `objects/` (`abilities/`, `items/`, `blueprints/`, `environment/`, `door/`, `hitbox/`, `bullet/`, `ground/`), `gui/` (`components/`, `managers/`, `configs/`), `assets/`, `theme/`.
- Список игроков матча — `PlayerRoster` (`shared/gui/components/player_roster/`): ник, цвет, пинг, пометки «вы»/«хост»; общий узел для лобби и игрового меню, обновляется сам.
- Именование по роли: `configs/*_config.gd` — конфиги, `resources/*_resource.gd` — данные-ресурсы, `managers/*_manager/*.gd` — менеджеры, `*_base.gd` и `*_template.gd` — базовые классы.
- [`docs/multiplayer_plan.md`](docs/multiplayer_plan.md) — план мультиплеера (кооп, listen-server, до 20 игроков): **начинать чтение с §0 «Кратко»** — там базовый контекст, принципы, что реализовано и что дальше; ниже решения, этапы M0–M5 (выполнены), замеры трафика и спланированный, но не начатый M6 «Выделенный сервер».
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
