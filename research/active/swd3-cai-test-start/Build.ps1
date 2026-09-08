param([string]$GameRoot='D:\SteamLibrary\steamapps\common\SWD3')
$ErrorActionPreference='Stop'
$aiBase='cai_test_start'
$aiBuild=Join-Path $PSScriptRoot ('../../../.work/cai-test-start-build-'+(Get-Date -Format 'yyyyMMdd-HHmmss-fff'))
$aiTool=Join-Path $GameRoot 'Tools/SS2Dtool.exe'
New-Item -ItemType Directory -Path $aiBuild | Out-Null
Push-Location $aiBuild
try {
    & $aiTool p "-i$PSScriptRoot/src" "-I$aiBase"
    if (-not (Test-Path "$aiBase.ssmod")) { throw 'Package missing' }
    & $aiTool x "-i$aiBuild" "-I$aiBase"
    foreach ($aiFile in Get-ChildItem "$PSScriptRoot/src/data" -File) {
        if ((Get-FileHash $aiFile.FullName).Hash -ne (Get-FileHash "out_data/$($aiFile.Name)").Hash) { throw "Roundtrip mismatch: $($aiFile.Name)" }
    }
    $aiManifest=Get-ChildItem -Recurse -Filter "$aiBase.ext" | Select-Object -First 1
    if (-not $aiManifest -or (Get-FileHash $aiManifest.FullName).Hash -ne (Get-FileHash "$PSScriptRoot/src/$aiBase.ext").Hash) { throw 'Manifest roundtrip mismatch' }
    New-Item -ItemType Directory -Force -Path "$PSScriptRoot/dist" | Out-Null
    Copy-Item "$aiBase.ssmod" "$PSScriptRoot/dist/$aiBase.ssmod" -Force
    Get-FileHash "$PSScriptRoot/dist/$aiBase.ssmod"
} finally { Pop-Location }
