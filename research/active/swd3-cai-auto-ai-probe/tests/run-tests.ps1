param([string]$OriginalRoot=(Join-Path $PSScriptRoot '../../../../.work/extracted/script-index-inspect/out_data'))
$ErrorActionPreference='Stop'
$aiProject=Split-Path -Parent $PSScriptRoot
$aiFiles=Get-ChildItem "$aiProject/src/data" -Filter '*.lua' | ForEach-Object { '--file'; $_.FullName }
& npx --yes --package luaparse luaparse --quiet @aiFiles
if ($LASTEXITCODE -ne 0) { throw 'Lua syntax failed' }
$aiResult=(& npx --yes --package fengari-node-cli fengari "$PSScriptRoot/runtime.lua" $aiProject $OriginalRoot 2>&1 | Out-String)
Write-Output $aiResult
if ($LASTEXITCODE -ne 0 -or $aiResult -match 'stack traceback:' -or $aiResult -notmatch 'PASS: Cai auto AI native dispatcher') { throw 'AI tests failed' }
