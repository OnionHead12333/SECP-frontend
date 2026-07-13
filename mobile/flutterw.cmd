@echo off
setlocal
set "ROOT_DIR=%~dp0.."
set "PUB_CACHE=E:\.pub-cache"
set "GRADLE_USER_HOME=%ROOT_DIR%\.gradle-user-home"
if exist "C:\flutter_windows_3.41.6-stable\flutter\bin\flutter.bat" (
  set "FLUTTER_BIN=C:\flutter_windows_3.41.6-stable\flutter\bin\flutter.bat"
) else (
  set "FLUTTER_BIN=flutter"
)
"%FLUTTER_BIN%" %*
