#include <windows.h>
#include <tchar.h>
#include <stdio.h>
#include <cmath>
#include <algorithm>
#include "../driver/VSTDriverRack.h"
extern "C" { HINSTANCE hinst_vst_driver = NULL; }
static void SetString(HKEY key,const wchar_t* name,const wchar_t* text) {
    RegSetValueExW(key,name,0,REG_SZ,(BYTE*)text,DWORD((wcslen(text)+1)*2));
}
static void Require(bool success,const char* label) {
    if(!success) { printf("FAIL: %s\n",label); ExitProcess(1); }
}
int wmain(int argc,wchar_t** argv) {
    if(argc!=5) return 2;
    hinst_vst_driver=LoadLibraryW(argv[1]);
    Require(hinst_vst_driver!=NULL,"load driver for bridge path");
    wchar_t path[128]; swprintf_s(path,L"Software\\VSTDriverRackTest-%lu",GetCurrentProcessId());
    HKEY testRoot,settings;
    Require(!RegCreateKeyExW(HKEY_CURRENT_USER,path,0,NULL,0,KEY_ALL_ACCESS,NULL,&testRoot,NULL),"create isolated settings");
    RegOverridePredefKey(HKEY_CURRENT_USER,testRoot);
    RegCreateKeyExW(HKEY_CURRENT_USER,L"Software\\VSTi Driver",0,NULL,0,KEY_ALL_ACCESS|KEY_WOW64_32KEY,NULL,&settings,NULL);
    DWORD mask=15;
    RegSetValueExW(settings,L"EnabledPortMask",0,REG_DWORD,(BYTE*)&mask,4);
    DWORD individual=1;
    RegSetValueExW(settings,L"IndividualPortVst",0,REG_DWORD,(BYTE*)&individual,4);
    SetString(settings,L"plugin",argv[2]);
    SetString(settings,L"PortPluginC",argv[3]);
    SetString(settings,L"PortPluginD",argv[4]);
    {
        VSTDriverRack rack;
        Require(rack.OpenVSTDriver(NULL,48000),"open SGP2 A/B, x64 C, x86 D");
        float audio[960];
        auto render=[&]() { Require(rack.RenderFloat(audio,480,1,2)==0,"render"); };
        render();
        rack.ProcessMIDIMessage(2,0x00403c90); render();
        Require(fabs(audio[0]-0.03125f)<1e-7,"C uses x64 VST");
        rack.ProcessMIDIMessage(3,0x00403c90); render();
        Require(fabs(audio[0]-0.09375f)<1e-7,"C+D independent sum");
        rack.ProcessMIDIMessage(2,0x0078b0); render();
        Require(fabs(audio[0]-0.0625f)<1e-7,"C off does not silence D");
        rack.ProcessMIDIMessage(3,0x0078b0); render();
        Require(fabs(audio[0])<1e-7,"both off");
        unsigned char xg[]={0xf0,0x43,0x10,0x4c,0,0,0x7e,0,0xf7};
        rack.ProcessSysEx(0,xg,sizeof(xg)); rack.ProcessMIDIMessage(0,0x00503c90);
        bool audible=false;
        for(int i=0;i<20;++i) { render(); for(float sample:audio) audible |= fabs(sample)>1e-4; }
        Require(audible,"real SGP2 default A audible");
        rack.ProcessMIDIMessage(0,0x0078b0);
        rack.ProcessSysEx(1,xg,sizeof(xg)); rack.ProcessMIDIMessage(1,0x00504090);
        audible=false;
        for(int i=0;i<20;++i) { render(); for(float sample:audio) audible |= fabs(sample)>1e-4; }
        Require(audible,"real SGP2 default B audible");
        rack.ProcessMIDIMessage(1,0x0078b0);
        for(int i=0;i<100;++i) render();
        printf("PASS: A/B real SGP2, C x64, D x86, independent MIDI and audio mix\n");
    }
    // With individual mode OFF, stale overrides must not affect any port.
    individual=0;
    RegSetValueExW(settings,L"IndividualPortVst",0,REG_DWORD,(BYTE*)&individual,4);
    SetString(settings,L"plugin",argv[3]); // All enabled ports use the x64 fixture.
    SetString(settings,L"PortPluginA",L"Z:\\missing-vst.dll");
    {
        VSTDriverRack rack;
        Require(rack.OpenVSTDriver(NULL,48000),"common mode ignores invalid individual override");
        float audio[960];
        for(unsigned p=0;p<4;++p) {
            rack.ProcessMIDIMessage(p,0x00403c90);
            Require(rack.RenderFloat(audio,480,1,2)==0,"common mode render");
            Require(fabs(audio[0]-0.03125f*(p+1))<1e-7,"common VST applies to all ports");
        }
        printf("PASS: Basic/common mode applies one VST to A-D and ignores preserved overrides\n");
    }
    RegCloseKey(settings); RegOverridePredefKey(HKEY_CURRENT_USER,NULL); RegCloseKey(testRoot);
    RegDeleteTreeW(HKEY_CURRENT_USER,path);
    FreeLibrary(hinst_vst_driver);
    return 0;
}
