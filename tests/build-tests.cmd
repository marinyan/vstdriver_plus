@echo off
setlocal
call "C:\Program Files\Microsoft Visual Studio\18\Community\VC\Auxiliary\Build\vcvarsall.bat" %1 >nul
if errorlevel 1 exit /b 1
cd /d "%~dp0"
cl /nologo /O2 /EHsc /DUNICODE /D_UNICODE port-enumeration.cpp /Fe:port-enumeration-%1.exe /Fo:port-enumeration-%1.obj /link advapi32.lib
exit /b %errorlevel%
