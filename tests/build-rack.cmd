@echo off
setlocal
call "C:\Program Files\Microsoft Visual Studio\18\Community\VC\Auxiliary\Build\vcvarsall.bat" %1 >nul
if errorlevel 1 exit /b 1
cd /d "%~dp0"
cl /nologo /O2 /EHsc /LD test-vst.cpp /Fe:test-vst-%1.dll /Fo:test-vst-%1.obj /link /EXPORT:VSTPluginMain
if errorlevel 1 exit /b 1
cl /nologo /O2 /EHsc /DUNICODE /D_UNICODE /D_CRT_SECURE_NO_WARNINGS rack-ports.cpp ..\driver\VSTDriver.cpp /Fe:rack-ports-%1.exe /link advapi32.lib ole32.lib user32.lib comdlg32.lib winmm.lib
exit /b %errorlevel%
