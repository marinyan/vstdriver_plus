param([string]$NsisPath, [switch]$SkipBuild, [switch]$TestInstaller)
$ErrorActionPreference = 'Stop'
$buildRoot = $PSScriptRoot
if (!$NsisPath) {
    $candidates = @(
        (Join-Path ${env:ProgramFiles(x86)} 'NSIS\makensis.exe'),
        (Join-Path $env:ProgramFiles 'NSIS\makensis.exe'),
        (Join-Path $buildRoot '..\vstdriver\.build-deps\nsis\nsis-3.11\makensis.exe')
    )
    $NsisPath = $candidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
}
if (!$NsisPath -or !(Test-Path -LiteralPath $NsisPath)) {
    throw 'Install NSIS 3.11 or supply -NsisPath C:\path\to\makensis.exe.'
}
$NsisPath = (Resolve-Path -LiteralPath $NsisPath).Path
$sdk = Join-Path (Split-Path -Parent $NsisPath) 'Examples\Plugin\nsis'
Copy-Item -Path "$sdk\*" -Destination (Join-Path $buildRoot 'ummidiplg\nsis') -Force
if (!$SkipBuild) { & (Join-Path $buildRoot 'build-local.ps1') }
$vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
$vsPath = & $vswhere -latest -products '*' -property installationPath
$msbuild = Join-Path $vsPath 'MSBuild\Current\Bin\MSBuild.exe'
$buildArgs = @((Join-Path $buildRoot 'ummidiplg\ummidiplg.vcxproj'),
    '/m', '/nr:false', '/nologo', '/v:minimal', '/p:Configuration=ReleaseUnicode',
    '/p:Platform=Win32', '/p:PlatformToolset=v145', '/p:WindowsTargetPlatformVersion=10.0.26100.0',
    '/p:UseOfMfc=false', '/p:UseOfAtl=false',
    "/p:OutDir=$buildRoot\stage\nsis\", "/p:IntDir=$buildRoot\.build-obj\ummidiplg\")
& $msbuild @buildArgs
if ($LASTEXITCODE -ne 0) { throw 'MIDI registration plugin build failed.' }
New-Item -ItemType Directory -Force -Path (Join-Path $buildRoot 'dist') | Out-Null
$nsisArgs = @('/INPUTCHARSET', 'UTF8', '/V3')
if ($TestInstaller) { $nsisArgs += '/DTEST_INSTALLER' }
$nsisArgs += Join-Path $buildRoot 'installer\setup.nsi'
& $NsisPath @nsisArgs
if ($LASTEXITCODE -ne 0) { throw 'Installer build failed.' }
if (!$TestInstaller) {
    $version = (Get-Item -LiteralPath (Join-Path $buildRoot 'stage\vstmididrvcfg.exe')).VersionInfo.FileVersion -replace ',\s*','.'
    $setup = Join-Path $buildRoot "dist\vstdriver_plus-$version-Setup.exe"
    $hash = Get-FileHash -LiteralPath $setup -Algorithm SHA256
    "$($hash.Hash.ToLowerInvariant())  $([IO.Path]::GetFileName($setup))" |
        Set-Content -LiteralPath "$setup.sha256" -Encoding ascii
    Write-Host "Built: $setup"
}
