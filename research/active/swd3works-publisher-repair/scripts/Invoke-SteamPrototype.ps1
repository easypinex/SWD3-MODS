[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$BuildRoot,
    [Parameter(Mandatory)][ValidateSet('health','list','details','files','history','review-release','publish-release','verify-release','close-release','create-test','update-test','verify-test','download-test','self-test')][string]$Command,
    [Parameter(Mandatory)][string]$LogPath,
    [string]$PlanPath,
    [string]$StatePath,
    [string]$ItemId,
    [string]$OutputPath,
    [ValidateSet('english','tchinese','schinese')][string]$Language='tchinese',
    [ValidateRange(0,1000)][int]$Page=0,
    [ValidateRange(5,600)][int]$TimeoutSeconds=60
)
$ErrorActionPreference = 'Stop'
$build = (Resolve-Path -LiteralPath $BuildRoot).Path
$exe = Join-Path $build 'SteamPrototype.exe'
$fingerprint = Get-Content -LiteralPath (Join-Path $build 'build-fingerprint.json') -Raw | ConvertFrom-Json
if ((Get-FileHash -LiteralPath $exe).Hash -ne $fingerprint.ExecutableSHA256) { throw 'Executable differs from the build fingerprint.' }
foreach ($dependency in $fingerprint.Dependencies) {
    if ((Get-FileHash -LiteralPath (Join-Path $build $dependency.Name)).Hash -ne $dependency.SHA256) { throw "Dependency differs from the build: $($dependency.Name)" }
}
if ($fingerprint.Version -in @('0.2.0','0.3.0')) {
    if ((Get-FileHash -LiteralPath (Join-Path $build 'SteamReleasePackage.py')).Hash -ne $fingerprint.PackageInspectorSHA256 -or
        (Get-FileHash -LiteralPath (Join-Path $build 'package-runtime.json')).Hash -ne $fingerprint.PackageRuntimeSHA256) { throw 'Package inspector/runtime differs from build.' }
}
$log = [IO.Path]::GetFullPath($LogPath)
if (Test-Path -LiteralPath $log) { throw 'Use a new log path.' }
New-Item -ItemType Directory -Force -Path (Split-Path $log) | Out-Null
$arguments = @($Command,'--timeout',"$TimeoutSeconds")
$arguments += @('--language',$Language)
if ($PlanPath) { $arguments += @('--plan',(Resolve-Path -LiteralPath $PlanPath).Path) }
if ($StatePath) { $arguments += @('--state',[IO.Path]::GetFullPath($StatePath)) }
if ($ItemId) { $arguments += @('--id',$ItemId) }
if ($OutputPath) { $arguments += @('--out',[IO.Path]::GetFullPath($OutputPath)) }
if ($Page) { $arguments += @('--page',"$Page") }
Push-Location $build
try {
    & $exe @arguments | Tee-Object -FilePath $log | ForEach-Object {
        # Preserve every raw line in the log; keep console summaries compact.
        if ($_ -match '^\{') {
            $record = $_ | ConvertFrom-Json
            if ($record.kind -eq 'published') {
                "Published: $($record.data.items.Count) / $($record.data.total); complete=$($record.data.complete)"
                $record.data.items | Select-Object Id,Title,Version,Visibility | Format-Table -AutoSize | Out-String
            } elseif ($record.kind -eq 'details' -or $record.kind -eq 'verified') {
                "$($record.kind): written to $log"
            } elseif ($record.kind -in @('release-review','release-verified','files','downloaded','release-history','release-rejected','release-verification-failed')) {
                "$($record.kind): written to $log"
            } else { $_ }
        }
    }
    $code = $LASTEXITCODE
} finally { Pop-Location }
if ($PlanPath -and $StatePath -and (Test-Path -LiteralPath $StatePath) -and $Command.EndsWith('-release')) {
    & (Join-Path $PSScriptRoot 'Export-SteamReleaseReport.ps1') -PlanPath $PlanPath -StatePath $StatePath -OutputPath ($log + '.html')
}
if ($code -ne 0) { throw "Prototype exited $code. Inspect $log; do not retry a create request blindly." }
Write-Output "PASS: $Command; log=$log"
