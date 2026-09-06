[CmdletBinding()]
param([Parameter(Mandatory)][string]$BuildRoot,[Parameter(Mandatory)][string]$GameRoot,[Parameter(Mandatory)][string]$OutputRoot)
$ErrorActionPreference='Stop'
$build=(Resolve-Path -LiteralPath $BuildRoot).Path
$game=(Resolve-Path -LiteralPath $GameRoot).Path
$output=[IO.Path]::GetFullPath($OutputRoot)
if(Test-Path -LiteralPath $output){throw 'Use a new isolated test directory.'}
if($output.Equals($game,[StringComparison]::OrdinalIgnoreCase) -or $output.StartsWith($game.TrimEnd('\')+'\',[StringComparison]::OrdinalIgnoreCase)){throw 'Tests must stay outside the game.'}
$expected='756D9E2F9866EC335F8A536B9ED0DE2869BBE83FF3D5BF468E0F8A2E3C0330FA'
$original=Join-Path $game 'SWD3Works.exe'
if((Get-FileHash $original).Hash -ne $expected){$original=Join-Path $game 'SWD3Works.original.exe'}
if((Get-FileHash $original).Hash -ne $expected){throw 'No verified original publisher.'}
$fixture=Join-Path $output '中文 空格 game'
New-Item -ItemType Directory -Path $fixture | Out-Null
Copy-Item -LiteralPath $original -Destination (Join-Path $fixture 'SWD3Works.exe')
Copy-Item -LiteralPath (Join-Path $game 'SWD3Works.exe.config') -Destination $fixture
[IO.File]::WriteAllText((Join-Path $fixture 'swd3.exe'),'isolated game marker - never execute')
$results=[Collections.Generic.List[object]]::new()
function Invoke-Entry([string]$Action,[int]$ExpectedExit=0) {
    $index=$results.Count
    $log=Join-Path $output "$index-$Action.jsonl"
    $process=Start-Process -FilePath (Join-Path $build 'SWD3ModStudio.exe') -ArgumentList @('--steam-entry',$Action,('"'+$fixture+'"')) -WindowStyle Hidden -Wait -PassThru -RedirectStandardOutput $log
    if($process.ExitCode -ne $ExpectedExit){throw "Unexpected exit for $Action : $(Get-Content $log -Raw)"}
    $record=Get-Content $log -Raw | ConvertFrom-Json
    if($ExpectedExit -eq 0 -and $record.kind -ne 'steam-entry'){throw 'Missing success payload'}
    if($ExpectedExit -ne 0 -and $record.kind -ne 'steam-entry-error'){throw 'Missing failure payload'}
    $results.Add(@{Case=$Action;ExpectedExit=$ExpectedExit;Result=$record})
}
$entry=Join-Path $fixture 'SWD3Works.exe'
$backup=Join-Path $fixture 'SWD3Works.original.exe'
$shimHash=(Get-FileHash (Join-Path $build 'DeveloperBridge.exe')).Hash
Invoke-Entry status
Invoke-Entry install
$patchHash=(Get-FileHash $entry).Hash
$patchRecord=Get-Content (Join-Path $fixture 'SWD3ModStudio.developer.json') -Raw | ConvertFrom-Json
if($patchHash -eq $shimHash -or $patchHash -eq $expected -or (Get-FileHash $backup).Hash -ne $expected -or $patchRecord.Scope -ne 'DeveloperMenu' -or $patchRecord.Verification.UnchangedMethods -lt 100){throw 'Menu-only patch verification failed'}
Invoke-Entry install
Invoke-Entry restore
if((Get-FileHash $entry).Hash -ne $expected){throw 'Restore hash mismatch'}
Invoke-Entry restore
Invoke-Entry install
# Simulate Steam restoring the exact known original, without touching Steam.
Copy-Item -LiteralPath $backup -Destination $entry -Force
Invoke-Entry status
Invoke-Entry install
# Never overwrite an unrecognized replacement.
$verifiedPatch=Join-Path $output 'verified-patch.exe'
Copy-Item -LiteralPath $entry -Destination $verifiedPatch
$patchHash=(Get-FileHash $entry).Hash
[IO.File]::WriteAllText($entry,'unknown third-party entry')
Invoke-Entry install 1
Invoke-Entry restore 1
if([IO.File]::ReadAllText($entry) -ne 'unknown third-party entry'){throw 'Unknown file overwritten'}
Copy-Item -LiteralPath $verifiedPatch -Destination $entry -Force
[IO.File]::WriteAllText($backup,'damaged backup')
Invoke-Entry restore 1
if((Get-FileHash $entry).Hash -ne $patchHash){throw 'Entry changed after bad-backup rejection'}
Copy-Item -LiteralPath $original -Destination $backup -Force
Invoke-Entry restore
# An interrupted swap leaves a valid backup/journal and can be retried.
$lock=[IO.File]::Open($entry,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::Read)
try{Invoke-Entry install 1}finally{$lock.Dispose()}
if((Get-FileHash $entry).Hash -ne $expected){throw 'Locked original changed'}
Invoke-Entry install
Invoke-Entry restore
if((Get-FileHash $entry).Hash -ne $expected -or (Get-FileHash $backup).Hash -ne $expected){throw 'Final restoration failed'}
if((Get-FileHash (Join-Path $fixture 'SWD3Works.exe.config')).Hash -ne (Get-FileHash (Join-Path $game 'SWD3Works.exe.config')).Hash){throw 'Original config changed'}
# Repair a previously registered 0.3.1 full-launcher takeover using the original backup.
[IO.File]::WriteAllText($entry,'isolated legacy whole-launcher shim')
@{Schema=1;EntryHashes=@((Get-FileHash $entry).Hash)} | ConvertTo-Json | Set-Content (Join-Path $fixture 'SWD3ModStudio.entry.json') -Encoding UTF8
Invoke-Entry install
Invoke-Entry restore
$bridge=Join-Path $fixture 'SWD3ModStudio.developer.exe'
[IO.File]::WriteAllText($bridge,'unknown developer bridge')
Invoke-Entry install 1
if([IO.File]::ReadAllText($bridge) -ne 'unknown developer bridge'){throw 'Unknown bridge overwritten'}
Copy-Item -LiteralPath (Join-Path $build 'DeveloperBridge.exe') -Destination $bridge -Force
Invoke-Entry install
Invoke-Entry restore
@{Passed=$results.Count;SteamInitialized=$false;OriginalSHA256=$expected;BridgeSHA256=$shimHash;ScopeVerification=$patchRecord.Verification;Cases=$results} | ConvertTo-Json -Depth 8 | Set-Content (Join-Path $output 'results.json') -Encoding UTF8
Write-Output "PASS: $($results.Count) isolated entry checks; original and config preserved"
