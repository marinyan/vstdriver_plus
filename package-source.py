"""Package the source tree and submodule sources without local paths/settings."""
from pathlib import Path
import hashlib
import subprocess
import zipfile

root = Path(__file__).resolve().parent
tracked = subprocess.check_output(
    ['git', '-C', str(root), 'ls-files', '--recurse-submodules', '-z'])
paths = {p.decode('utf-8') for p in tracked.split(b'\0') if p}
paths.update(['build-local.ps1', 'build-installer.ps1', 'package-source.py',
              'common/ports.h', 'driver/VSTDriverRack.h', 'tests/installer-test.py',
              'tests/test-vst.cpp', 'tests/rack-ports.cpp', 'tests/port-enumeration.cpp',
              'tests/build-tests.cmd', 'tests/build-rack.cmd'])
paths.update(str(p.relative_to(root)).replace('\\', '/')
             for p in (root / 'installer').rglob('*') if p.is_file())
# Local IDE state is not needed to rebuild.
paths = {p for p in paths if not p.endswith(('.suo', '.user', '.vspscc'))}
archive = root / 'dist' / 'vstdriver_plus-2.6.1.2-source.zip'
with zipfile.ZipFile(archive, 'w', zipfile.ZIP_DEFLATED) as output:
    for relative in sorted(paths):
        source = root / relative
        if not source.is_file():
            raise FileNotFoundError(source)
        output.write(source, 'vstdriver_plus/' + relative)
with zipfile.ZipFile(archive) as check:
    assert check.testzip() is None
    assert not any('SGP2.DLL' in n.upper() for n in check.namelist())
archive.with_suffix('.zip.sha256').write_text(
    hashlib.sha256(archive.read_bytes()).hexdigest() + '  ' + archive.name + '\n',
    encoding='ascii')
print(f'{archive}: {len(paths)} files, {archive.stat().st_size} bytes')
