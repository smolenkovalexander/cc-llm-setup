# Установка cc-llm-setup агентом

Runbook для AI-агента (Claude Code или другой CLI-агент), который разворачивает эту
систему на новом компьютере. Проходи шаги по порядку; после каждого — проверка.
Если проверка не прошла, не продолжай: смотри «Диагностику» в конце.

Пользователю по ходу понадобится ввести два секрета (DeepSeek key и DIAL token) —
их вводит человек, агент их не придумывает и никуда не пишет, кроме `config-azure.yaml`.

## Что получится в итоге

```
%USERPROFILE%\cc-llm-setup\      ← папка проекта (клона): venv, конфиги, скрипты
%USERPROFILE%\.local\bin\        ← cc-ds.cmd, cc-proxy.cmd (из PATH)
%USERPROFILE%\.env               ← переменные Claude Code (модели, endpoint)
C:\...\Startup\litellm-proxy.lnk ← НЕ создаётся: прокси живёт только на время сессии
```

Два режима работы:

| Лончер | Что делает | Нужен прокси | Нужен VPN |
|---|---|---|---|
| `cc-ds` | Claude Code → api.deepseek.com напрямую | нет | нет |
| `cc-proxy` | Claude Code → локальный LiteLLM:4000 → DeepSeek / EPAM DIAL | да (поднимает сам) | для sonnet/haiku |

## Предусловия

Проверь и покажи пользователю результат каждого пункта:

```powershell
python --version      # нужен Python 3.11+
git --version
node --version        # нужен для хуков Claude Code
claude --version      # Claude Code установлен
```

Если чего-то нет:

```powershell
winget install Python.Python.3.12   # или с python.org
winget install Git.Git
winget install OpenJS.NodeJS.LTS
npm install -g @anthropic-ai/claude-code
```

Секреты (запроси у пользователя, если их нет):
- **DeepSeek API key** — https://platform.deepseek.com → API Keys
- **EPAM DIAL token** — у администратора EPAM; формат `dial-...`, имеет срок жизни

## Шаг 1. Клонирование

Раскладка по умолчанию — строго `%USERPROFILE%\cc-llm-setup`: на неё рассчитаны
лончеры и шаблон `start-proxy.cmd.example`.

```powershell
cd $env:USERPROFILE
git clone https://github.com/smolenkovalexander/cc-llm-setup.git
cd cc-llm-setup
```

Проверка: `Test-Path .\cc-proxy.cmd` → `True`.

## Шаг 2. Виртуальное окружение

```powershell
python -m venv venv
.\venv\Scripts\python.exe -m pip install --upgrade pip
.\venv\Scripts\pip.exe install -r requirements.txt
.\venv\Scripts\litellm.exe --version
```

Проверка: последняя команда печатает `LiteLLM: Current Version = 1.99.0`.

Версия **зафиксирована** (`litellm==1.99.0`), не обновляй её произвольно: новые
релизы LiteLLM отказываются стартовать без настроек аутентификации в конфиге
(нужен `master_key` либо явный opt-in-флаг). Если обновление всё же требуется —
смотри заметку о совместимости в конце `config-azure.yaml.example`.

Активировать venv в текущей сессии не обязательно — скрипты вызывают `litellm.exe` по пути.

## Шаг 3. Конфигурация прокси (секреты)

```powershell
Copy-Item config-azure.yaml.example config-azure.yaml
```

Открой `config-azure.yaml` и замени плейсхолдеры:

| Плейсхолдер | Значение |
|---|---|
| `YOUR_DEEPSEEK_API_KEY` (2 места) | DeepSeek API key |
| `YOUR_DIAL_TOKEN` (2 места) | EPAM DIAL token |

Ввод — только пользователь. Агент: попроси вставить ключи и не повторяй их в чате,
логах и коммитах.

Проверка: `git status --short` **не должен** показывать `config-azure.yaml` —
он в `.gitignore`. Если показывает, остановись и проверь `.gitignore`.

> Ключи DIAL имеют срок жизни. Если `cc-proxy` пишет WARNING про недоступный DIAL
> при включённом VPN — токен, скорее всего, истёк: запроси новый.

## Шаг 4. Скрипт запуска прокси

```powershell
Copy-Item start-proxy.cmd.example start-proxy.cmd
```

Правка нужна, **только** если папка проекта не `%USERPROFILE%\cc-llm-setup`:
в `start-proxy.cmd` замени строку `set "PROXY_DIR=%USERPROFILE%\cc-llm-setup"`.

Не удаляй из него `set "PYTHONIOENCODING=utf-8"` — без него LiteLLM падает на
русской Windows с `UnicodeEncodeError` в баннере и не стартует вообще.

Проверка: `Test-Path .\start-proxy.cmd` → `True`.

## Шаг 5. Переменные Claude Code

```powershell
Copy-Item .env.example "$env:USERPROFILE\.env" -Force
```

Значения менять не нужно. Токен `ANTHROPIC_AUTH_TOKEN` — любая непустая строка
(например, `local-proxy-key`): это заглушка для прокси, реальный ключ не нужен.

**Правило имён моделей** (иначе получите HTTP 400): в `.env` имена должны точно
совпадать с `model_name` в `config-azure.yaml`. Суффикс `[1m]` (1M-контекст) здесь
указывать нельзя — его понимает только прямой DeepSeek API; в режиме `cc-ds` лончер
подставляет его сам.

## Шаг 6. Лончеры в PATH

```powershell
$bin = "$env:USERPROFILE\.local\bin"
New-Item -ItemType Directory -Force $bin | Out-Null
Copy-Item cc-ds.cmd, cc-proxy.cmd $bin\
```

Добавь `$bin` в пользовательский PATH, если его там нет:

```powershell
$userPath = [Environment]::GetEnvironmentVariable("Path", "User")
if ($userPath -notlike "*$bin*") {
  [Environment]::SetEnvironmentVariable("Path", "$userPath;$bin", "User")
  Write-Host "PATH обновлён — перезапусти терминал"
}
```

Проверка (в **новом** терминале): `Get-Command cc-proxy` находит `.local\bin\cc-proxy.cmd`.

## Шаг 7. Первый запуск и приёмка

```powershell
.\start-proxy.cmd
Start-Sleep -Seconds 15
curl.exe -s http://127.0.0.1:4000/health/liveliness
```

Ожидается `"I'm alive!"`.
**Не используй `/health`** — он пингует все модели конфига и зависает, если один
апстрим недоступен (типовой случай: DIAL без VPN).

Список моделей:

```powershell
curl.exe -s http://127.0.0.1:4000/v1/models
```

Ожидается четыре: `deepseek-v4-pro`, `deepseek-flash`, `claude-sonnet-4-6`, `claude-haiku-4-5`.

Сквозной тест — реальный запрос через прокси к DeepSeek (VPN не нужен):

```powershell
curl.exe -s -X POST http://127.0.0.1:4000/v1/messages `
  -H "content-type: application/json" -H "x-api-key: test" -H "anthropic-version: 2023-06-01" `
  -d '{\"model\":\"deepseek-flash\",\"max_tokens\":8,\"messages\":[{\"role\":\"user\",\"content\":\"ping\"}]}'
```

Ожидается JSON с `"role":"assistant"`. Ошибка `400 Invalid model name` — см. диагностику.

Погаси прокси, если поднимал вручную (в штатной работе это делает `cc-proxy`):

```powershell
Get-NetTCPConnection -LocalPort 4000 -State Listen | ForEach-Object { Stop-Process -Id $_.OwningProcess -Force }
```

Финальная проверка лончеров:

```powershell
cc-ds        # баннер Claude Code, модель deepseek-flash[1m] — работает без прокси
cc-proxy     # поднимает прокси, проверяет DIAL/VPN, гасит прокси при выходе
```

## Шаг 8. Обвязка Claude Code (опционально)

Если у пользователя есть репозиторий с конфигурацией `~/.claude` (CLAUDE.md, агенты,
политики, хуки, скиллы) — разверни его по его собственному `AGENT-INSTALL.md`
из того репозитория.

## Автозагрузка

По умолчанию **не нужна**: `cc-proxy` поднимает прокси на время сессии и гасит его
при выходе последней параллельной сессии (счётчик в `cc-proxy.lock`).

Держать прокси постоянно (например, для сторонних клиентов) — тогда ярлык:

```powershell
$startup = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup"
$shell = New-Object -ComObject WScript.Shell
$lnk = $shell.CreateShortcut("$startup\litellm-proxy.lnk")
$lnk.TargetPath = "$env:USERPROFILE\cc-llm-setup\start-proxy.cmd"
$lnk.WorkingDirectory = "$env:USERPROFILE\cc-llm-setup"
$lnk.Save()
```

Отключить автозагрузку — удалить ярлык (или переименовать в `.lnk.bak`).

## Диагностика

| Симптом | Причина | Решение |
|---|---|---|
| `400 Invalid model name ...` | имя модели в `.env` не совпадает с `config-azure.yaml`; чаще всего лишний суффикс `[1m]` | убери `[1m]` из `.env`; `[1m]` допустим только в `cc-ds` |
| `Application startup failed` + `UnicodeEncodeError` в консоли | не задан `PYTHONIOENCODING=utf-8` | добавь в `start-proxy.cmd` (он уже есть в шаблоне) |
| `/health` зависает | `/health` пингует все модели, включая недоступный DIAL | используй `/health/liveliness` |
| `[cc-proxy] ERROR: start-proxy.cmd not found` | `start-proxy.cmd` не рядом с лончером и не в `%USERPROFILE%\cc-llm-setup` | положи скрипт в папку проекта или клонируй туда |
| WARNING про DIAL, sonnet/haiku не отвечают | нет VPN или истёк DIAL token | включи VPN; проверь `curl.exe -s -o NUL -w "%{http_code}" -m 5 https://ai-proxy.lab.epam.com` → `401` = ок, `000` = нет сети/VPN |
| Прокси остался висеть после закрытия окна | жёсткое завершение сессии не уменьшило счётчик | `cc-proxy.lock` в папке проекта удалить; при следующем старте счётчик сбросится |
| DeepSeek отвечает ошибкой | ключ/баланс | platform.deepseek.com → API Keys / Usage |
| Прокси отвечает `429 Too Many Requests` | лимит DeepSeek | подожди или переключись на `cc-ds` |

## Чего делать нельзя

- Коммитить `config-azure.yaml`, `start-proxy.cmd`, `.env` — там живые ключи.
  Все три перечислены в `.gitignore`; проверяй `git status` перед коммитом.
- Печатать в чат содержимое `config-azure.yaml` и `.env`, даже частично.
- Менять порт `4000` в одном файле из двух: `start-proxy.cmd` и проверки в `cc-proxy.cmd`
  должны оставаться согласованными.
- Указывать `--host 0.0.0.0`: прокси должен слушать только `127.0.0.1`.

## Схема

```
Claude Code (cc-ds) ────────────────► api.deepseek.com/anthropic
Claude Code (cc-proxy) ──► LiteLLM 127.0.0.1:4000 ──┬──► api.deepseek.com/anthropic
                                                     └──► ai-proxy.lab.epam.com (EPAM DIAL, VPN)

Переключение модели в Claude Code:
  /model deepseek-flash      ← по умолчанию (V4.1 Flash, повседневная работа)
  /model deepseek-v4-pro     ← архитектура, алгоритмика, глубокий ревью
  /model claude-sonnet-4-6   ← корпоративный Claude (только при VPN)
```
