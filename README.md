# vstdriver_plus — 4-port VST MIDI driver

This edition is based on [Falcosoft's Falcomod](https://github.com/Falcosoft/vstdriver)
(commit `0069a1682b06e45746635daaa8b5a8ce468146a6`), building on Arakula's vstdriver.
It adds four native WinMM MIDI ports (A–D), selectable port enablement, and optional
independent VST2 instruments for each port. Disabling individual settings applies
the Basic VST to every enabled port while preserving each port's saved path.

## 謝辞 / Acknowledgements

Falcosoft / Zoltán Bacskó に深く感謝します。Falcomodでの音声出力、MIDIタイミング、
互換性などの改良とソースコードの公開が、今回の低遅延動作と機能追加の土台になっています。
Chris Moeller、Brad Miller、Christopher Snowhill (kode54)、Hermann Seib (Arakula)、
DB50XG、およびその他のvstdriver貢献者にも感謝します。

Many thanks to Falcosoft for the Falcomod improvements and for making the source
available, and to all original vstdriver contributors. These additional changes
are maintained in vstdriver_plus; this is not an official upstream release.
Original copyright notices and licenses are retained below and in LICENSE.txt.

## Building this edition

Tested toolchain: Visual Studio 2026 C++/ATL (v145), Windows SDK 10.0.26100.0,
and NSIS 3.11. Clone with submodules (`git clone --recursive`). Then run:

```powershell
.\build-installer.ps1 -NsisPath 'C:\Program Files (x86)\NSIS\makensis.exe'
```

This builds the x86/x64 driver, both VST bridge hosts, the configuration tools,
and the registration plugin, then creates `dist/vstdriver_plus-2.6.1.2-Setup.exe`.
The installer targets x86/x64 Windows 10/11 and retains existing user settings.
SGP2 and other VST instruments are not included. The bundled BASSASIO binary has
its own license; see [installation notes and acknowledgements](installer/README-ja.txt).

The new installer uses standard NSIS plugins and does not need LockedList.
Run `build-installer.ps1 -SkipBuild -TestInstaller` followed by
`python tests/installer-test.py` for isolated file installation, upgrade, rollback,
loaded-DLL update and uninstall tests. This test build skips real device/registry
registration; a clean Windows installation still requires a separate smoke test.

## Upstream documentation

# vstdriver - MIDI synthesizer driver for VST Instruments

A Windows user-mode software MIDI synthesizer driver which is capable of using any 32 or 64 bit VST Instrument

Copyright (C) 2011 Chris Moeller, Brad Miller  
... and maybe others; this seems to be a more or less abandoned project.
The above is the copyright notice I found in readme.txt.

Based on the Github project history:  
Parts Copyright (c) 2013-2021 Christopher Snowhill (kode54)

And finally:  
Parts Copyright (c) 2021 Hermann Seib

After the above:
Parts Copyright (c) 2023 Zoltán Bacsko (Falcosoft) 

## Building

Currently, the following development environments are supported:  
Visual Studio 2008, Visual Studio 2017-2022 
In theory, VS2010-VS2015 should work, too, but I didn't investigate that.

Falcosoft: Visual studio 2005 also works with the vstdriver.08.sln solution file.
Visual Studio 2005 can be used to build WinNT4 SP6 compatible version of the driver.

### Additional requirements

To build it, you need the following software installed:

#### Nullsoft Scriptable Install System (NSIS) V3.0a or higher
See https://sourceforge.net/projects/nsis/  
Additionally, the locked-list plug-in needs to be installed; you can get that from
https://nsis.sourceforge.io/LockedList_plug-in  
After having fetched the plug-in, copy its contents into the NSIS installation directory.

Then, from the NSIS installation directory, you have to copy the contents of the Examples\Plugin\nsis folder into this project's ummidiplg\nsis subdirectory. Since they may vary between NSIS installer versions, I didn't want to include them directly.


## Falcosoft:
Windows Template Library 9.1 headers have been integrated to the project since they work with all versions of Visual Studio
and can be used to compile a driver that is compatible with all supported Windows versions (from WinNT4 SP6 to Win11). 

The version forked by Arakula (Hermann Seib) used the Bass/Basswasapi libraries to produce audio.
There were 2 serious problems with this approach:

1. VST Midi driver is an in-process driver. It cannot use its own Bass libraries if the Midi client already uses some other versions of Bass libraries.
https://www.vogons.org/viewtopic.php?p=596545#p596545

This is also true the other way around: If a Midi client uses VST Midi driver then it cannot use its own Bass libraries afterward since the libraries are already loaded to the client's address space through VST Midi driver. 
https://www.vogons.org/viewtopic.php?p=1066041#p1066041

Both situations can cause subtle and hard to debug problems.

2. Midi precision depends on Bass update periods that are 5-10 ms at best case. 
This Midi precision depends on Bass update periods problem has already been fixed by Ian for BassMidi (async mode) and by me in my Bass_VST version but unfortunately none of them applies to VST Midi drivers using Bass libraries. 
https://www.un4seen.com/forum/?topic=18485.msg129797#msg129797

https://www.un4seen.com/forum/?topic=19639.msg137463#msg137463

Interestingly the previous version that used traditional WaveOut also used timestamped Midi messages and waveOutGetPosition to achieve perfect Midi timing/precision.
So I restored the WaveOut version that cures both problems listed above. 
The only drawback would be higher latency but the fun fact is that because of missing proper configuration (BASS_CONFIG_BUFFER) and some path reelated bugs the Arakula version that used Bass/Basswasapi had a terrible 500ms latenccy.
So actually the WaveOut version has also much better latency now.

PS:
Further info can be found on the Wiki page:  
https://github.com/Falcosoft/vstdriver/wiki
