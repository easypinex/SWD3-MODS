[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$GameRoot,
    [switch]$ReuseAnalysis
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$analysisRoot = Join-Path $projectRoot 'native-analysis'
$inputRoot = Join-Path $analysisRoot 'input'
$reportRoot = Join-Path $analysisRoot 'reports'
$ghidraProjectRoot = Join-Path $analysisRoot 'ghidra-project'
$gameRootPath = (Resolve-Path -LiteralPath $GameRoot).Path
# Locate the workspace independently of active/archive nesting; also works in a clone.
$workspaceCandidate = Get-Item -LiteralPath $projectRoot
while ($null -ne $workspaceCandidate -and -not (
    (Test-Path -LiteralPath (Join-Path $workspaceCandidate.FullName 'AGENTS.md')) -and
    (Test-Path -LiteralPath (Join-Path $workspaceCandidate.FullName 'docs\knowledge'))
)) {
    $workspaceCandidate = $workspaceCandidate.Parent
}
if ($null -eq $workspaceCandidate) { throw 'Workspace root (AGENTS.md and docs/knowledge) not found.' }
$toolRoot = Join-Path $workspaceCandidate.FullName '.tools\static-re'
$ghidraRoot = Join-Path $toolRoot 'ghidra-11.4.3'
$jdkRoot = Join-Path $toolRoot 'jdk-21'
$requiredFiles = @('swd3.exe', 'SWD3Works.exe', 'Steamworks.NET.dll')

foreach ($fileName in $requiredFiles) {
    $source = Join-Path $gameRootPath $fileName
    if (-not (Test-Path -LiteralPath $source -PathType Leaf)) {
        throw "Required game file is missing: $source"
    }
}
foreach ($path in @($inputRoot, $reportRoot, $ghidraProjectRoot)) {
    New-Item -ItemType Directory -Force -Path $path | Out-Null
}
$copyValidation = foreach ($fileName in $requiredFiles) {
    $source = Join-Path $gameRootPath $fileName
    $destination = Join-Path $inputRoot $fileName
    $before = (Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash
    Copy-Item -LiteralPath $source -Destination $destination -Force
    $after = (Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash
    $copied = (Get-FileHash -LiteralPath $destination -Algorithm SHA256).Hash
    if ($before -ne $after -or $before -ne $copied) {
        throw "Input changed while copied; stop and rerun with the game closed: $fileName"
    }
    [pscustomobject]@{ File = $fileName; SourceBefore = $before; SourceAfter = $after; Copied = $copied }
}

$fingerprint = foreach ($fileName in $requiredFiles) {
    $path = Join-Path $inputRoot $fileName
    $item = Get-Item -LiteralPath $path
    [pscustomobject]@{
        File = $fileName
        Length = $item.Length
        FileVersion = $item.VersionInfo.FileVersion
        ProductVersion = $item.VersionInfo.ProductVersion
        SHA256 = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash
    }
}
$fingerprint | Format-Table -AutoSize | Out-String | Set-Content -LiteralPath (Join-Path $reportRoot 'input-fingerprints.txt') -Encoding utf8
$copyValidation | Format-Table -AutoSize | Out-String | Add-Content -LiteralPath (Join-Path $reportRoot 'input-fingerprints.txt') -Encoding utf8

$managedReport = Join-Path $reportRoot 'swd3works-managed-inventory.txt'
$managedInventoryScript = Join-Path $PSScriptRoot 'Get-Swd3WorksManagedInventory.ps1'
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $managedInventoryScript `
    -InputRoot $inputRoot -OutputPath $managedReport
if ($LASTEXITCODE -ne 0) {
    throw "Managed metadata inventory failed with exit code $LASTEXITCODE. Inspect $managedReport"
}

$importReport = Join-Path $reportRoot 'swd3-pe-imports-and-loader-strings.txt'
& python (Join-Path $PSScriptRoot 'Get-PeImports.py') (Join-Path $inputRoot 'swd3.exe') | `
    Tee-Object -FilePath $importReport
if ($LASTEXITCODE -ne 0) {
    throw "PE import inventory failed with exit code $LASTEXITCODE. Inspect $importReport"
}

if (-not (Test-Path -LiteralPath (Join-Path $ghidraRoot 'support\analyzeHeadless.bat'))) {
    throw "Ghidra 11.4.3 is unavailable at $ghidraRoot"
}
if (-not (Test-Path -LiteralPath (Join-Path $jdkRoot 'bin\java.exe'))) {
    throw "Portable JDK 21 is unavailable at $jdkRoot"
}

$env:JAVA_HOME = $jdkRoot
$env:PATH = "$jdkRoot\bin;" + $env:PATH
$analysisFlag = if ($ReuseAnalysis) { '-noanalysis' } else { '-import' }
$analyzeHeadless = Join-Path $ghidraRoot 'support\analyzeHeadless.bat'
$reportScriptPath = Join-Path $PSScriptRoot 'ghidra'
$nativeReport = Join-Path $reportRoot 'swd3-native-loader-report.txt'

if ($ReuseAnalysis) {
    & $analyzeHeadless $ghidraProjectRoot 'SWD3Loader' -process 'swd3.exe' -noanalysis `
        -scriptPath $reportScriptPath -postScript 'ReportHdModLoader.py' | Tee-Object -FilePath $nativeReport
} else {
    & $analyzeHeadless $ghidraProjectRoot 'SWD3Loader' -import (Join-Path $inputRoot 'swd3.exe') `
        -scriptPath $reportScriptPath -postScript 'ReportHdModLoader.py' | Tee-Object -FilePath $nativeReport
}
if ($LASTEXITCODE -ne 0) {
    throw "Ghidra analysis failed with exit code $LASTEXITCODE. Inspect $nativeReport"
}

$followUpReports = @(
    @{ Script = 'DecompileHdModLoaderControlFlow.py'; Report = 'swd3-native-loader-control-flow.txt' },
    @{ Script = 'ReportHdModuleApiXrefs.py'; Report = 'swd3-native-module-api-xrefs.txt' },
    @{ Script = 'ReportHdLuaPackageLoadlib.py'; Report = 'swd3-lua-package-loadlib-exposure.txt' }
)
foreach ($followUp in $followUpReports) {
    $outputPath = Join-Path $reportRoot $followUp.Report
    & $analyzeHeadless $ghidraProjectRoot 'SWD3Loader' -process 'swd3.exe' -noanalysis `
        -scriptPath $reportScriptPath -postScript $followUp.Script | Tee-Object -FilePath $outputPath
    if ($LASTEXITCODE -ne 0) {
        throw "Ghidra report $($followUp.Script) failed with exit code $LASTEXITCODE. Inspect $outputPath"
    }
}

Write-Output "Static reports are in $reportRoot"
