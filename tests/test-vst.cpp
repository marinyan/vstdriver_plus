#include <windows.h>
#include "../external_packages/aeffectx.h"
#include <cstring>
struct Instrument { AEffect effect; bool sounding; };
static VstIntPtr VSTCALLBACK Dispatch(AEffect* effect, VstInt32 op, VstInt32, VstIntPtr, void* ptr, float) {
    Instrument* inst = reinterpret_cast<Instrument*>(effect);
    switch (op) {
    case effClose: delete inst; return 0;
    case effGetPlugCategory: return kPlugCategSynth;
    case effCanDo: return 1;
    case effGetEffectName: case effGetProductString: strcpy_s((char*)ptr, 32, "Port isolation test"); return 1;
    case effGetVendorString: strcpy_s((char*)ptr, 32, "Local test fixture"); return 1;
    case effProcessEvents:
        for(int i=0; i<((VstEvents*)ptr)->numEvents; ++i) {
            VstEvent* ev=((VstEvents*)ptr)->events[i];
            if(ev->type==kVstSysExType) inst->sounding=false;
            if(ev->type!=kVstMidiType) continue;
            unsigned char* bytes=(unsigned char*)((VstMidiEvent*)ev)->midiData;
            if((bytes[0]&0xf0)==0x90) inst->sounding=bytes[2]!=0;
            if((bytes[0]&0xf0)==0x80 || ((bytes[0]&0xf0)==0xb0 && bytes[1]>=120)) inst->sounding=false;
        }
    }
    return 0;
}
static void VSTCALLBACK Process(AEffect* effect, float**, float** out, VstInt32 frames) {
#ifdef _WIN64
    const float level=0.03125f;
#else
    const float level=0.0625f;
#endif
    float value=reinterpret_cast<Instrument*>(effect)->sounding ? level : 0;
    for(int i=0;i<frames;++i) { out[0][i]=value; out[1][i]=value*0.5f; }
}
extern "C" __declspec(dllexport) AEffect* VSTPluginMain(audioMasterCallback) {
    Instrument* inst=new Instrument();
    inst->effect.magic=kEffectMagic;
    inst->effect.dispatcher=Dispatch;
    inst->effect.processReplacing=Process;
    inst->effect.numOutputs=2;
    inst->effect.flags=effFlagsIsSynth|effFlagsCanReplacing;
    inst->effect.uniqueID='tst4';
    return &inst->effect;
}
