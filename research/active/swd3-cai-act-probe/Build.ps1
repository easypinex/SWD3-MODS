param([string]$GameRoot='D:\SteamLibrary\steamapps\common\SWD3')
$ErrorActionPreference='Stop'
$caiWorkspace=(Resolve-Path "$PSScriptRoot/../../..").Path
$caiProbeBuild=Join-Path $caiWorkspace ('.work/cai-probe-'+(Get-Date -Format 'yyyyMMdd-HHmmss-fff'))
New-Item -ItemType Directory "$caiProbeBuild/src/data" | Out-Null
Copy-Item "$PSScriptRoot/src/cai_act_probe.ext" "$caiProbeBuild/src/"
Copy-Item "$PSScriptRoot/src/data/CaiActProbe.lua" "$caiProbeBuild/src/data/"
Copy-Item "$caiWorkspace/swd3-cai-demon-king-mod/src/data/CaiDemonActions.*" "$caiProbeBuild/src/data/"
Push-Location $caiProbeBuild
try {
    & "$GameRoot/Tools/SS2Dtool.exe" p "-i$caiProbeBuild/src" '-Icai_act_probe'
    if (-not (Test-Path cai_act_probe.ssmod)) { throw 'Probe package missing' }
    & "$GameRoot/Tools/SS2Dtool.exe" x "-i$caiProbeBuild" '-Icai_act_probe'
    foreach($caiFile in Get-ChildItem src/data -File) {
        if ((Get-FileHash $caiFile.FullName).Hash -ne (Get-FileHash "out_data/$($caiFile.Name)").Hash) { throw 'Probe roundtrip mismatch' }
    }
    if ((Get-FileHash src/cai_act_probe.ext).Hash -ne (Get-FileHash cai_act_probe.ext).Hash) { throw 'Probe manifest mismatch' }
    Get-FileHash cai_act_probe.ssmod
} finally { Pop-Location }
