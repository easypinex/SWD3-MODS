[CmdletBinding()]
param([Parameter(Mandatory)][string]$BuildRoot,[Parameter(Mandatory)][string]$OutputRoot)
$ErrorActionPreference='Stop'
$build=(Resolve-Path -LiteralPath $BuildRoot).Path
$output=[IO.Path]::GetFullPath($OutputRoot)
if(Test-Path -LiteralPath $output){throw 'Use a new release output directory.'}
$source=(Resolve-Path (Join-Path $PSScriptRoot '../release')).Path
$package=Join-Path $output 'SWD3-Mod-Studio-0.3.2-Windows'
New-Item -ItemType Directory -Path (Join-Path $package 'worker') | Out-Null
$desktop=Get-Content (Join-Path $build 'desktop-fingerprint.json') -Raw | ConvertFrom-Json
$worker=Get-Content (Join-Path $build 'worker/build-fingerprint.json') -Raw | ConvertFrom-Json
if($desktop.Version -ne '0.3.2' -or $worker.Version -ne '0.3.0'){throw 'Expected desktop 0.3.2 / worker 0.3.0.'}
if((Get-FileHash (Join-Path $build 'DeveloperBridge.exe')).Hash -ne $desktop.DeveloperBridgeSHA256){throw 'Entry fingerprint mismatch.'}
if((Get-FileHash (Join-Path $build 'Mono.Cecil.dll')).Hash -ne $desktop.CecilSHA256 -or $desktop.CecilSHA256 -ne '831DCA77470D85CB6FFBEA3072DAA7A3DF5B7C9FCFD9C3F43674A9BE99D4BFCF'){throw 'Cecil fingerprint mismatch.'}
if((Get-FileHash (Join-Path $build 'SWD3ModStudio.exe')).Hash -ne $desktop.ExecutableSHA256 -or (Get-FileHash (Join-Path $build 'worker/SteamPrototype.exe')).Hash -ne $worker.ExecutableSHA256){throw 'Build fingerprint mismatch.'}
$files=@('SWD3ModStudio.exe','SWD3ModStudio.exe.config','DeveloperBridge.exe','desktop-fingerprint.json','Mono.Cecil.dll','Mono.Cecil-LICENSE.txt','worker/SteamPrototype.exe','worker/SteamPrototype.exe.config','worker/SteamReleasePackage.py','worker/steam_appid.txt')
foreach($file in $files){Copy-Item -LiteralPath (Join-Path $build $file) -Destination (Join-Path $package $file)}
$worker.PackageRuntimeSHA256='SETUP_REQUIRED'
$worker | ConvertTo-Json -Depth 6 | Set-Content (Join-Path $package 'worker/build-fingerprint.json') -Encoding UTF8
foreach($file in @('Setup-Desktop.ps1','Setup.cmd','README.txt')){Copy-Item -LiteralPath (Join-Path $source $file) -Destination $package}
$inventory=Get-ChildItem $package -Recurse -File | Where-Object Name -ne 'build-fingerprint.json' | ForEach-Object { [ordered]@{Name=$_.FullName.Substring($package.Length+1).Replace('\','/');SHA256=(Get-FileHash $_.FullName).Hash} }
@{Version='0.3.2';Files=@($inventory)} | ConvertTo-Json -Depth 5 | Set-Content (Join-Path $package 'release-files.json') -Encoding UTF8
$zip=Join-Path $output 'SWD3-Mod-Studio-0.3.2-Windows.zip'
Compress-Archive -Path $package -DestinationPath $zip
[IO.File]::WriteAllText((Join-Path $output 'SHA256SUMS.txt'),((Get-FileHash $zip).Hash.ToLowerInvariant()+'  '+[IO.Path]::GetFileName($zip)+"`n"),[Text.Encoding]::ASCII)
Write-Output "PASS: $zip"
