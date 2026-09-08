param([string]$GameRoot='D:\SteamLibrary\steamapps\common\SWD3')
$ErrorActionPreference='Stop'
$caiBase='cai_demon_king'
$caiBuild=Join-Path $PSScriptRoot ('../.work/cai-build-'+(Get-Date -Format 'yyyyMMdd-HHmmss-fff'))
$caiTool=Join-Path $GameRoot 'Tools/SS2Dtool.exe'
New-Item -ItemType Directory -Path $caiBuild | Out-Null
Push-Location $caiBuild
try {
    & $caiTool p "-i$PSScriptRoot/src" "-I$caiBase"
    if (-not (Test-Path "$caiBase.ssmod")) { throw 'Package missing' }
    & $caiTool x "-i$caiBuild" "-I$caiBase"
    foreach ($file in Get-ChildItem "$PSScriptRoot/src/data" -File) {
        if ((Get-FileHash $file.FullName).Hash -ne (Get-FileHash "out_data/$($file.Name)").Hash) { throw "Roundtrip mismatch: $($file.Name)" }
    }
    $manifest=Get-ChildItem -Recurse -Filter "$caiBase.ext" | Select-Object -First 1
    if (-not $manifest -or (Get-FileHash $manifest.FullName).Hash -ne (Get-FileHash "$PSScriptRoot/src/$caiBase.ext").Hash) { throw 'Manifest roundtrip mismatch' }
    New-Item -ItemType Directory -Force -Path "$PSScriptRoot/dist" | Out-Null
    Copy-Item "$caiBase.ssmod" "$PSScriptRoot/dist/$caiBase.ssmod" -Force
    Get-FileHash "$PSScriptRoot/dist/$caiBase.ssmod"
} finally { Pop-Location }
