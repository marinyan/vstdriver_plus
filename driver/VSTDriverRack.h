#pragma once
#include "VSTDriver.h"
#include "../common/ports.h"

// One isolated bridge per enabled MIDI port. Each bridge can use either VST2
// architecture; all four are mixed into the same hardware audio stream.
class VSTDriverRack {
    VSTDriver* ports[VST_MIDI_PORTS];
    std::vector<float> scratch, mixed;
    bool singlePort32Ch;
public:
    VSTDriverRack() : ports(), singlePort32Ch(false) {
        scratch.resize(4800 * 2);
        mixed.resize(4800 * 4);
    }
    ~VSTDriverRack() { for (unsigned p = 0; p < VST_MIDI_PORTS; ++p) delete ports[p]; }
    BOOL OpenVSTDriver(TCHAR*, int sampleRate) {
        DWORD mask = ReadEnabledPortMask();
        for (unsigned p = 0; p < VST_MIDI_PORTS; ++p) {
            if (!(mask & (1u << p))) continue;
            TCHAR path[MAX_PATH] = {0};
            if (ReadIndividualPortVst()) ReadPortPlugin(p, path);
            ports[p] = new VSTDriver;
            ports[p]->setRackPort(p);
            if (!ports[p]->OpenVSTDriver(path[0] ? path : NULL, sampleRate)) {
                TCHAR error[MAX_PATH + 120];
                _stprintf_s(error, _T("Cannot load the VST instrument for port %c.\r\n%s\r\nCheck this port in Config > Ports A-D."), _T('A') + p,
                    path[0] ? path : _T("Common VST settings"));
                MessageBox(NULL, error, _T("VST MIDI Driver"), MB_OK | MB_ICONERROR);
                return FALSE;
            }
        }
        return mask != 0;
    }
    bool getIsSCVA() {
        for (unsigned p = 0; p < VST_MIDI_PORTS; ++p) if (ports[p] && ports[p]->getIsSCVA()) return true;
        return false;
    }
    void setHighDpiMode(unsigned mode) {
        for (unsigned p = 0; p < VST_MIDI_PORTS; ++p) if (ports[p]) ports[p]->setHighDpiMode(mode);
    }
    void initSysTray() {
        for (unsigned p = 0; p < VST_MIDI_PORTS; ++p) if (ports[p]) ports[p]->initSysTray();
    }
    void displayEditorModal(unsigned p, HWND owner) {
        if (p < VST_MIDI_PORTS && ports[p]) ports[p]->displayEditorModal(0, owner);
    }
    void setSinglePort32ChMode() { singlePort32Ch = true; }
    void ResetDriver(unsigned p) {
        if (singlePort32Ch) {
            for (unsigned i = 0; i < 2; ++i) if (ports[i]) ports[i]->ResetDriver(0);
        } else if (p < VST_MIDI_PORTS && ports[p]) ports[p]->ResetDriver(0);
    }
    void ProcessMIDIMessage(DWORD p, DWORD message) {
        if (p < VST_MIDI_PORTS && ports[p]) ports[p]->ProcessMIDIMessage(0, message);
    }
    void ProcessSysEx(DWORD p, const unsigned char* bytes, int size) {
        if (p < VST_MIDI_PORTS && ports[p]) ports[p]->ProcessSysEx(0, bytes, size);
    }
    uint32_t RenderFloat(float* output, int frames, float gain, WORD channels) {
        memset(output, 0, size_t(frames) * channels * sizeof(float));
        uint32_t result = NoError;
        for (int offset = 0; offset < frames; offset += 4800) {
            int count = min(4800, frames - offset);
            for (unsigned p = 0; p < VST_MIDI_PORTS; ++p) {
                if (!ports[p]) continue;
                uint32_t code = ports[p]->RenderFloat(&scratch[0], count, gain, 2);
                if (code != NoError) result = code;
                unsigned pair = channels == 4 ? (p % 2) * 2 : 0;
                for (int frame = 0; frame < count; ++frame) {
                    output[(offset + frame) * channels + pair] += scratch[frame * 2];
                    output[(offset + frame) * channels + pair + 1] += scratch[frame * 2 + 1];
                }
            }
        }
        return result;
    }
    uint32_t Render(short* output, int frames, float gain, WORD channels) {
        uint32_t result = NoError;
        for (int offset = 0; offset < frames; offset += 4800) {
            int count = min(4800, frames - offset);
            uint32_t code = RenderFloat(&mixed[0], count, gain, channels);
            if (code != NoError) result = code;
            for (int sample = 0; sample < count * channels; ++sample) {
                float value = mixed[sample] * 32768.0f;
                output[offset * channels + sample] = short(max(-32768.0f, min(32767.0f, value)));
            }
        }
        return result;
    }
};
