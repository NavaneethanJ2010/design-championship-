@echo off
setlocal

REM Run this from the sign_assistant_project folder after installing requirements.
pyinstaller --noconfirm --clean --noconsole --onefile --name SignAssistant ^
  --add-data "core\hand_landmarker.task;core" ^
  --add-data "data\sign_dictionary.json;data" ^
  main.py

echo.
echo Build complete: dist\SignAssistant.exe
endlocal
