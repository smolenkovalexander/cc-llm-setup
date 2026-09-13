@echo off
REM cc-ds: Claude Code via DeepSeek API directly (no proxy, model deepseek-v4-pro[1m])
REM Loads vars from %USERPROFILE%\.env, then overrides endpoint/model to direct DeepSeek.
title CC / DeepSeek direct
setlocal EnableExtensions

set "ENVF=%USERPROFILE%\.env"
if not exist "%ENVF%" (
  echo [cc-ds] ERROR: %ENVF% not found
  exit /b 1
)

for /f "usebackq tokens=1* delims==" %%A in (`findstr /b /c:"$env:" "%ENVF%"`) do (
  if "%%A"=="$env:ANTHROPIC_BASE_URL" set "ANTHROPIC_BASE_URL=%%~B"
  if "%%A"=="$env:ANTHROPIC_AUTH_TOKEN" set "ANTHROPIC_AUTH_TOKEN=%%~B"
  if "%%A"=="$env:ANTHROPIC_MODEL" set "ANTHROPIC_MODEL=%%~B"
  if "%%A"=="$env:ANTHROPIC_DEFAULT_OPUS_MODEL" set "ANTHROPIC_DEFAULT_OPUS_MODEL=%%~B"
  if "%%A"=="$env:ANTHROPIC_DEFAULT_SONNET_MODEL" set "ANTHROPIC_DEFAULT_SONNET_MODEL=%%~B"
  if "%%A"=="$env:ANTHROPIC_DEFAULT_HAIKU_MODEL" set "ANTHROPIC_DEFAULT_HAIKU_MODEL=%%~B"
  if "%%A"=="$env:CLAUDE_CODE_SUBAGENT_MODEL" set "CLAUDE_CODE_SUBAGENT_MODEL=%%~B"
  if "%%A"=="$env:CLAUDE_CODE_EFFORT_LEVEL" set "CLAUDE_CODE_EFFORT_LEVEL=%%~B"
  if "%%A"=="$env:CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC" set "CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=%%~B"
  if "%%A"=="$env:ENABLE_TOOL_SEARCH" set "ENABLE_TOOL_SEARCH=%%~B"
)

REM Direct DeepSeek overrides
set "ANTHROPIC_BASE_URL=https://api.deepseek.com/anthropic"
set "ANTHROPIC_MODEL=deepseek-flash"
set "ANTHROPIC_DEFAULT_OPUS_MODEL=deepseek-v4-pro[1m]"
set "ANTHROPIC_DEFAULT_SONNET_MODEL=deepseek-flash"

echo [cc-ds] Claude Code -- DeepSeek API direct ^(default: deepseek-flash, opus: deepseek-v4-pro[1m]^)
claude --allow-dangerously-skip-permissions --dangerously-skip-permissions %*
exit /b %errorlevel%
