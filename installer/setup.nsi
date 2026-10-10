Unicode true
!include MUI2.nsh
!include x64.nsh
!include WinVer.nsh
!include FileFunc.nsh
!include LogicLib.nsh
!addplugindir "..\stage\nsis"
!getdllversion "..\stage\vstmididrvcfg.exe" ver_
!define VERSION "${ver_1}.${ver_2}.${ver_3}.${ver_4}"
!define PRODUCT "vstdriver_plus (4 ports)"
!define UNKEY "Software\Microsoft\Windows\CurrentVersion\Uninstall\VST MIDI System Synth"
Name "${PRODUCT} ${VERSION}"
!ifdef TEST_INSTALLER
  RequestExecutionLevel user
  OutFile "..\dist\installer-test.exe"
!else
  RequestExecutionLevel admin
  OutFile "..\dist\vstdriver_plus-${VERSION}-Setup.exe"
!endif
InstallDir "$PROGRAMFILES32\vstdriver_plus"
ManifestDPIAware true
SetCompressor /SOLID lzma
VIProductVersion "${VERSION}"
VIAddVersionKey "ProductName" "${PRODUCT}"
VIAddVersionKey "FileDescription" "VST MIDI driver based on Falcosoft Falcomod"
VIAddVersionKey "FileVersion" "${VERSION}"
VIAddVersionKey "LegalCopyright" "Upstream: kode54, Arakula, DB50XG, Falcosoft and contributors"
!define MUI_ICON "..\drivercfg\install.ico"
!define MUI_UNICON "..\drivercfg\uninstall.ico"
!define MUI_WELCOMEPAGE_TEXT "Install the 4-port VST MIDI driver based on Falcosoft Falcomod.$\r$\n$\r$\nPlease close MIDI applications and the configuration tool before continuing.$\r$\n$\r$\nExisting VST and audio settings are preserved. VST instruments are not included."
!define MUI_FINISHPAGE_NOREBOOTSUPPORT
!define MUI_FINISHPAGE_TEXT "Open Configure VST MIDI Driver from the Start menu to choose your instrument and ports.$\r$\n$\r$\nRestart MIDI applications to use this version. If Windows reports files pending removal, restart Windows when convenient.$\r$\n$\r$\nWith thanks to Falcosoft and the original vstdriver contributors."
!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_LICENSE "..\LICENSE.txt"
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_PAGE_FINISH
!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES
!insertmacro MUI_LANGUAGE "English"
!insertmacro MUI_LANGUAGE "Japanese"
Var Root32
Var Root64
Var Source
Var Target
Var Backup
Var Count
Var Failure
!ifdef TEST_INSTALLER
Var TestFail
!endif

Function .onInit
  SetShellVarContext all
  ${IfNot} ${AtLeastWin10}
    MessageBox MB_OK|MB_ICONSTOP "Windows 10 or later is required." /SD IDOK
    Abort
  ${EndIf}
  ${If} ${IsNativeARM64}
    MessageBox MB_OK|MB_ICONSTOP "This build supports x86 and x64 Windows only." /SD IDOK
    Abort
  ${EndIf}
  StrCpy $Root32 "$SYSDIR"
  StrCpy $Root64 "$WINDIR\Sysnative"
  ${If} ${RunningX64}
    StrCpy $Root32 "$WINDIR\SysWOW64"
  ${EndIf}
!ifdef TEST_INSTALLER
  ; All filesystem operations are redirected; no registry/device operations.
  StrCpy $Root32 "$INSTDIR\x86"
  StrCpy $Root64 "$INSTDIR\x64"
  ${GetParameters} $0
  ${GetOptions} $0 "/FAIL=" $TestFail
!endif
FunctionEnd

; Transaction records are stored separately from the NSIS/plugin argument stack.
; Every old image is renamed before copying, allowing a loaded DLL to survive.
Function ReplaceFile
  ClearErrors
  ${GetParent} "$Target" $0
  CreateDirectory "$0"
  StrCpy $Backup ""
  ${If} ${FileExists} "$Target"
    GetTempFileName $Backup "$0"
    Delete "$Backup"
    ClearErrors
    Rename "$Target" "$Backup"
    ${If} ${Errors}
      StrCpy $Failure "Cannot replace $Target. Close applications using the driver and try again."
      Return
    ${EndIf}
  ${EndIf}
  IntOp $Count $Count + 1
  WriteINIStr "$PLUGINSDIR\transaction.ini" "$Count" "target" "$Target"
  WriteINIStr "$PLUGINSDIR\transaction.ini" "$Count" "backup" "$Backup"
  ClearErrors
  CopyFiles /SILENT "$Source" "$Target"
  ${If} ${Errors}
    StrCpy $Failure "Cannot copy $Source to $Target."
  ${EndIf}
FunctionEnd

Function Rollback
  ${DoWhile} $Count > 0
    ReadINIStr $Target "$PLUGINSDIR\transaction.ini" "$Count" "target"
    ReadINIStr $Backup "$PLUGINSDIR\transaction.ini" "$Count" "backup"
    Delete "$Target"
    ${If} $Backup != ""
      ClearErrors
      Rename "$Backup" "$Target"
      ${If} ${Errors}
        DetailPrint "RESTORE FAILED: $Backup -> $Target; keep this backup."
        StrCpy $Failure "$Failure$\r$\nRestore failed: $Backup -> $Target"
      ${EndIf}
    ${EndIf}
    IntOp $Count $Count - 1
  ${Loop}
FunctionEnd

Function Commit
  ${DoWhile} $Count > 0
    ReadINIStr $Backup "$PLUGINSDIR\transaction.ini" "$Count" "backup"
    ${If} $Backup != ""
!ifdef TEST_INSTALLER
      ; Tests never schedule system-wide reboot operations.
      Delete "$Backup"
!else
      Delete /REBOOTOK "$Backup"
!endif
    ${EndIf}
    IntOp $Count $Count - 1
  ${Loop}
FunctionEnd

!macro InstallOne SRC DST
  StrCpy $Source "${SRC}"
  StrCpy $Target "${DST}"
  Call ReplaceFile
  ${If} $Failure != ""
    Goto install_failed
  ${EndIf}
!macroend
!macro InstallArch ARCH ROOT
  !insertmacro InstallOne "$PLUGINSDIR\${ARCH}\vstmididrv.dll" "${ROOT}\vstmididrv.dll"
  !insertmacro InstallOne "$PLUGINSDIR\${ARCH}\vstmididrvcfg.exe" "${ROOT}\vstmididrv\vstmididrvcfg.exe"
  !insertmacro InstallOne "$PLUGINSDIR\${ARCH}\vstbridgeapp32.exe" "${ROOT}\vstmididrv\vstbridgeapp32.exe"
  !insertmacro InstallOne "$PLUGINSDIR\${ARCH}\vstbridgeapp64.exe" "${ROOT}\vstmididrv\vstbridgeapp64.exe"
  !insertmacro InstallOne "$PLUGINSDIR\${ARCH}\bassasio_vstdrv.dll" "${ROOT}\vstmididrv\bassasio_vstdrv.dll"
  !insertmacro InstallOne "$PLUGINSDIR\${ARCH}\ASIO2WASAPI_vstdrv.dll" "${ROOT}\vstmididrv\ASIO2WASAPI_vstdrv.dll"
!macroend

!macro InstallHelp ROOT
  !insertmacro InstallOne "$PLUGINSDIR\help\Readme.html" "${ROOT}\vstmididrv\Help\Readme.html"
  !insertmacro InstallOne "$PLUGINSDIR\help\Readme.css" "${ROOT}\vstmididrv\Help\Readme.css"
  !insertmacro InstallOne "$PLUGINSDIR\help\advredir.html" "${ROOT}\vstmididrv\Help\advredir.html"
  !insertmacro InstallOne "$PLUGINSDIR\help\background.jpg" "${ROOT}\vstmididrv\Help\background.jpg"
  !insertmacro InstallOne "$PLUGINSDIR\help\donate.gif" "${ROOT}\vstmididrv\Help\donate.gif"
  !insertmacro InstallOne "$PLUGINSDIR\help\play.png" "${ROOT}\vstmididrv\Help\play.png"
!macroend

Section "Driver"
  InitPluginsDir
  StrCpy $Count 0
  StrCpy $Failure ""
  SetOutPath "$PLUGINSDIR\x86"
  File "..\stage\vstmididrv.dll"
  File "..\stage\vstmididrvcfg.exe"
  File "..\stage\vstbridgeapp32.exe"
  File "..\stage\vstbridgeapp64.exe"
  File "..\stage\bassasio_vstdrv.dll"
  File "..\stage\ASIO2WASAPI_vstdrv.dll"
  SetOutPath "$PLUGINSDIR\x64"
  File "..\stage\64\vstmididrv.dll"
  File "..\stage\64\vstmididrvcfg.exe"
  File "..\stage\64\vstbridgeapp32.exe"
  File "..\stage\64\vstbridgeapp64.exe"
  File "..\stage\64\bassasio_vstdrv.dll"
  File "..\stage\64\ASIO2WASAPI_vstdrv.dll"
  SetOutPath "$PLUGINSDIR\docs"
  File "README-ja.txt"
  File "..\LICENSE.txt"
  File /oname=ASIO2WASAPI-LICENSE.txt "..\external_packages\ASIO2WASAPI_VSTDRIVER\LICENSE.txt"
  SetOutPath "$PLUGINSDIR\help"
  File "..\Help\*"
  !insertmacro InstallArch "x86" "$Root32"
  ${If} ${RunningX64}
    !insertmacro InstallArch "x64" "$Root64"
  ${EndIf}
  !insertmacro InstallOne "$PLUGINSDIR\docs\README-ja.txt" "$INSTDIR\README-ja.txt"
  !insertmacro InstallOne "$PLUGINSDIR\docs\LICENSE.txt" "$INSTDIR\LICENSE.txt"
  !insertmacro InstallOne "$PLUGINSDIR\docs\ASIO2WASAPI-LICENSE.txt" "$INSTDIR\ASIO2WASAPI-LICENSE.txt"
  !insertmacro InstallHelp "$Root32"
  ${If} ${RunningX64}
    !insertmacro InstallHelp "$Root64"
  ${EndIf}
!ifdef TEST_INSTALLER
  ${If} $TestFail == "1"
    StrCpy $Failure "Injected failure for rollback test."
    Goto install_failed
  ${EndIf}
!else
  ; Always supply the optional fifth argument, so plugin popParms cannot
  ; consume unrelated stack entries. Do not remove/re-register user settings.
  ummidiplg::SetupRegistry "vstmididrv.dll" "VST MIDI Driver" "Falcosoft / vstdriver_plus" "ROOT\vstmididrv" ""
  Pop $0
  ${If} $0 != "OK"
    StrCpy $Failure "$0 The files will be restored."
    Goto install_failed
  ${EndIf}
  Pop $1
  Pop $2
!endif
  ClearErrors
  WriteUninstaller "$PLUGINSDIR\Uninstall.exe"
  ${If} ${Errors}
    StrCpy $Failure "Cannot create uninstaller."
    Goto install_failed
  ${EndIf}
  !insertmacro InstallOne "$PLUGINSDIR\Uninstall.exe" "$INSTDIR\Uninstall.exe"
!ifndef TEST_INSTALLER
  SetRegView 32
  WriteRegStr HKLM "${UNKEY}" "DisplayName" "${PRODUCT}"
  WriteRegStr HKLM "${UNKEY}" "DisplayVersion" "${VERSION}"
  WriteRegStr HKLM "${UNKEY}" "Publisher" "vstdriver_plus contributors (based on Falcosoft Falcomod)"
  WriteRegStr HKLM "${UNKEY}" "UninstallString" '$\"$INSTDIR\Uninstall.exe$\"'
  WriteRegStr HKLM "${UNKEY}" "QuietUninstallString" '$\"$INSTDIR\Uninstall.exe$\" /S'
  WriteRegStr HKLM "${UNKEY}" "InstallLocation" "$INSTDIR"
  WriteRegStr HKLM "${UNKEY}" "DisplayIcon" "$Root32\vstmididrv\vstmididrvcfg.exe"
  WriteRegStr HKLM "${UNKEY}" "URLInfoAbout" "https://github.com/marinyan/vstdriver_plus"
  WriteRegDWORD HKLM "${UNKEY}" "NoModify" 1
  WriteRegDWORD HKLM "${UNKEY}" "NoRepair" 1
  WriteRegStr HKLM "Software\VST MIDI Driver" "path" "$Root32\vstmididrv"
  CreateDirectory "$SMPROGRAMS\VST MIDI System Synth"
  CreateShortCut "$SMPROGRAMS\VST MIDI System Synth\Configure VST MIDI Driver.lnk" "$Root32\vstmididrv\vstmididrvcfg.exe"
  CreateShortCut "$SMPROGRAMS\VST MIDI System Synth\ReadMe.lnk" "$INSTDIR\README-ja.txt"
  CreateShortCut "$SMPROGRAMS\VST MIDI System Synth\Uninstall.lnk" "$INSTDIR\Uninstall.exe"
!endif
  Call Commit
  SetErrorLevel 0
  Goto install_done
install_failed:
  Call Rollback
  DetailPrint "$Failure"
  MessageBox MB_OK|MB_ICONSTOP "$Failure" /SD IDOK
  SetErrorLevel 1
  Abort
install_done:
SectionEnd

!macro RemoveArch ROOT
  Delete /REBOOTOK "${ROOT}\vstmididrv.dll"
  Delete /REBOOTOK "${ROOT}\vstmididrv\vstmididrvcfg.exe"
  Delete /REBOOTOK "${ROOT}\vstmididrv\vstbridgeapp32.exe"
  Delete /REBOOTOK "${ROOT}\vstmididrv\vstbridgeapp64.exe"
  Delete /REBOOTOK "${ROOT}\vstmididrv\bassasio_vstdrv.dll"
  Delete /REBOOTOK "${ROOT}\vstmididrv\ASIO2WASAPI_vstdrv.dll"
  Delete "${ROOT}\vstmididrv\Help\Readme.html"
  Delete "${ROOT}\vstmididrv\Help\Readme.css"
  Delete "${ROOT}\vstmididrv\Help\advredir.html"
  Delete "${ROOT}\vstmididrv\Help\background.jpg"
  Delete "${ROOT}\vstmididrv\Help\donate.gif"
  Delete "${ROOT}\vstmididrv\Help\play.png"
  RMDir "${ROOT}\vstmididrv\Help"
  RMDir "${ROOT}\vstmididrv"
!macroend
Section "Uninstall"
  SetShellVarContext all
  StrCpy $Root32 "$SYSDIR"
  StrCpy $Root64 "$WINDIR\Sysnative"
  ${If} ${RunningX64}
    StrCpy $Root32 "$WINDIR\SysWOW64"
  ${EndIf}
!ifdef TEST_INSTALLER
  StrCpy $Root32 "$INSTDIR\x86"
  StrCpy $Root64 "$INSTDIR\x64"
!else
  ummidiplg::CleanupRegistry "vstmididrv.dll" "VST MIDI Driver" "ROOT\vstmididrv" ""
  Pop $0
  ${If} $0 != "OK"
    MessageBox MB_OK|MB_ICONSTOP "$0" /SD IDOK
    SetErrorLevel 1
    Abort
  ${EndIf}
  SetRegView 32
  DeleteRegKey HKLM "${UNKEY}"
  DeleteRegKey HKLM "Software\VST MIDI Driver"
  ; Remove legacy Control Panel links that point to the same removed config.
  DeleteRegKey HKLM "SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\ControlPanel\NameSpace\{E33B77CA-8645-49E7-8CBD-1E39673C8C43}"
  DeleteRegKey HKLM "SOFTWARE\Classes\CLSID\{E33B77CA-8645-49E7-8CBD-1E39673C8C43}"
  ${If} ${RunningX64}
    SetRegView 64
    DeleteRegKey HKLM "SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\ControlPanel\NameSpace\{E33B77CA-8645-49E7-8CBD-1E39673C8C43}"
    DeleteRegKey HKLM "SOFTWARE\Classes\CLSID\{E33B77CA-8645-49E7-8CBD-1E39673C8C43}"
    SetRegView 32
  ${EndIf}
  Delete "$SMPROGRAMS\VST MIDI System Synth\Configure VST MIDI Driver.lnk"
  Delete "$SMPROGRAMS\VST MIDI System Synth\Configure VST MIDI Driver (x64).lnk"
  Delete "$SMPROGRAMS\VST MIDI System Synth\ReadMe.lnk"
  Delete "$SMPROGRAMS\VST MIDI System Synth\Uninstall.lnk"
  RMDir "$SMPROGRAMS\VST MIDI System Synth"
!endif
  !insertmacro RemoveArch "$Root32"
  ${If} ${RunningX64}
    !insertmacro RemoveArch "$Root64"
  ${EndIf}
  Delete "$INSTDIR\README-ja.txt"
  Delete "$INSTDIR\LICENSE.txt"
  Delete "$INSTDIR\ASIO2WASAPI-LICENSE.txt"
  Delete /REBOOTOK "$INSTDIR\Uninstall.exe"
  RMDir "$INSTDIR"
  SetErrorLevel 0
SectionEnd
