#pragma once

// Stable physical identities. WinMM exposes only the enabled subset.
#define VST_MIDI_PORTS 4
#define VST_MIDI_DEFAULT_PORT_MASK 3
#define WM_VST_PORT_SETTINGS_CHANGED (WM_APP + 71)

inline bool ReadIndividualPortVst()
{
    DWORD value = 0, size = sizeof(value), type = 0;
    HKEY key;
    if (RegOpenKeyEx(HKEY_CURRENT_USER, _T("Software\\VSTi Driver"), 0,
        KEY_QUERY_VALUE | KEY_WOW64_32KEY, &key) == ERROR_SUCCESS) {
        if (RegQueryValueEx(key, _T("IndividualPortVst"), NULL, &type,
            reinterpret_cast<BYTE*>(&value), &size) != ERROR_SUCCESS || type != REG_DWORD) value = 0;
        RegCloseKey(key);
    }
    return value != 0;
}

inline void ReadCommonPlugin(TCHAR (&path)[MAX_PATH])
{
    path[0] = 0;
    HKEY key;
    if (RegOpenKeyEx(HKEY_CURRENT_USER, _T("Software\\VSTi Driver"), 0,
        KEY_QUERY_VALUE | KEY_WOW64_32KEY, &key) != ERROR_SUCCESS) return;
    DWORD selected = 0, size = sizeof(selected), type;
    RegQueryValueEx(key, _T("SelectedPlugin"), NULL, NULL, reinterpret_cast<BYTE*>(&selected), &size);
    TCHAR name[32] = _T("plugin");
    if (selected) _stprintf_s(name, _T("plugin%u"), selected);
    size = sizeof(path);
    if (RegQueryValueEx(key, name, NULL, &type, reinterpret_cast<BYTE*>(path), &size) != ERROR_SUCCESS || type != REG_SZ) path[0] = 0;
    path[MAX_PATH - 1] = 0;
    RegCloseKey(key);
}

inline DWORD ReadEnabledPortMask()
{
    DWORD mask = VST_MIDI_DEFAULT_PORT_MASK, size = sizeof(mask), type = 0;
    HKEY key;
    if (RegOpenKeyEx(HKEY_CURRENT_USER, _T("Software\\VSTi Driver"), 0,
        KEY_QUERY_VALUE | KEY_WOW64_32KEY, &key) == ERROR_SUCCESS)
    {
        DWORD value = mask;
        if (RegQueryValueEx(key, _T("EnabledPortMask"), NULL, &type,
            reinterpret_cast<BYTE*>(&value), &size) == ERROR_SUCCESS &&
            type == REG_DWORD && size == sizeof(value)) mask = value;
        RegCloseKey(key);
    }
    return mask & ((1u << VST_MIDI_PORTS) - 1);
}

inline LONG WriteEnabledPortMask(DWORD mask)
{
    HKEY key;
    LONG result = RegCreateKeyEx(HKEY_CURRENT_USER, _T("Software\\VSTi Driver"),
        0, NULL, 0, KEY_SET_VALUE | KEY_WOW64_32KEY, NULL, &key, NULL);
    if (result != ERROR_SUCCESS) return result;
    mask &= (1u << VST_MIDI_PORTS) - 1;
    result = RegSetValueEx(key, _T("EnabledPortMask"), 0, REG_DWORD,
        reinterpret_cast<const BYTE*>(&mask), sizeof(mask));
    RegCloseKey(key);
    return result;
}

inline void ReadPortPlugin(unsigned port, TCHAR (&path)[MAX_PATH])
{
    path[0] = 0;
    HKEY key;
    if (RegOpenKeyEx(HKEY_CURRENT_USER, _T("Software\\VSTi Driver"), 0,
        KEY_QUERY_VALUE | KEY_WOW64_32KEY, &key) != ERROR_SUCCESS) return;
    TCHAR name[] = _T("PortPluginA");
    name[_countof(name) - 2] += TCHAR(port);
    DWORD type = 0, size = sizeof(path);
    if (RegQueryValueEx(key, name, NULL, &type, reinterpret_cast<BYTE*>(path), &size) != ERROR_SUCCESS || type != REG_SZ)
        path[0] = 0;
    path[MAX_PATH - 1] = 0;
    RegCloseKey(key);
}

inline LONG WritePortPlugin(unsigned port, const TCHAR* path)
{
    HKEY key;
    LONG result = RegCreateKeyEx(HKEY_CURRENT_USER, _T("Software\\VSTi Driver"),
        0, NULL, 0, KEY_SET_VALUE | KEY_WOW64_32KEY, NULL, &key, NULL);
    if (result != ERROR_SUCCESS) return result;
    TCHAR name[] = _T("PortPluginA");
    name[_countof(name) - 2] += TCHAR(port);
    result = RegSetValueEx(key, name, 0, REG_SZ, reinterpret_cast<const BYTE*>(path),
        DWORD((_tcslen(path) + 1) * sizeof(TCHAR)));
    RegCloseKey(key);
    return result;
}
