---
name: lesson-game-build
description: Release-build recipe for the LessonGame Godot 4.6 project — bump the version, export the Windows preset headlessly, pack the RAR with WinRAR, smoke-run the result.
whenToUse: Use when asked to build a new LessonGame version ("собери билд", "новая версия", "сделай сборку"), or when a Godot export under the DSH sandbox fails (missing export template, denied junction).
---

# LessonGame: сборка релизного билда

## Что должно получиться

`build/v.0.0.N/` — три файла и архив рядом:

| Файл | Размер (ориентир) |
|---|---|
| `LessonGame.exe` | 99.71 МБ (это шаблон `windows_release_x86_64.exe` плюс иконка) |
| `LessonGame.console.exe` | 0.16 МБ (обёртка с консолью, `debug/export_console_wrapper=2`) |
| `LessonGame.pck` | ~6 МБ (`binary_format/embed_pck=false`) |
| `run_server.bat` | ~1 КБ, копируется из `tools/server/` — запуск выделенного сервера двойным кликом |
| `v.0.0.N.rar` | ~32 МБ (те же четыре файла в корне архива) |

`build/` в `.gitignore` — в гите живёт только `export_presets.cfg`, поэтому номер версии фиксируется коммитом этого файла.

## Номер версии

Следующая версия — максимальная в `build/` плюс один. В `export_presets.cfg` при сборке меняется **только** поле `export_path` (так во всей истории коммитов), и оно указывает на **последнюю собранную** версию:

```
export_path="build/v.0.0.N/LessonGame.exe"
```

## Шаги

Всё в одном процессе PowerShell: `APPDATA` действует только на текущий процесс.

0. Гейт загрузки, чтобы кэш импорта был свежим (иначе экспорт может собрать старое):
   `& $godot --headless --path . --quit` — exit 0 и только баннер.
1. Шаблоны экспорта — один раз на машину, см. ниже.
2. Поднять номер в `export_presets.cfg`.
3. Экспорт:

```powershell
$env:APPDATA = Join-Path (Get-Location) '.dsh_user'
$godot = 'C:\Program Files\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe'
New-Item -ItemType Directory -Force 'build\v.0.0.N' | Out-Null
& $godot --headless --path . --export-release "Windows Desktop" "build/v.0.0.N/LessonGame.exe" *> '.dsh_user\build-export.log'
"exit=$LASTEXITCODE"
```

   Успех — `exit=0` и `[ DONE ] savepack` в конце лога. Если шаблона нет, файлы просто не появятся (или экспорт вернёт ненулевой код) — см. раздел про шаблоны.
4. Архив (WinRAR стоит в `C:\Program Files\WinRAR\Rar.exe`):

```powershell
Push-Location 'build\v.0.0.N'
& 'C:\Program Files\WinRAR\Rar.exe' a -ep1 -m5 'v.0.0.N.rar' 'LessonGame.exe' 'LessonGame.console.exe' 'LessonGame.pck'
Pop-Location
& 'C:\Program Files\WinRAR\Rar.exe' l 'build\v.0.0.N\v.0.0.N.rar'   # сверка содержимого
```

   `-ep1` — без путей: в архиве три файла в корне, как во всех прошлых версиях.
5. Смоук собранного:

```powershell
$env:APPDATA = Join-Path (Get-Location) '.dsh_user'
& '.\build\v.0.0.N\LessonGame.console.exe' --headless --quit *> '.dsh_user\build-run.log'
"exit=$LASTEXITCODE"
```

   Успех — exit 0 и только баннер движка. Единственная допустимая строка `ERROR` — `Failed to read the root certificate store` (системное хранилище сертификатов; она же появляется в прогонах редактора и к проекту не относится).

Логи всех шагов — в `.dsh_user\build-*.log` (папка в `.gitignore`), поэтому в корне проекта после сборки ничего лишнего не остаётся.

## Шаблоны экспорта под песочницей

Перенаправленный `APPDATA` уводит и папку шаблонов: движок ищет их в `.dsh_user\Godot\export_templates\`, а не в реальном профиле. Junction туда создать **политика не даёт** (`Access is denied`), поэтому файлы копируются — один раз на машину, ~100 МБ:

```powershell
$src = Join-Path $env:USERPROFILE 'AppData\Roaming\Godot\export_templates\4.6.stable'
$dst = Join-Path (Get-Location) '.dsh_user\Godot\export_templates\4.6.stable'
New-Item -ItemType Directory -Force $dst | Out-Null
'version.txt','windows_release_x86_64.exe','windows_release_x86_64_console.exe' |
	ForEach-Object { Copy-Item (Join-Path $src $_) (Join-Path $dst $_) -Force }
```

## Скрипт

`build.ps1` в этой же папке делает шаги 0–5 плюс проверку файрвола. На машине запрещён запуск `.ps1` политикой, поэтому сначала Bypass в том же процессе:

```powershell
Set-ExecutionPolicy -Scope Process Bypass -Force
& .dsh\skills\lesson-game-build\build.ps1 -DryRun        # показать план, ничего не менять
& .dsh\skills\lesson-game-build\build.ps1                # собрать следующую версию
& .dsh\skills\lesson-game-build\build.ps1 -Version 16    # конкретная версия
```

Альтернатива без смены политики в сессии: `powershell -NoProfile -ExecutionPolicy Bypass -File .dsh\skills\lesson-game-build\build.ps1`.

Параметры: `-DryRun`, `-NoRar`, `-SkipSmoke`, `-SkipFirewall`, `-Godot <путь к exe>`. Если скрипт не сработал — шаги выше авторитетнее, они проверены руками на v.0.0.15.

## Файрвол: чтобы свежая сборка не «не подключалась»

Отдельный шаг сборки, потому что заблокированная сборка снаружи выглядит ровно как «игра не соединяется» (см. грабли ниже). Логика:

- **проверка** — только чтение хранилища правил из реестра, поэтому работает и в `-DryRun`, и без прав администратора;
- **починка** — `firewall-allow.ps1` в этой же папке: создаёт не привязанное к exe правило `LessonGame UDP 8910-8911` (покрывает все текущие и будущие сборки) и удаляет правила `Block` для любого exe внутри `build\`. Требует прав администратора;
- `build.ps1` вызывает починку **только если есть что чинить**: когда процесс уже повышен, helper запускается напрямую, иначе однократно запрашивается UAC. Отказались от UAC или запуск неинтерактивный — сборка не падает, а печатает готовую команду для админского окна:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .dsh\skills\lesson-game-build\firewall-allow.ps1
```

Правило по портам добавляется один раз и дальше не требует ни диалогов, ни прав: под него попадает `LessonGame.exe` из любой версии, потому что оно не привязано к пути. Проверить состояние можно в любой момент — `build.ps1 -DryRun` печатает, что именно не так (`no port rule covering every build`, `block rules in the build folder: N`) и сколько разрешений уже выдано отдельным сборкам.

**Особенности машины, из-за которых скрипт выглядит именно так** (все проверены):

- `pwsh` не установлен, шелл — **Windows PowerShell 5.1**. Скрипт держим совместимым с 5.1 (`#Requires -Version 5.1`, никаких `??` и тернарников из 7-й версии).
- PowerShell 5.1 читает файлы **без BOM как ANSI**, поэтому кириллица внутри `.ps1` ломает разбор (`Unexpected token`). Скрипт поэтому **чисто ASCII**: комментарии и сообщения в нём английские, а русские тексты живут здесь, в SKILL.md. Если всё же добавляешь кириллицу в `.ps1` — сохраняй файл в UTF-8 **с BOM**.
- **В PowerShell 5.1 stderr нативной программы при `$ErrorActionPreference = 'Stop'` — терминальная ошибка.** Godot всегда пишет в stderr одну безобидную строку `ERROR: Failed to read the root certificate store` (не относится к проекту) — из-за неё скрипт падал **сразу на шаге 0**, хотя сам гейт возвращал exit 0: в логе оставался только баннер, `[exit code: 1]` без единого слова о причине. Поэтому все вызовы `Godot`, `Rar.exe` и смоук-прогон идут через `Invoke-Native` — он на время вызова опускает `$ErrorActionPreference` до `Continue` и возвращает **код возврата** (он и остаётся источником истины; `if ($LASTEXITCODE -ne 0)` после нативной команды бесполезен, потому что до него управление не доходит). Если добавляешь новый внешний вызов — оборачивай так же, иначе он «сломает сборку без причины».
- **Форматирование того же stderr попадает в лог смоук-прогона** (`*> файл`): PowerShell дописывает строки `At line:…`, `CategoryInfo : …` и `FullyQualifiedErrorId : NativeCommandError`, и в них есть слово `ERROR` — фильтр «оставить только настоящие ошибки» ловил их и выдавал ложный `WARNING: errors in the run log`. Скрипт отбрасывает эти строки регуляркой `$errorNoise`; настоящие ошибки движка выглядят иначе (`SCRIPT ERROR: …`) и проходят фильтр. Сменить этот шаг на `Start-Process -RedirectStandardOutput` не получится: под песочницей DSH он падает с `Access is denied`, хотя файлы успевает создать.

## Грабли

- **В билд попадает рабочее дерево, а не коммит.** Незакоммиченные правки уедут в сборку — сначала решить, то ли это, что нужно.
- **Размеры — быстрый признак неудачи.** `LessonGame.exe` около 99.71 МБ, `.pck` около 6 МБ. Заметно другие числа (или отсутствие `.pck`) означают, что экспорт собрал не то.
- **`APPDATA` ставить в том же процессе**, где идёт экспорт или запуск: переменная не переживает запуск нового процесса PowerShell.
- **Не запускать смоук-прогон параллельно с сетевым смоуком**: если игра останется висеть без `--quit`, она займёт порт 8910 и следующий прогон упадёт с «Не удалось создать игру на порту 8910» (такое уже случалось, когда на машине крутился чужой хост).
- RAR от WinRAR пишет `Evaluation copy. Please register.` — это нормально, архив создаётся.
- **Провал в середине сборки съедает номер версии.** `export_path` перезаписывается на новую версию ещё до экспорта, поэтому после любой неудачи следующий запуск считает «последней собранной» ту версию, до которой дошёл, и берёт номер на единицу выше. Так появился дубль `v.0.0.16` (тот же код, что и `v.0.0.17`, совпадали даже хеши `LessonGame.exe`): шаг упал на архиве уже **после** экспорта. Если это не нужно — либо `-Version N` явно, либо убрать лишнюю папку.
- **На другой машине SmartScreen может не дать запустить exe.** Сборка не подписана, а файл, перенесённый по сети или скачанный, несёт метку «из интернета» — Windows показывает «Windows protected your PC» и игра не стартует, что снаружи выглядит как «не подключается». Лечение: «Run anyway», либо снять метку — `Unblock-File` на архиве **до** распаковки (тогда она не перейдёт на exe) или на самом exe; через GUI — Свойства → «Разблокировать». У каждой новой версии репутации нет, поэтому вопрос будет повторяться, пока файл не разблокируют или сборку не подпишут (`codesign` в пресете выключен).
- **Windows Firewall блокирует сборки по отдельности.** В ответ на «Отмена» в запросе «Разрешить доступ к сети?» Windows создаёт правила `Action=Block` **на конкретный путь exe** и больше про эту программу не спрашивает — дальше блок ставится молча. Решение запоминается по пути, поэтому пересборка по тому же пути его не сбрасывает, а новая папка версии считается новой программой. Дефолт для входящих — блок, а `Block` приоритетнее `Allow` — поэтому портовое правило `LessonGame UDP 8910-8911` (оно не привязано к exe и покрывает все будущие сборки) помогает только после удаления блоков: `Get-NetFirewallRule | Where-Object { $_.DisplayName -match 'lessongame' -and $_.Action -eq 'Block' } | Remove-NetFirewallRule`. Что блоков нет, проверяется **без админа** — по реестру `HKLM:\SYSTEM\CurrentControlSet\Services\SharedAccess\Parameters\FirewallPolicy\FirewallRules` (искать `Action=Block` и путь сборки). Чтобы запрос больше не появлялся, можно `Set-NetFirewallProfile -NotifyOnListen False`, но только когда разрешающее правило уже есть: выключенные уведомления **ничего не разрешают**, без правила трафик будет тихо блокироваться.
- Версия видна только в `export_presets.cfg`; в самой игре её нигде нет (`application/product_version` пустой). Показывать версию в UI — отдельная задача.
