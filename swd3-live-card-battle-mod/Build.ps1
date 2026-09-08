param([string]$GameRoot='D:\SteamLibrary\steamapps\common\SWD3')
$ErrorActionPreference='Stop'
$challengeBase='live_card_battle'
$challengeBuild=Join-Path $PSScriptRoot ('../.work/live-card-build-'+(Get-Date -Format 'yyyyMMdd-HHmmss-fff'))
$challengeTool=Join-Path $GameRoot 'Tools/SS2Dtool.exe'
New-Item -ItemType Directory -Path $challengeBuild | Out-Null
Push-Location $challengeBuild
try {
    & $challengeTool p "-i$PSScriptRoot/src" "-I$challengeBase"
    if (-not (Test-Path "$challengeBase.ssmod")) { throw 'Package missing' }
    & $challengeTool x "-i$challengeBuild" "-I$challengeBase"
    foreach ($line in Get-Content "$PSScriptRoot/src/$challengeBase.ext") {
        if ($line -notmatch '^DAT\s+\d+,\d+,([^,]+),') { continue }
        $dataName=$Matches[1].Trim()
        if ((Get-FileHash "$PSScriptRoot/src/data/$dataName").Hash -ne (Get-FileHash "out_data/$dataName").Hash) { throw "Roundtrip mismatch: $dataName" }
    }
    $manifest=Get-ChildItem -Recurse -Filter "$challengeBase.ext" | Select-Object -First 1
    if (-not $manifest -or (Get-FileHash $manifest.FullName).Hash -ne (Get-FileHash "$PSScriptRoot/src/$challengeBase.ext").Hash) { throw 'Manifest roundtrip mismatch' }
    New-Item -ItemType Directory -Force -Path "$PSScriptRoot/dist" | Out-Null
    Copy-Item "$challengeBase.ssmod" "$PSScriptRoot/dist/$challengeBase.ssmod" -Force
    Get-FileHash "$PSScriptRoot/dist/$challengeBase.ssmod"
} finally { Pop-Location }
