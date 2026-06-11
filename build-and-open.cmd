@echo off
rem Orbit Legends — rebuild the place file from the src\ Lua and open it in Studio.
rem Double-click this whenever you want to test the latest code.
cd /d "%~dp0"
echo Building OrbitLegends.rbxlx from src\ ...
"%~dp0tools\rojo.exe" build -o "%~dp0OrbitLegends.rbxlx"
if errorlevel 1 (
  echo.
  echo Build FAILED - see the error above.
  pause
  exit /b 1
)
echo Build OK. Opening in Roblox Studio...
start "" "%~dp0OrbitLegends.rbxlx"
