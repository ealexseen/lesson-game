---
name: lesson-game-godot
description: Verification recipes for the LessonGame Godot 4.6 project — headless gates, smoke scenes, report files — plus how to look up exact Godot 4.6 engine API answers through Context7.
whenToUse: Use when verifying a change in LessonGame, when a Godot CLI run misbehaves, when a client cannot connect from another machine, or when an exact Godot 4.6 engine API detail is needed and guessing is not acceptable.
---

# LessonGame: проверка и справка по API

Проект — Godot 4.6 (GDScript). Тестового фреймворка нет: логика проверяется только запуском.

## Запуск движка

Godot не в PATH. Консольный вариант и обязательный редирект пользовательской папки:

```powershell
$godot = 'C:\Program Files\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe'
$env:APPDATA = Join-Path (Get-Location) '.dsh_user'   # иначе движок не пишет user:// и падает
```

`APPDATA` задаётся в том же процессе, что и запуск. Без редиректа — только с расширенными правами.

## Рабочий гейт

Загрузка проекта и всех достижимых скриптов — главная проверка компиляции и импорта:

```powershell
& $godot --headless --path . --quit *> gate.txt
```

Успех — только баннер движка, exit 0. Ошибки компиляции и импорта идут в stderr.

Чего гейт **не** видит: скрипты из недостижимых сцен (главная сцена + автолоады). Такой скрипт надо запускать напрямую, иначе ошибка пройдёт молча. Лобби — как раз такой случай: его скрипт компилируется только при загрузке сцены, поэтому после правок лобби проверяйте её отдельно.

## Смоук-сцены

Обе сцены запускаются headless, аргументы смоука идут после `--`. Запуск игры руками — тот же exe без `--headless`.

```powershell
# изоляция игровых событий по игроку (M0)
& $godot --headless --path . res://core/dev_checks/players_isolation_check.tscn

# сетевой смоук (M1–M6)
& $godot --headless --path . res://core/dev_checks/network_smoke.tscn -- <аргументы>

# лобби: гейт его не компилирует, поэтому проверяем загрузкой сцены
& $godot --headless --path . res://shared/gui/components/navigations/navigation_multiplayer/navigation_multiplayer.tscn --quit-after 120
```

Аргументы сетевого смоука:

| Роль | Аргументы |
|---|---|
| хост | `--autohost --name=Host [--password=secret]` и один из `--start-game` / `--solo-start` / `--stress`, плюс `[--world]` |
| клиент | `--autoconnect=127.0.0.1 [--password=secret] [--expect-game] [--world] [--watch-name=<ник>` либо `--watch-peer=<id>]` |
| отказ по паролю | `--autoconnect=127.0.0.1 --password=wrong --expect-reject` |
| поиск в локальной сети | `--lan-search` |
| бот для стресса | `--autoconnect=127.0.0.1 --bot --hold=N` |

Маркеры успеха: `M0 CHECK: OK`, `SMOKE CLIENT CONNECTED`, `SMOKE CLIENT REJECTED: …`, `SMOKE LAN FOUND n`, `SMOKE CLIENT SEES MOTION`, `SMOKE CLIENT SEES PEER n MOTION`, `SMOKE CLIENT NAMEPLATE: ник цвет` (цвет обязан совпасть с `SMOKE HOST COLOR`), `SMOKE CLIENT SEES TREE GONE`, `SMOKE CLIENT WORLD OK`, `SMOKE EQUIP CLIENT: <узел> face_right=<bool> own_empty=<bool>`, `SMOKE USE CLIENT: <узел> playing=true`, `SMOKE STRESS OK`, `SMOKE BOT DONE`. Провал — exit 1.

`--watch-name` / `--watch-peer` задают, за движением чьего игрока следить. Без них смоук смотрит только на хоста, а репликация между двумя клиентами (через релей) остаётся непроверенной — так и проскочил баг с поздним входом. Ник надёжнее id: peer_id в ENet случайный, а не «2, 3, 4…».

## Что ловит грабли

- `--check-only --script res://<путь>.gd` **не годится как проверка**: автолоады в этом режиме недоступны, отсюда ложные `Identifier not found: EventSystem`, и exit 0 даже при реальной ошибке.
- Новый `class_name` не виден движку, пока не выполнен `--headless --import`.
- stdout под `Start-Process` буферизуется и теряет хвост. Итог прогона надёжнее писать файлом: `--report=<имя>.txt` → `res://_dsh_reports/<имя>.txt` (папку создать заранее). Много процессов удобно поднимать одним заданием (`Start-Process` в цикле), но одиночный прогон надёжнее гонять через `& $godot ... *> файл` — по одному процессу на задание.
- Два окна игры конфликтуют за порт LAN-поиска 8911: слушатель только один, второй ждёт освобождения. Подключение по адресу работает всегда.
- Долгие прогоны (стресс с ботами, сеть) стоит уводить в фоновую задачу, а не ждать синхронно.
- **Чужой запущенный экземпляр игры занимает порт 8910**, и прогон падает с «Не удалось создать игру на порту 8910» (или клиент подключается к чужому лобби). Перед серией прогонов проверить: `Get-Process -Name 'Godot*'` и `netstat -ano -p UDP | Select-String '8910'`.
- `SMOKE FAIL: раннер не передал управление пробе` — это не падение игры, а страховка раннера (`RUNNER_TIMEOUT = 30` с). Она срабатывает там, где сцена не меняется, например когда клиент не смог подключиться: ENet замечает недоступный адрес примерно через 30 с, то есть позже страховки. Путь «хост недоступен» так не проверить.
- Не подключается **с другой машины** — это почти всегда не код: нужен разрешённый входящий UDP 8910/8911 в файрволе хоста и правильный адрес (при Hamachi/VPN — его IP). Полный чек-лист — §11 в `docs/multiplayer_plan.md`, хост показывает свои адреса в лобби.

## Выделенный сервер

```powershell
# сервер (без окна, без игрока за машиной), аргументы после --
& $godot --headless --path . -- --server [--min-players=2] [--password=secret] [--name=MyServer] [--admin-token=secret] [--dtls]

# проверка: два бота подключаются и играют
& $godot --headless --path . res://core/dev_checks/network_smoke.tscn -- --autoconnect=127.0.0.1 --name=Bot1 --bot --hold=12

# админ-команды (клиенту не нужно быть игроком, достаточно токена)
& $godot --headless --path . res://core/dev_checks/network_smoke.tscn -- --autoconnect=127.0.0.1 --name=Admin --admin-token=secret --admin-kick=Bot1
& $godot --headless --path . res://core/dev_checks/network_smoke.tscn -- --autoconnect=127.0.0.1 --name=Admin --admin-token=secret --admin-stop
```

Успех: сервер печатает `SERVER READY: порт 8910, игроков до 20, автостарт от N, админ-команды включены|выключены, DTLS включён|выключен` и `GAME STARTED: участников N`; боты — `SMOKE BOT DONE` с `players=N` (сервер в число игроков не входит), `dedicated=true` и `scene=map_1.tscn`. Кикнутый бот (`--expect-kick`) пишет `SMOKE CLIENT KICKED OK: <причина>`; после `--admin-stop` сервер печатает `SERVER STOPPED` и процесс завершается.

**DTLS:** флаг `--dtls` нужен **обеим** сторонам. Клиент с ним печатает `CLIENT: DTLS включён (код 0)`, сервер — `SERVER: DTLS включён (код 0)`. Обычный клиент к DTLS-серверу не проходит (это и есть негативная проверка шифрования), а в stderr сервера при этом сыплется `mbedtls error: returned -0x7700` и `ERROR: TLS handshake error: -30464` — ожидаемо.

**Настройки сервера:** читаются из `server.cfg` (создаётся при первом запуске), аргументы командной строки перекрывают файл. Проверка конфига: `--server --config=<путь>` → сервер печатает `SERVER: создан файл настроек …` (если файла не было) и `SERVER: настройки из …`, а в `SERVER READY` видны порт, лимит игроков и автостарт из файла. Свой порт проверяется ботом: `--autoconnect=127.0.0.1:<порт>`. Лаунчеры для запуска двойным кликом — `tools/server/run_server.bat` и `run_server_dev.bat`.

**Журнал сервера:** строки идут с меткой `[ЧЧ:ММ:СС]` и дублируются в `logs/server-ГГГГ-ММ-ДД.log` (в редакторе — в корне проекта, `logs/` в `.gitignore`). Маркеры для проверок: `SERVER: + <ник>`, `SERVER: - <ник>`, `<ник> вошёл в мир`, `SERVER: сводка — игроков N`, `ADMIN: кик`, `SERVER STOPPED`. В консоли строки цветные (ANSI), в файл цвета не попадают, поэтому читать журнал лучше из файла, а не из перенаправленного stdout.

**Серверная симуляция движения:** ввод владельца уходит на сервер каждый тик, сервер считает движение сам и рассылает истину, а владелец предсказывает и пересчитывает неподтверждённые кадры. Проверка подделки — бот с `--teleport` (прибавляет себе 2000 px): он печатает `SMOKE CLIENT TELEPORTS: …`, а сервер — `SERVER: расхождение с <ник> — N px (наша позиция …)`, и остаётся при своей позиции.

**Живой вывод в консоль.** В релизной сборке Godot не сбрасывает stdout на каждый `print` (`application/run/flush_stdout_on_print`), поэтому окно `run_server.bat` показывало только баннер движка, а строки сервера оставались в буфере — на этом легко решить, что сервер не запустился. В `project.godot` теперь `run/flush_stdout_on_print=true`; убирать нельзя, иначе консоль снова онемеет. Отладочная сборка (запуск из редактора) сбрасывает всегда, поэтому из редактора проблема не видна: проверять живой вывод нужно именно на собранной игре.

Сервер не завершается сам: в фоновом прогоне его нужно останавливать (`Stop-Process`), иначе он держит порт 8910. stdout под `Start-Process` буферизуется — ошибки читайте из stderr, итог — из отчётов (`--report`). Развёртывание (systemd/docker/файрвол) — §12 в `docs/multiplayer_plan.md`.

## Справка по API Godot 4.6 (Context7)

Если нужен точный ответ по API движка — брать его из Context7, а не по памяти.

Основной путь — REST-эндпоинт через `web_fetch`: MCP-сервер в профиле по умолчанию не смонтирован, а REST не платит ничего за схемы инструментов:

```
https://context7.com/api/v1/websites/godotengine_en_4_6?type=txt&topic=<тема>&tokens=2500
```

Если в сессии всё же видны инструменты `mcp__context7__*` — можно и ими, ID тот же: `libraryId` = `/websites/godotengine_en_4_6`.

Почему именно он: верхняя по релевантности запись в поиске Context7 — `/godotengine/godot-docs`, и она прибита к ветке **4.5**. В проекте разрешён только 4.6, поэтому ID задаётся явно и `resolve-library-id` не вызывается.

Как спрашивать: вопрос должен быть конкретным («как объявить @rpc для listen-server, call_local, rpc_config»), тогда выдача — ровно 4.6 с сигнатурами и ссылками на `/en/4.6/`. На расплывчатую формулировку выдача уезжает в соседние классы.

Когда **не** тратить вызов: вопросы про наш код — Context7 его не знает, для этого чтение `shared/` и `core/`. Также не нужен для проверок: гейт и смоуки дешевле.

Ориентир по цене: ответ Context7 на 2500 токенов ≈ 3k токенов, полная страница класса движка как текст ≈ 40k.
