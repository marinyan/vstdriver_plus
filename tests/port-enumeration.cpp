#include <windows.h>
#include <mmsystem.h>
#include <mmddk.h>
#include <tchar.h>
#include <stdio.h>
#include <stdlib.h>
typedef DWORD (WINAPI* ModMessage)(DWORD,DWORD,DWORD_PTR,DWORD_PTR,DWORD_PTR);
int wmain(int argc, wchar_t** argv) {
    if (argc!=3) return 2;
    DWORD mask = wcstoul(argv[2],NULL,0);
    // Redirect HKCU inside this test process only. User configuration is untouched.
    wchar_t path[128]; swprintf_s(path,L"Software\\VSTDriverPortTest-%lu",GetCurrentProcessId());
    HKEY testRoot,settings;
    if(RegCreateKeyExW(HKEY_CURRENT_USER,path,0,NULL,0,KEY_ALL_ACCESS,NULL,&testRoot,NULL)) return 3;
    if(RegOverridePredefKey(HKEY_CURRENT_USER,testRoot)) return 4;
    RegCreateKeyExW(HKEY_CURRENT_USER,L"Software\\VSTi Driver",0,NULL,0,KEY_ALL_ACCESS|KEY_WOW64_32KEY,NULL,&settings,NULL);
    RegSetValueExW(settings,L"EnabledPortMask",0,REG_DWORD,(BYTE*)&mask,sizeof(mask));
    HMODULE module=LoadLibraryW(argv[1]);
    ModMessage message=module ? (ModMessage)GetProcAddress(module,"modMessage") : NULL;
    int failures=0;
    if (!message) { wprintf(L"Load failed %lu\n",GetLastError()); failures++; }
    else {
        DWORD count=message(0,MODM_GETNUMDEVS,0,0,0),expected=0;
        for(DWORD port=0;port<4;++port) if(mask&(1u<<port)) {
            MIDIOUTCAPS2W caps={};
            if(message(expected,MODM_GETDEVCAPS,0,(DWORD_PTR)&caps,sizeof(caps))) failures++;
            wchar_t name[32]; swprintf_s(name,L"VST MIDI Synth (port %c)",L'A'+port);
            if(wcscmp(caps.szPname,name)) failures++;
            wprintf(L"%lu=%ls ",expected,caps.szPname);
            expected++;
        }
        if(count!=expected) failures++;
        if(message(count,MODM_GETDEVCAPS,0,0,0)!=MMSYSERR_BADDEVICEID) failures++;
        DWORD off=0;
        RegSetValueExW(settings,L"EnabledPortMask",0,REG_DWORD,(BYTE*)&off,sizeof(off));
        // Enumeration must stay stable, while newly disabled opens are rejected.
        if(message(0,MODM_GETNUMDEVS,0,0,0)!=expected) failures++;
        for(DWORD i=0;i<count;++i)
            if(message(i,MODM_OPEN,0,0,0)!=MMSYSERR_NOTENABLED) failures++;
        if(!count && message(0,MODM_OPEN,0,0,0)!=MMSYSERR_BADDEVICEID) failures++;
        wprintf(L"mask=%lu count=%lu failures=%d\n",mask,count,failures);
        FreeLibrary(module);
    }
    RegCloseKey(settings);
    RegOverridePredefKey(HKEY_CURRENT_USER,NULL);
    RegCloseKey(testRoot);
    RegDeleteTreeW(HKEY_CURRENT_USER,path);
    return failures ? 1 : 0;
}
