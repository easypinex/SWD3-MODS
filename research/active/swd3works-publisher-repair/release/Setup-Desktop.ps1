[CmdletBinding()]
param([string]$GameRoot,[string]$PythonExe,[switch]$NoLaunch)
$ErrorActionPreference='Stop'
try {
    $root=$PSScriptRoot
    $worker=Join-Path $root 'worker'
    $utf8=New-Object Text.UTF8Encoding($false)
    $manifest=Get-Content (Join-Path $root 'release-files.json') -Raw -Encoding UTF8 | ConvertFrom-Json
    foreach($file in $manifest.Files) {
        $path=Join-Path $root $file.Name
        if((Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash -ne $file.SHA256) { throw "Release file changed: $($file.Name). Extract a fresh ZIP." }
    }
    if(!$GameRoot) {
        Add-Type -AssemblyName System.Windows.Forms
        $dialog=New-Object Windows.Forms.OpenFileDialog
        $dialog.Title='Select swd3.exe from the Steam HD game folder'
        $dialog.Filter='SWD3 game (swd3.exe)|swd3.exe'
        if($dialog.ShowDialog() -ne 'OK'){return}
        $GameRoot=Split-Path $dialog.FileName
    }
    $game=(Resolve-Path -LiteralPath $GameRoot).Path.TrimEnd('\')
    if(!(Test-Path -LiteralPath (Join-Path $game 'swd3.exe'))) { throw 'Select the Steam HD game folder containing swd3.exe.' }
    if($root.Equals($game,[StringComparison]::OrdinalIgnoreCase) -or $root.StartsWith($game+'\',[StringComparison]::OrdinalIgnoreCase)) { throw 'Extract MOD Studio outside the game folder.' }
    $fingerprint=Get-Content (Join-Path $worker 'build-fingerprint.json') -Raw -Encoding UTF8 | ConvertFrom-Json
    foreach($dependency in $fingerprint.Dependencies) {
        if((Get-FileHash -LiteralPath (Join-Path $game $dependency.Name)).Hash -ne $dependency.SHA256) { throw "Unsupported game dependency: $($dependency.Name). Requires the tested Steam HD DLL versions." }
    }
    if(!$PythonExe) {
        $candidate=Get-Command python -ErrorAction SilentlyContinue
        if($candidate){$PythonExe=$candidate.Source}
        elseif(Get-Command py -ErrorAction SilentlyContinue){$PythonExe=(& py -3 -c 'import sys; print(sys.executable)' | Select-Object -Last 1)}
    }
    if(!$PythonExe) { throw 'Install Python 3 and zstandard 0.25.0, then run setup again.' }
    $pythonResult=& $PythonExe -c 'import sys, zstandard; print(sys.executable)' 2>&1
    if($LASTEXITCODE -ne 0) { throw 'Python 3 + zstandard is required. Run: python -m pip install zstandard==0.25.0' }
    $pythonPath=[string]($pythonResult | Select-Object -Last 1)
    if(!(Test-Path -LiteralPath $pythonPath)){throw 'Cannot find the resolved Python interpreter.'}
    foreach($dependency in $fingerprint.Dependencies) { Copy-Item -LiteralPath (Join-Path $game $dependency.Name) -Destination $worker }
    $runtime=Join-Path $worker 'package-runtime.json'
    [IO.File]::WriteAllText($runtime,(@{Python=$pythonPath;HelperSha256=$fingerprint.PackageInspectorSHA256}|ConvertTo-Json),$utf8)
    $fingerprint.PackageRuntimeSHA256=(Get-FileHash -LiteralPath $runtime).Hash
    [IO.File]::WriteAllText((Join-Path $worker 'build-fingerprint.json'),($fingerprint|ConvertTo-Json -Depth 6),$utf8)
    Push-Location $worker
    try { & (Join-Path $worker 'SteamPrototype.exe') self-test; if($LASTEXITCODE -ne 0){throw 'Worker self-test failed.'} } finally { Pop-Location }
    Write-Output 'Setup complete. Sign in to Steam, then open SWD3ModStudio.exe.'
    if(!$NoLaunch){Start-Process -FilePath (Join-Path $root 'SWD3ModStudio.exe') -WorkingDirectory $root}
} catch { Write-Error $_; exit 1 }
