@echo off
pushd "%~dp0.."
if not exist build\tools mkdir build\tools
odin run tools\build.odin -file -out:build\tools\build.exe -- %*
set EXIT_CODE=%ERRORLEVEL%
popd
exit /b %EXIT_CODE%
