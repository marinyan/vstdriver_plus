$ErrorActionPreference = 'Stop'
$buildRoot = $PSScriptRoot
$vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
$vsPath = & $vswhere -latest -products '*' -property installationPath
$msbuild = Join-Path $vsPath 'MSBuild\Current\Bin\MSBuild.exe'
$logDir = Join-Path $buildRoot 'build-logs'
New-Item -ItemType Directory -Force -Path $logDir | Out-Null
function Build-Project($project, $platform, $target, $outRelative) {
    $logName = "$target-$platform.log"
    $buildArgs = @($project, '/m', '/nr:false', '/nologo', '/v:minimal',
        '/p:Configuration=Release', "/p:Platform=$platform",
        '/p:PlatformToolset=v145', '/p:WindowsTargetPlatformVersion=10.0.26100.0',
        '/p:UseOfMfc=false', '/p:UseOfAtl=false',
        "/p:SolutionDir=$buildRoot\", "/p:TargetName=$target",
        "/p:OutDir=$buildRoot\$outRelative\",
        "/p:IntDir=$buildRoot\.build-obj\$target\$platform\Release\",
        '/fl', "/flp:logfile=$logDir\$logName;verbosity=normal;encoding=UTF-8")
    Write-Host "Building $target ($platform)"
    & $msbuild @buildArgs
    if ($LASTEXITCODE -ne 0) { throw "Build failed: $logName" }
}
Push-Location $buildRoot
try {
    foreach ($platform in @('Win32', 'x64')) {
        $out = if ($platform -eq 'Win32') { 'stage' } else { 'stage\64' }
        $hostTarget = if ($platform -eq 'Win32') { 'vstbridgeapp32' } else { 'vstbridgeapp64' }
        Build-Project 'driver\vstmididrv.vcxproj' $platform vstmididrv $out
        Build-Project 'vsthost\vsthost.vcxproj' $platform $hostTarget $out
        Build-Project 'drivercfg\drivercfg.vcxproj' $platform vstmididrvcfg $out
        $lib = if ($platform -eq 'Win32') { 'lib' } else { 'lib64' }
        Copy-Item "external_packages\$lib\bassasio_vstdrv.dll" "$out\" -Force
        Copy-Item "external_packages\$lib\ASIO2WASAPI_vstdrv.dll" "$out\" -Force
    }
    Copy-Item 'stage\64\vstbridgeapp64.exe' 'stage\vstbridgeapp64.exe' -Force
    Copy-Item 'stage\vstbridgeapp32.exe' 'stage\64\vstbridgeapp32.exe' -Force
} finally { Pop-Location }
