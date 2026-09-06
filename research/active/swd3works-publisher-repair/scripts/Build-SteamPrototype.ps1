[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$GameRoot,
    [Parameter(Mandatory)][string]$OutputRoot
)
$ErrorActionPreference = 'Stop'
$game = (Resolve-Path -LiteralPath $GameRoot).Path.TrimEnd('\')
$output = [IO.Path]::GetFullPath($OutputRoot).TrimEnd('\')
if ($output.Equals($game, [StringComparison]::OrdinalIgnoreCase) -or $output.StartsWith($game + '\', [StringComparison]::OrdinalIgnoreCase)) { throw 'Output must be outside the game.' }
if (Test-Path -LiteralPath $output) { throw 'Use a new build directory.' }
$source = Join-Path $PSScriptRoot '../prototype/SteamPrototype.cs'
$releaseSource = Join-Path $PSScriptRoot '../prototype/ReleaseWorkflow.cs'
$inspector = Join-Path $PSScriptRoot 'SteamReleasePackage.py'
$pythonPath = & python -c 'import sys, zstandard; print(sys.executable)'
if ($LASTEXITCODE -ne 0 -or !(Test-Path -LiteralPath $pythonPath)) { throw 'Python 3 with zstandard is required for package inspection.' }
$compiler = Join-Path $env:WINDIR 'Microsoft.NET/Framework/v4.0.30319/csc.exe'
$expected = @{
    'Steamworks.NET.dll' = 'CFC3DB8EDBB2A1BB5A23FA045BB3F30C959068DF147B01FC34291F7E0C71029F'
    'steam_api.dll' = 'DF431862608823F54DF423428296273E1CA65C9928FA93633B882FE1C3D7D153'
}
foreach ($name in $expected.Keys) {
    if ((Get-FileHash -LiteralPath (Join-Path $game $name)).Hash -ne $expected[$name]) { throw "Unknown dependency version: $name" }
}
New-Item -ItemType Directory -Path $output | Out-Null
foreach ($name in $expected.Keys) { Copy-Item -LiteralPath (Join-Path $game $name) -Destination $output }
$exe = Join-Path $output 'SteamPrototype.exe'
& $compiler /nologo /target:exe /platform:x86 /optimize+ /warnaserror+ "/out:$exe" "/reference:$(Join-Path $output 'Steamworks.NET.dll')" /reference:System.Web.Extensions.dll $source $releaseSource
if ($LASTEXITCODE -ne 0 -or !(Test-Path -LiteralPath $exe)) { throw 'Build failed.' }
[IO.File]::WriteAllText((Join-Path $output 'steam_appid.txt'), '1638230', [Text.Encoding]::ASCII)
[IO.File]::WriteAllText(($exe + '.config'), '<?xml version="1.0"?><configuration><startup><supportedRuntime version="v4.0" sku=".NETFramework,Version=v4.8" /></startup></configuration>', [Text.Encoding]::UTF8)
Copy-Item -LiteralPath $inspector -Destination $output
@{Python=$pythonPath; HelperSha256=(Get-FileHash -LiteralPath $inspector).Hash} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $output 'package-runtime.json') -Encoding utf8
$fingerprints = foreach ($name in $expected.Keys) {
    foreach ($path in @((Join-Path $game $name), (Join-Path $output $name))) {
        if ((Get-FileHash -LiteralPath $path).Hash -ne $expected[$name]) { throw 'Dependency changed during build.' }
    }
    [pscustomobject]@{Name=$name; SHA256=$expected[$name]}
}
[pscustomobject]@{
    Version='0.3.0'; RecordedAt=(Get-Date).ToString('o'); Architecture='x86'; Runtime='.NET Framework 4.8'
    Compiler=(Get-Item -LiteralPath $compiler).VersionInfo.FileVersion
    SourceSHA256=(Get-FileHash -LiteralPath $source).Hash
    ReleaseSourceSHA256=(Get-FileHash -LiteralPath $releaseSource).Hash
    PackageInspectorSHA256=(Get-FileHash -LiteralPath $inspector).Hash
    PackageRuntimeSHA256=(Get-FileHash -LiteralPath (Join-Path $output 'package-runtime.json')).Hash
    ExecutableSHA256=(Get-FileHash -LiteralPath $exe).Hash
    Dependencies=@($fingerprints)
} | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $output 'build-fingerprint.json') -Encoding utf8
& $exe self-test
if ($LASTEXITCODE -ne 0) { throw 'Offline self-test failed.' }
Write-Output "PASS: $exe"
