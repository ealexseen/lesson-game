---
name: lesson-game-godot
description: Verification recipes for the LessonGame Godot 4.6 project — headless gates, smoke scenes, report files — plus how to look up exact Godot 4.6 engine API answers through Context7.
whenToUse: Use when verifying a change in LessonGame, when a Godot CLI run misbehaves, or when an exact Godot 4.6 engine API detail is needed and guessing is not acceptable.
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

Чего гейт **не** видит: скрипты из недостижимых сцен (главная сцена + автолоады). Такой скрипт надо запускать напрямую, иначе ошибка пройдёт молча.

## Смоук-сцены

```powershell
# изоляция игровых событий по игроку (M0)
& $godot --headless --path . res://core/dev_checks/players_isolation_check.tscn

# сетевой смоук (M1–M5), аргументы после --
& $godot --headless --path . res://core/dev_checks/network_smoke.tscn -- --autohost --name=Host --password=secret --start-game
& $godot --headless --path . res://core/dev_checks/network_smoke.tscn -- --autoconnect=127.0.0.1 --password=secret --expect-game
```

Успех печатают маркеры `M0 CHECK: OK`, `SMOKE CLIENT CONNECTED`, `SMOKE CLIENT SEES MOTION`, `SMOKE CLIENT NAMEPLATE: ник цвет`, `SMOKE STRESS OK`, `SMOKE BOT DONE`. Провал — exit 1.

## Что ловит грабли

- `--check-only --script res://<путь>.gd` **не годится как проверка**: автолоады в этом режиме недоступны, отсюда ложные `Identifier not found: EventSystem`, и exit 0 даже при реальной ошибке.
- Новый `class_name` не виден движку, пока не выполнен `--headless --import`.
- stdout под `Start-Process` буферизуется и теряет хвост. Итог прогона надёжнее писать файлом: `--report=<имя>.txt` → `res://_dsh_reports/<имя>.txt` (папку создать заранее).
- Два окна игры конфликтуют за порт LAN-поиска 8911: слушатель только один, второй ждёт освобождения. Подключение по адресу работает всегда.
- Долгие прогоны (стресс с ботами, сеть) стоит уводить в фоновую задачу, а не ждать синхронно.

## Справка по API Godot 4.6 (Context7)

Если нужен точный ответ по API движка — использовать MCP Context7 с явным ID, не поиск по памяти:

- `libraryId`: `/websites/godotengine_en_4_6`

Почему именно он: верхняя по релевантности запись в поиске Context7 — `/godotengine/godot-docs`, и она прибита к ветке **4.5**. В проекте разрешён только 4.6, поэтому ID задаётся явно и `resolve-library-id` не вызывается.

Как спрашивать: вопрос должен быть конкретным («как объявить @rpc для listen-server, call_local, rpc_config»), тогда выдача — ровно 4.6 с сигнатурами и ссылками на `/en/4.6/`. На расплывчатую формулировку выдача уезжает в соседние классы.

Когда **не** тратить вызов: вопросы про наш код — Context7 его не знает, для этого чтение `shared/` и `core/`. Также не нужен для проверок: гейт и смоуки дешевле.

Ориентир по цене: ответ Context7 на 2500 токенов ≈ 3k токенов, полная страница класса движка как текст ≈ 40k.
