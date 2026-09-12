@echo off
REM cc-proxy: start the LiteLLM proxy on demand (127.0.0.1:4000), run Claude Code,
REM then stop the proxy when the last cc-proxy session exits.
REM Loads all vars from %USERPROFILE%\.env (that file is the proxy config).
REM Works from the repo folder or when copied anywhere else:
REM start-proxy.cmd is looked up next to this script, then in %USERPROFILE%\cc-llm-setup.
REM Known limits: if a session is killed hard (Ctrl+C at the batch prompt, closed
REM window), its refcount entry leaks and the proxy keeps running until the next
REM cc-proxy start resets the counter.
title CC / LiteLLM proxy
setlocal EnableExtensions

set "ENVF=%USERPROFILE%\.env"
if not exist "%ENVF%" (
  echo [cc-proxy] ERROR: %ENVF% not found
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

REM ---------- locate start-proxy.cmd ----------
set "PROXY_DIR=%~dp0"
if not exist "%PROXY_DIR%start-proxy.cmd" set "PROXY_DIR=%USERPROFILE%\cc-llm-setup\"
if not exist "%PROXY_DIR%start-proxy.cmd" (
  echo [cc-proxy] ERROR: start-proxy.cmd not found next to this script or in %USERPROFILE%\cc-llm-setup
  exit /b 1
)

REM ---------- session refcount (supports parallel cc-proxy windows) ----------
set "LOCK=%PROXY_DIR%cc-proxy.lock"
set /a CNT=0 >NUL
if exist "%LOCK%" set /p CNT=<"%LOCK%"
set /a CNT+=1 >NUL

REM ---------- start the proxy if it is down ----------
REM Use /health/liveliness, NOT /health: /health pings EVERY model in the
REM config, so one unreachable upstream (e.g. corporate DIAL without VPN)
REM makes it hang forever and cc-proxy never reaches Claude Code.
set "STARTED=0"
curl.exe -fsS -m 5 -o NUL http://127.0.0.1:4000/health/liveliness 2>NUL
if not errorlevel 1 goto proxy_up

echo [cc-proxy] LiteLLM proxy is down - starting it (127.0.0.1:4000)...
cmd /c "%PROXY_DIR%start-proxy.cmd"
set "STARTED=1"

set /a TRIES=0 >NUL
:wait_proxy
curl.exe -fsS -m 2 -o NUL http://127.0.0.1:4000/health/liveliness 2>NUL
if not errorlevel 1 goto proxy_up
set /a TRIES+=1 >NUL
if %TRIES% GEQ 15 goto proxy_failed
ping -n 3 127.0.0.1 >NUL
goto wait_proxy

:proxy_failed
del "%LOCK%" 2>NUL
echo [cc-proxy] ERROR: proxy did not start within 30s. Check the litellm-proxy window for errors.
exit /b 1

:proxy_up
if "%STARTED%"=="1" set /a CNT=1 >NUL
<nul set /p "=%CNT%" > "%LOCK%"

echo [cc-proxy] Claude Code - LiteLLM proxy ^(127.0.0.1:4000, models from .env^)

REM ---------- corporate DIAL check (sonnet/haiku need the VPN) ----------
REM any HTTP response (even 401) means DIAL is alive - use curl WITHOUT -f
curl.exe -s -m 5 -o NUL https://ai-proxy.lab.epam.com 2>NUL
if errorlevel 1 (
  echo [cc-proxy] WARNING: corporate DIAL is unreachable - the VPN seems to be OFF.
  echo [cc-proxy]   claude-sonnet-4-6 and haiku will NOT work; only DeepSeek models.
  echo [cc-proxy]   Turn the VPN on and restart cc-proxy to use sonnet.
) else (
  echo [cc-proxy] DIAL: reachable - claude-sonnet-4-6 available.
)

REM call (not bare invocation): claude may be a .cmd shim - without call the
REM batch would chain into it and the stop-proxy code below would never run
call claude --allow-dangerously-skip-permissions --dangerously-skip-permissions %*
set "CLAUDE_EXIT=%errorlevel%"

REM ---------- release refcount; stop the proxy after the last session ----------
set /a CNT=0 >NUL
if exist "%LOCK%" set /p CNT=<"%LOCK%"
set /a CNT-=1 >NUL
if %CNT% LEQ 0 goto stop_proxy
<nul set /p "=%CNT%" > "%LOCK%"
goto done

:stop_proxy
del "%LOCK%" 2>NUL
echo [cc-proxy] Last session exited - stopping LiteLLM proxy...
for /f "tokens=5" %%P in ('netstat -ano ^| findstr /r /c:":4000 .*LISTENING"') do taskkill /F /PID %%P >NUL 2>&1

:done
exit /b %CLAUDE_EXIT%
