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
git clone git@github.com:smolenkovalexander/cc-llm-setup.git
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

.\start-proxy.cmd
```

Подробная инструкция — в `AGENT-INSTALL.md`.

## Файлы

| Файл | Назначение |
|---|---|
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
