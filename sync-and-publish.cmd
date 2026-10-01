@echo off
setlocal
cd /d "%~dp0"
node scripts\publish-obsidian.mjs %*
set "PUBLISH_EXIT=%ERRORLEVEL%"
echo.
if not "%PUBLISH_EXIT%"=="0" echo Publish failed. See the message above.
if "%~1"=="" pause
exit /b %PUBLISH_EXIT%
