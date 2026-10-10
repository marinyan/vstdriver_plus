"""Integration tests for the TEST_INSTALLER build: no system/registry writes."""
import ctypes
from pathlib import Path
import hashlib
import json
import subprocess
import tempfile
import time

repo = Path(__file__).resolve().parents[1]
setup = repo / 'dist' / 'installer-test.exe'
root = Path(tempfile.mkdtemp(prefix='vstdriver-plus-installer-'))
target = root / 'install'

def run(*options):
    return subprocess.run([str(setup), '/S', *options, '/D=' + str(target)], timeout=30).returncode

def hashes():
    return {str(p.relative_to(target)): hashlib.sha256(p.read_bytes()).hexdigest()
            for p in target.rglob('*') if p.is_file()}

assert run() == 0, 'fresh install'
for arch, stage in [('x86', repo / 'stage'), ('x64', repo / 'stage' / '64')]:
    for name in ['vstmididrv.dll', 'vstmididrvcfg.exe', 'vstbridgeapp32.exe',
                 'vstbridgeapp64.exe', 'bassasio_vstdrv.dll', 'ASIO2WASAPI_vstdrv.dll']:
        installed = target / arch / (name if name == 'vstmididrv.dll' else 'vstmididrv/' + name)
        assert installed.read_bytes() == (stage / name).read_bytes(), installed
print('PASS fresh install: x86/x64 payload hashes')

# Simulate an actual older payload so rollback cannot pass by reinstalling new bytes.
old = target / 'x86' / 'vstmididrv' / 'vstmididrvcfg.exe'
old.write_bytes(b'old-version-sentinel')
before = hashes()
assert run('/FAIL=1') == 1, 'injected failure exit code'
assert hashes() == before, 'rollback must restore every original byte and remove new files'
print('PASS late failure: complete rollback')

k32 = ctypes.WinDLL('kernel32', use_last_error=True)
k32.CreateFileW.argtypes = [ctypes.c_wchar_p, ctypes.c_uint32, ctypes.c_uint32,
    ctypes.c_void_p, ctypes.c_uint32, ctypes.c_uint32, ctypes.c_void_p]
k32.CreateFileW.restype = ctypes.c_void_p
k32.CloseHandle.argtypes = [ctypes.c_void_p]
handle = k32.CreateFileW(str(old), 0x80000000, 0, None, 3, 0, None)
assert handle != ctypes.c_void_p(-1).value
try:
    assert run() == 1, 'locked file must fail safely'
finally:
    k32.CloseHandle(handle)
assert hashes() == before, 'earlier replaced DLL must be restored after lock failure'
print('PASS exclusive file lock: rollback and error exit')

assert run() == 0, 'upgrade'
assert old.read_bytes() == (repo / 'stage' / 'vstmididrvcfg.exe').read_bytes()
print('PASS upgrade')

# Load an actual installed image; the update must keep it alive under its temp name.
k32.LoadLibraryW.argtypes = [ctypes.c_wchar_p]
k32.LoadLibraryW.restype = ctypes.c_void_p
k32.FreeLibrary.argtypes = [ctypes.c_void_p]
module = k32.LoadLibraryW(str(target / 'x64' / 'vstmididrv.dll'))
assert module
try:
    assert run() == 0, 'loaded-image upgrade'
finally:
    k32.FreeLibrary(module)
print('PASS loaded DLL update')

# User-owned files must survive uninstall, even inside the application's folder.
keep = target / 'user-instrument.dll'
keep.write_bytes(b'not part of the installer')
result = subprocess.run([str(target / 'Uninstall.exe'), '/S'], timeout=30)
assert result.returncode == 0
for attempt in range(100):
    if not (target / 'x86' / 'vstmididrv.dll').exists():
        break
    time.sleep(0.1)
assert not (target / 'x86' / 'vstmididrv.dll').exists()
assert not (target / 'x64' / 'vstmididrv.dll').exists()
assert keep.read_bytes() == b'not part of the installer'
print('PASS uninstall preserves unowned files')
print(json.dumps({'test_root': str(root), 'success': True}))
