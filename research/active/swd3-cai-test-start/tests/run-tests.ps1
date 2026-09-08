param([string]$OriginalRoot=(Join-Path $PSScriptRoot '../../../../.work/extracted/script-index-inspect/out_data'))
$ErrorActionPreference='Stop'
$prepProject=Split-Path -Parent $PSScriptRoot
$prepFiles=Get-ChildItem "$prepProject/src/data" -Filter '*.lua' | ForEach-Object { '--file'; $_.FullName }
& npx --yes --package luaparse luaparse --quiet @prepFiles
if ($LASTEXITCODE -ne 0) { throw 'Lua syntax failed' }
$prepOutput=(& npx --yes --package fengari-node-cli fengari "$PSScriptRoot/runtime.lua" $prepProject $OriginalRoot 2>&1 | Out-String)
Write-Output $prepOutput
if ($LASTEXITCODE -ne 0 -or $prepOutput -match 'stack traceback:' -or $prepOutput -notmatch 'PASS: four Lv60 profiles') { throw 'Test start mock failed' }
