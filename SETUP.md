# cc-llm-setup

Локальный LiteLLM-прокси плюс два лончера Claude Code:

- **cc-ds** — Claude Code напрямую к `api.deepseek.com/anthropic`, без прокси. Основная модель `deepseek-flash[1m]` (1M-контекст), слот opus — `deepseek-v4-pro[1m]`.
- **cc-proxy** — Claude Code через локальный LiteLLM (`127.0.0.1:4000`), который раздаёт и DeepSeek, и корпоративный Claude через EPAM DIAL. Прокси поднимается по требованию и гаснет при выходе последней сессии.

## Архитектура

```
Claude Code (cc-ds) ────────────────► api.deepseek.com/anthropic
Claude Code (cc-proxy) ──► LiteLLM 127.0.0.1:4000 ──┬──► api.deepseek.com/anthropic
                                                     └──► ai-proxy.lab.epam.com (EPAM DIAL, VPN)
```

## Установка

Полный runbook (в том числе для агента): **`AGENT-INSTALL.md`**. Коротко:

```powershell
cd $env:USERPROFILE
git clone https://github.com/smolenkovalexander/cc-llm-setup.git
cd cc-llm-setup

python -m venv venv
.\venv\Scripts\pip.exe install -r requirements.txt

Copy-Item config-azure.yaml.example config-azure.yaml   # вписать DeepSeek key и DIAL token
Copy-Item start-proxy.cmd.example start-proxy.cmd       # путь уже параметризован
Copy-Item .env.example "$env:USERPROFILE\.env"

$bin = "$env:USERPROFILE\.local\bin"
New-Item -ItemType Directory -Force $bin | Out-Null
Copy-Item cc-ds.cmd, cc-proxy.cmd $bin\                 # и добавить $bin в PATH
```

Лончеры ищут `start-proxy.cmd` рядом с собой, затем в `%USERPROFILE%\cc-llm-setup`, — поэтому раскладка «клон в `%USERPROFILE%\cc-llm-setup`» работает без правок.

Автозагрузка не нужна: прокси живёт только во время сессий `cc-proxy`. Постоянный запуск — по желанию, ярлык описан в `AGENT-INSTALL.md`.

## Запуск

```powershell
cc-proxy    # прокси + обе платформы (перед стартом проверяет доступность DIAL и предупредит, если VPN выключен)
cc-ds       # напрямую DeepSeek, прокси не нужен
```

Переключение модели внутри сессии:

```
/model deepseek-flash      ← по умолчанию (V4.1 Flash, повседневная работа)
/model deepseek-v4-pro     ← архитектура, алгоритмика, глубокий ревью
/model claude-sonnet-4-6   ← корпоративный Claude (только при VPN)
```

## Грабли

- **Имена моделей в `.env` не должны содержать `[1m]`.** Прокси ищет модель по точному имени из `config-azure.yaml` и на незнакомое отвечает `400 Invalid model name`. Суффикс `[1m]` понимает только прямой DeepSeek API, и `cc-ds` подставляет его сам.
- **Проверяй живость через `/health/liveliness`, а не `/health`.** `/health` пингует все модели конфига и зависает, когда DIAL недоступен без VPN.
- **`PYTHONIOENCODING=utf-8` в `start-proxy.cmd` обязателен** — иначе LiteLLM падает на русской Windows (`UnicodeEncodeError` в баннере → `Application startup failed`).
- **Ключи не коммитятся.** `config-azure.yaml`, `start-proxy.cmd`, `.env` перечислены в `.gitignore`.

## Файлы

| Файл | Назначение |
|---|---|
| `cc-proxy.cmd` | Лончер: прокси on-demand → Claude Code → автогашение + проверка VPN/DIAL |
| `cc-ds.cmd` | Лончер: Claude Code напрямую через DeepSeek (модели с `[1m]`) |
| `config-azure.yaml.example` | Шаблон конфига прокси: DeepSeek + EPAM DIAL (заменить ключи) |
| `start-proxy.cmd.example` | Шаблон запуска прокси (путь параметризован через `%USERPROFILE%`) |
| `.env.example` | Шаблон переменных Claude Code (`~/.env`) |
| `strip_cache.py` | Callback LiteLLM: убирает поля кэша, несовместимые с апстримом |
| `requirements.txt` | Зависимости Python (litellm) |
| `AGENT-INSTALL.md` | Полный runbook установки: шаги с проверками, приёмка, диагностика |

## Где взять ключи

- **DeepSeek API key**: https://platform.deepseek.com → API Keys
- **EPAM DIAL token**: у администратора EPAM (срок жизни ограничен — при массовых 401 запроси новый)
