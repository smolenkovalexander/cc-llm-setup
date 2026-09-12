# Инструкция для AI-агента: установка cc-llm-setup

Эта инструкция предназначена для AI-агента (Claude Code, Hermes и др.), который устанавливает прокси на новом компьютере. Следуй шагам строго по порядку.

---

## Предусловия (проверь перед началом)

- ОС: Windows 10/11
- Python 3.11+ установлен: `python --version`
- Git установлен: `git --version`
- SSH-ключ настроен для GitHub: `ssh -T git@github.com`
- У пользователя есть: DeepSeek API key + EPAM DIAL token

---

## Шаг 1 — Определи пути

```powershell
$username = $env:USERNAME
$home = $env:USERPROFILE
$proxyDir = "$home\cc-llm-setup"
```

Запомни `$proxyDir` — он используется во всех последующих шагах.

---

## Шаг 2 — Клонируй репозиторий

```powershell
cd $home
git clone git@github.com:smolenkovalexander/cc-llm-setup.git
cd cc-llm-setup
```

---

## Шаг 3 — Создай виртуальное окружение и установи зависимости

```powershell
python -m venv venv
.\venv\Scripts\activate
pip install -r requirements.txt
```

Проверь, что litellm установился:
```powershell
litellm --version
```

---

## Шаг 4 — Создай конфигурацию прокси

Скопируй шаблон:
```powershell
cp config-azure.yaml.example config-azure.yaml
```

Открой `config-azure.yaml` и замени:
- `YOUR_DEEPSEEK_API_KEY` → реальный DeepSeek API key (получить на platform.deepseek.com)
- `YOUR_DIAL_TOKEN` → реальный EPAM DIAL token (формат: `dial-xxxxxxxxxxxx`)

**Важно:** этот файл в `.gitignore` — он не попадёт в git. Никогда не коммить файлы с реальными ключами.

---

## Шаг 5 — Создай скрипт запуска

```powershell
cp start-proxy.cmd.example start-proxy.cmd
```

Открой `start-proxy.cmd` и замени `YOUR_USERNAME` на реальное имя пользователя Windows (`$env:USERNAME`).

Путь к litellm.exe должен быть:
```
C:\Users\YOUR_USERNAME\cc-llm-setup\venv\Scripts\litellm.exe
```

---

## Шаг 6 — Создай .env для Claude Code

```powershell
cp .env.example "$home\.env"
```

Открой `$home\.env` и замени:
- `YOUR_LITELLM_VIRTUAL_KEY_OR_ANY_NONEMPTY_STRING` → любая непустая строка (например, `local-proxy-key`)

Остальные значения менять не нужно — они уже правильные.

---

## Шаг 7 — Запусти прокси

```powershell
.\start-proxy.cmd
```

Проверь, что прокси поднялся:
```powershell
curl http://127.0.0.1:4000/health
```

Ожидаемый ответ: JSON со статусом healthy или список моделей.

Проверь список моделей:
```powershell
curl http://127.0.0.1:4000/v1/models
```

Должны быть: `deepseek-v4-pro`, `deepseek-v4-flash`, `claude-sonnet-4-6`, `claude-haiku-4-5`.

---

## Шаг 8 — Добавь прокси в автозагрузку Windows

Создай ярлык на `start-proxy.cmd` и помести в:
```
C:\Users\YOUR_USERNAME\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Startup\
```

Или через PowerShell:
```powershell
$startup = "$home\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Startup"
$shell = New-Object -ComObject WScript.Shell
$shortcut = $shell.CreateShortcut("$startup\litellm-proxy.lnk")
$shortcut.TargetPath = "$proxyDir\start-proxy.cmd"
$shortcut.WorkingDirectory = $proxyDir
$shortcut.Save()
```

---

## Шаг 9 — Проверь работу Claude Code

```powershell
claude --version
claude -p "ответь одним словом: работает?"
```

Если ответ получен — установка завершена.

---

## Диагностика проблем

### Прокси не запускается
- Проверь, что `venv\Scripts\litellm.exe` существует
- Запусти вручную с выводом: `.\venv\Scripts\litellm.exe --config config-azure.yaml --port 4000`
- Смотри ошибки в консоли

### Claude Code не видит прокси
- Проверь `~\.env`: `ANTHROPIC_BASE_URL=http://127.0.0.1:4000`
- Перезапусти терминал после изменения `.env`
- Проверь `curl http://127.0.0.1:4000/health`

### Ошибки кодировки при запуске прокси
- В `start-proxy.cmd` должно быть: `set "PYTHONIOENCODING=utf-8"`

### DeepSeek не отвечает
- Проверь ключ на platform.deepseek.com → API Keys
- Проверь баланс аккаунта

### DIAL не отвечает
- DIAL token имеет срок жизни — получи новый у администратора EPAM
- Проверь VPN-подключение к корпоративной сети (если требуется)

---

## Итоговая схема работы

```
Claude Code / другой AI-агент
        │
        │ Anthropic Messages API
        ▼
LiteLLM прокси (127.0.0.1:4000)
        │
        ├─── deepseek-v4-pro / deepseek-v4-flash
        │         └── api.deepseek.com/anthropic
        │
        └─── claude-sonnet-4-6 / claude-haiku-4-5
                  └── ai-proxy.lab.epam.com (EPAM DIAL)
```

### Переключение модели в Claude Code
```
/model deepseek-v4-pro      ← дешёвая повседневная работа
/model claude-sonnet-4-6    ← сложные задачи, ревью, архитектура
/model deepseek-v4-flash    ← фоновые задачи
```
