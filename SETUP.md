# cc-llm-setup

Локальный LiteLLM-прокси для подключения Claude Code к двум LLM-провайдерам:
- **DeepSeek** — через официальный Anthropic-совместимый API (дёшево, повседневная работа)
- **EPAM DIAL** — корпоративный шлюз к Claude Sonnet/Haiku (сложные задачи)

## Архитектура

```
Claude Code
    │ Anthropic Messages API
    ▼
LiteLLM proxy (localhost:4000)
    ├── deepseek-v4-pro / deepseek-v4-flash → api.deepseek.com
    └── claude-sonnet-4-6 / claude-haiku-4-5 → ai-proxy.lab.epam.com (DIAL)
```

## Быстрая установка

```powershell
git clone https://github.com/smolenkovalexander/cc-llm-setup.git
cd cc-llm-setup
python -m venv venv
.\venv\Scripts\activate
pip install -r requirements.txt

cp config-azure.yaml.example config-azure.yaml
# Открой config-azure.yaml и вставь ключи

cp start-proxy.cmd.example start-proxy.cmd
# Открой start-proxy.cmd и замени YOUR_USERNAME

cp .env.example $HOME\.env
# Отредактируй при необходимости
```

## Запуск Claude Code

```powershell
cc-proxy    # прокси поднимается по требованию, при выходе гаснет (рекомендуется)
cc-ds       # напрямую через DeepSeek, без прокси
```

- **cc-proxy**: если прокси лежит — сам его запускает, ждёт готовности, запускает Claude Code, а при выходе последней параллельной сессии гасит прокси. Перед запуском проверяет доступность DIAL и предупреждает, если VPN выключен (sonnet/haiku будут недоступны).
- **cc-ds**: Claude Code напрямую через `api.deepseek.com/anthropic` (модель `deepseek-v4-pro[1m]`), прокси не нужен.
- Лаунчеры можно скопировать в папку из PATH (например, `%USERPROFILE%\.local\bin`) — скрипт сам найдёт `start-proxy.cmd` рядом с собой или в `%USERPROFILE%\cc-llm-setup`.
- Автозагрузка прокси при включении ПК не нужна — он живёт только во время сессий `cc-proxy`.

Подробная инструкция — в `AGENT-INSTALL.md`.

## Файлы

| Файл | Назначение |
|---|---|
| `cc-proxy.cmd` | Лаунчер: прокси on-demand → Claude Code → автогашение прокси + напоминание о VPN |
| `cc-ds.cmd` | Лаунчер: Claude Code напрямую через DeepSeek |
| `config-azure.yaml.example` | Шаблон конфига прокси (заменить ключи) |
| `start-proxy.cmd.example` | Шаблон скрипта запуска (заменить путь) |
| `.env.example` | Шаблон переменных Claude Code |
| `strip_cache.py` | Callback LiteLLM: убирает поля кэша, несовместимые с апстримом |
| `requirements.txt` | Зависимости Python |
| `AGENT-INSTALL.md` | Полная инструкция для AI-агента |

## Где взять ключи

- **DeepSeek API key**: https://platform.deepseek.com → API Keys
- **EPAM DIAL token**: запросить у администратора EPAM или через внутренний портал

## Переключение модели

```
/model deepseek-v4-pro      ← по умолчанию, повседневная работа
/model claude-sonnet-4-6    ← сложные задачи, ревью архитектуры
/model deepseek-v4-flash    ← фоновые агенты
```
