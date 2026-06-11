@echo off
rem Launches Roblox Studio's built-in MCP server (StudioMCP.exe).
rem Studio's install folder name changes on every update, so this finds the
rem newest version folder that contains the exe and runs it from there.
for /f "delims=" %%i in ('dir /b /o-d "%LOCALAPPDATA%\Roblox\Versions" 2^>nul') do (
  if exist "%LOCALAPPDATA%\Roblox\Versions\%%i\StudioMCP.exe" (
    "%LOCALAPPDATA%\Roblox\Versions\%%i\StudioMCP.exe" %*
    exit /b %errorlevel%
  )
)
echo StudioMCP.exe not found in %LOCALAPPDATA%\Roblox\Versions - is Roblox Studio installed? 1>&2
exit /b 1
