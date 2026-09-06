[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$GameRoot,
    [Parameter(Mandatory)][string]$OutputRoot,
    [Parameter(Mandatory)][string]$IlspyPath
)
$ErrorActionPreference = 'Stop'
$game = (Resolve-Path -LiteralPath $GameRoot).Path
$ilspy = (Resolve-Path -LiteralPath $IlspyPath).Path
$output = [IO.Path]::GetFullPath($OutputRoot)
if ($output.TrimEnd('\').Equals($game.TrimEnd('\'), [StringComparison]::OrdinalIgnoreCase) -or
    $output.StartsWith($game.TrimEnd('\') + '\', [StringComparison]::OrdinalIgnoreCase)) {
    throw 'Output must be outside the game installation.'
}
if (Test-Path -LiteralPath $output) { throw 'Use a new output directory.' }
$inputDir = Join-Path $output 'input'
$codeDir = Join-Path $output 'decompiled'
New-Item -ItemType Directory -Path $inputDir, $codeDir | Out-Null
$fingerprints = foreach ($name in @('SWD3Works.exe', 'Steamworks.NET.dll', 'SWD3Works.exe.config')) {
    $source = Join-Path $game $name
    $copy = Join-Path $inputDir $name
    $hash = (Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash
    Copy-Item -LiteralPath $source -Destination $copy
    foreach ($path in @($source, $copy)) {
        if ((Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash -ne $hash) { throw 'Copy mismatch.' }
    }
    $info = Get-Item -LiteralPath $copy
    [pscustomobject]@{Name=$name; Version=$info.VersionInfo.FileVersion; Length=$info.Length; SHA256=$hash}
}
$version = & $ilspy --version
if ($LASTEXITCODE -ne 0) { throw 'ILSpy version check failed.' }
& $ilspy --disable-updatecheck -r $inputDir -o $codeDir (Join-Path $inputDir 'SWD3Works.exe')
if ($LASTEXITCODE -ne 0) { throw 'Decompilation failed.' }
$code = Join-Path $codeDir 'SWD3Works.decompiled.cs'
if (-not (Test-Path -LiteralPath $code)) { throw 'Missing decompiled C#.' }
foreach ($symbol in @('class SteamWorkshopManager', 'QueryInstalledWorkshopItems', 'SubmitItemUpdate')) {
    if (-not (Select-String -LiteralPath $code -SimpleMatch $symbol -Quiet)) { throw "Missing symbol: $symbol" }
}
foreach ($row in $fingerprints) {
    foreach ($path in @((Join-Path $game $row.Name), (Join-Path $inputDir $row.Name))) {
        if ((Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash -ne $row.SHA256) { throw 'Input changed during analysis.' }
    }
}
if ($fingerprints[0].SHA256 -eq '756D9E2F9866EC335F8A536B9ED0DE2869BBE83FF3D5BF468E0F8A2E3C0330FA' -and
    (Get-FileHash -LiteralPath $code -Algorithm SHA256).Hash -eq 'DBF8B4B4FA2C0411D4902C4402496E1BFEC9C2588B44FF40D0330B36C4131F78') {
    $lines = Get-Content -LiteralPath $code
    $excerpts = foreach ($range in @(@(1644, 1651), @(1854, 1917), @(3240, 3309),
        @(3437, 3444), @(3886, 3913), @(3984, 4073), @(4717, 4720), @(4788, 4796))) {
        "=== SWD3Works.decompiled.cs lines $($range[0])-$($range[1]) ==="
        for ($i = $range[0]; $i -le $range[1]; $i++) { '{0:D5}: {1}' -f $i, $lines[$i - 1] }
        ''
    }
    $excerpts | Set-Content -LiteralPath (Join-Path $output 'control-flow-excerpts.txt') -Encoding utf8
}
[pscustomobject]@{
    RecordedAt=(Get-Date).ToString('o'); Inputs=@($fingerprints); Tool=@($version)
    ScriptSHA256=(Get-FileHash -LiteralPath $PSCommandPath -Algorithm SHA256).Hash
    ReportSHA256=(Get-FileHash -LiteralPath $code -Algorithm SHA256).Hash
    Method='ILSpy C# export; no target execution or Steam API calls'
} | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $output 'fingerprint.json') -Encoding utf8
Write-Output "PASS: $code"
