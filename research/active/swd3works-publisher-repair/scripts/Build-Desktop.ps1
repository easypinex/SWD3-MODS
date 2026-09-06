[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$GameRoot,
    [Parameter(Mandatory)][string]$OutputRoot,
    [string]$CecilPath
)
$ErrorActionPreference='Stop'
$output=[IO.Path]::GetFullPath($OutputRoot).TrimEnd('\')
$game=(Resolve-Path -LiteralPath $GameRoot).Path.TrimEnd('\')
if ($output.Equals($game,[StringComparison]::OrdinalIgnoreCase) -or $output.StartsWith($game+'\',[StringComparison]::OrdinalIgnoreCase)) { throw 'Desktop output must be outside the game.' }
if (Test-Path -LiteralPath $output) { throw 'Use a new desktop build directory.' }
New-Item -ItemType Directory -Path $output | Out-Null
& (Join-Path $PSScriptRoot 'Build-SteamPrototype.ps1') -GameRoot $game -OutputRoot (Join-Path $output 'worker')
if ($LASTEXITCODE -ne 0) { throw 'Worker build failed.' }
$framework=Join-Path $env:WINDIR 'Microsoft.NET/Framework/v4.0.30319'
$compiler=Join-Path $framework 'csc.exe'
$source=(Resolve-Path (Join-Path $PSScriptRoot '../desktop')).Path
if(!$CecilPath){$CecilPath=Join-Path $PSScriptRoot '../../../../.tools/ilspycmd/.store/ilspycmd/9.1.0.7988/ilspycmd/9.1.0.7988/tools/net8.0/any/Mono.Cecil.dll'}
$cecil=(Resolve-Path -LiteralPath $CecilPath).Path
if((Get-FileHash $cecil).Hash -ne '831DCA77470D85CB6FFBEA3072DAA7A3DF5B7C9FCFD9C3F43674A9BE99D4BFCF'){throw 'Expected pinned Mono.Cecil 0.11.6.'}
Copy-Item -LiteralPath $cecil -Destination $output
Copy-Item -LiteralPath (Join-Path $PSScriptRoot '../release/Mono.Cecil-LICENSE.txt') -Destination $output
$exe=Join-Path $output 'SWD3ModStudio.exe'
$refs=@('PresentationCore','PresentationFramework','WindowsBase') | ForEach-Object { '/reference:'+(Join-Path $framework "WPF/$_.dll") }
$sources=@('StudioCore.cs','StudioApp.cs','DesktopTests.cs','SteamEntry.cs','WorkshopMenuPatch.cs') | ForEach-Object { Join-Path $source $_ }
& $compiler /nologo /target:winexe /platform:anycpu /optimize+ /warnaserror+ "/out:$exe" /reference:System.Web.Extensions.dll /reference:System.Web.dll /reference:System.Xaml.dll "/reference:$cecil" "/reference:$(Join-Path $framework 'netstandard.dll')" @refs "/resource:$(Join-Path $source 'MainWindow.xaml'),MainWindow.xaml" @sources
if ($LASTEXITCODE -ne 0 -or !(Test-Path -LiteralPath $exe)) { throw 'Desktop compilation failed.' }
[IO.File]::WriteAllText(($exe+'.config'),'<?xml version="1.0"?><configuration><startup><supportedRuntime version="v4.0" sku=".NETFramework,Version=v4.8" /></startup><runtime><AppContextSwitchOverrides value="Switch.System.Windows.DoNotScaleForDpiChanges=false" /></runtime></configuration>',[Text.Encoding]::UTF8)
$testLog=Join-Path $output 'desktop-self-test.jsonl'
$test=Start-Process -FilePath $exe -ArgumentList '--self-test' -WindowStyle Hidden -Wait -PassThru -RedirectStandardOutput $testLog
Get-Content -LiteralPath $testLog
if ($test.ExitCode -ne 0) { throw 'Desktop self-test failed.' }
$entry=Join-Path $output 'DeveloperBridge.exe'
& $compiler /nologo /target:winexe /platform:anycpu /optimize+ /warnaserror+ "/out:$entry" /reference:System.Web.Extensions.dll /reference:System.Web.dll /reference:System.Windows.Forms.dll (Join-Path $source 'StudioCore.cs') (Join-Path $source 'DeveloperBridge.cs')
if($LASTEXITCODE -ne 0 -or !(Test-Path $entry)){throw 'Steam entry compilation failed.'}
$fingerprint=[ordered]@{Version='0.3.2';RecordedAt=(Get-Date).ToString('o');ExecutableSHA256=(Get-FileHash $exe).Hash;DeveloperBridgeSHA256=(Get-FileHash $entry).Hash;CecilSHA256=(Get-FileHash $cecil).Hash;UI='WPF .NET Framework 4.8 AnyCPU';Worker='isolated x86 process';Sources=@()}
foreach ($path in @($sources)+(Join-Path $source 'MainWindow.xaml')+(Join-Path $source 'DeveloperBridge.cs')) { $fingerprint.Sources += @{Name=[IO.Path]::GetFileName($path);SHA256=(Get-FileHash $path).Hash} }
$fingerprint | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $output 'desktop-fingerprint.json') -Encoding utf8
Write-Output "PASS: $exe"
