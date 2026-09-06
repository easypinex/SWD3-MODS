[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$GameRoot,
    [Parameter(Mandatory)][string]$OutputRoot,
    [ValidateRange(1,9999)][int[]]$Revisions=@(1,2)
)
$ErrorActionPreference = 'Stop'
$game = (Resolve-Path -LiteralPath $GameRoot).Path.TrimEnd('\')
$output = [IO.Path]::GetFullPath($OutputRoot).TrimEnd('\')
if ($output.Equals($game, [StringComparison]::OrdinalIgnoreCase) -or $output.StartsWith($game + '\', [StringComparison]::OrdinalIgnoreCase)) { throw 'Output must be outside the game.' }
if (Test-Path -LiteralPath $output) { throw 'Use a new fixture directory.' }
$tool = Join-Path $game 'Tools/SS2Dtool.exe'
$toolHash = (Get-FileHash -LiteralPath $tool).Hash
$fixture = Join-Path $PSScriptRoot '../prototype/fixture'
$testKey = [Guid]::NewGuid().ToString('N')
$utf8 = [Text.UTF8Encoding]::new($false)
New-Item -ItemType Directory -Path $output | Out-Null
Add-Type -AssemblyName System.Drawing
$preview = Join-Path $output 'preview.png'
$bitmap = [Drawing.Bitmap]::new(512,256)
$graphics = [Drawing.Graphics]::FromImage($bitmap)
$font = [Drawing.Font]::new('Arial',24,[Drawing.FontStyle]::Bold)
$smallFont = [Drawing.Font]::new('Arial',14)
try {
    $graphics.Clear([Drawing.Color]::FromArgb(22,35,51))
    $graphics.DrawString('SWD3 MOD Studio',$font,[Drawing.Brushes]::White,26,44)
    $graphics.DrawString('PRIVATE M0 TEST',$smallFont,[Drawing.Brushes]::LightSkyBlue,28,112)
    $graphics.DrawString('No gameplay effects',$smallFont,[Drawing.Brushes]::White,28,157)
    $bitmap.Save($preview,[Drawing.Imaging.ImageFormat]::Png)
} finally { $smallFont.Dispose(); $font.Dispose(); $graphics.Dispose(); $bitmap.Dispose() }
$previewHash = (Get-FileHash -LiteralPath $preview).Hash
$results = foreach ($revision in $Revisions) {
    $stage = Join-Path $output "revision-$revision"
    $src = Join-Path $stage 'src'
    $build = Join-Path $stage 'build'
    $verify = Join-Path $stage 'verify'
    $content = Join-Path $stage 'content'
    New-Item -ItemType Directory -Path (Join-Path $src 'data'),$build,$content | Out-Null
    $ext = [IO.File]::ReadAllText((Join-Path $fixture 'studio_m0_fixture.ext')).Replace('MODVersion 0,1',"MODVersion 0,$revision")
    [IO.File]::WriteAllText((Join-Path $src 'studio_m0_fixture.ext'),$ext,$utf8)
    $lua = [IO.File]::ReadAllText((Join-Path $fixture 'Main.lua')) + "`n-- Payload revision $revision; test key $testKey`n"
    [IO.File]::WriteAllText((Join-Path $src 'data/Main.lua'),$lua,$utf8)
    Push-Location $build
    try { & $tool p "-i$src" '-Istudio_m0_fixture' } finally { Pop-Location }
    $package = Join-Path $build 'studio_m0_fixture.ssmod'
    if (!(Test-Path -LiteralPath $package) -or (Get-Item -LiteralPath $package).Length -lt 100) { throw 'Missing/empty package.' }
    $verifyOutput = & python (Join-Path $PSScriptRoot 'Verify-M0Package.py') $package $src $verify
    if ($LASTEXITCODE -ne 0) { throw 'Independent reverse extraction failed.' }
    if (($verifyOutput | ConvertFrom-Json).result -ne 'PASS') { throw 'Missing reverse extraction PASS.' }
    $sourceLua = (Get-FileHash -LiteralPath (Join-Path $src 'data/Main.lua')).Hash
    $decodedLua = (Get-FileHash -LiteralPath (Join-Path $verify 'data/Main.lua')).Hash
    if ($sourceLua -ne $decodedLua) { throw 'Round-trip Lua mismatch.' }
    if (!(Test-Path -LiteralPath (Join-Path $verify 'studio_m0_fixture.ext'))) { throw 'Decoded metadata missing.' }
    # Also assert semantic fields after the independent byte-for-byte comparison.
    $decodedExt = Get-Content -LiteralPath (Join-Path $verify 'studio_m0_fixture.ext') -Raw
    if ($decodedExt -notmatch "MODVersion\s+0\s*,\s*$revision" -or $decodedExt -notmatch 'Main.lua') { throw 'Decoded metadata mismatch.' }
    Copy-Item -LiteralPath $package -Destination $content
    $hash = (Get-FileHash -LiteralPath $package).Hash
    $plan = [ordered]@{
        Schema=1; AppId=1638230; TestKey=$testKey; Revision=$revision
        ContentDirectory=$content; ContentSha256=$hash; PreviewFile=$preview; PreviewSha256=$previewHash
        Title="[PRIVATE M0 TEST] SWD3 MOD Studio r$revision"
        Description="Private connectivity test for SWD3 MOD Studio. Revision $revision. No gameplay effects. Verifies creation, same-ID update and downloaded package integrity. Test key: $testKey."
        ChangeNote="M0 private test revision $revision; no gameplay effects."
    }
    $planPath = Join-Path $output "plan-r$revision.json"
    $plan | ConvertTo-Json | Set-Content -LiteralPath $planPath -Encoding utf8
    [pscustomobject]@{Revision=$revision; PackageSHA256=$hash; LuaSHA256=$sourceLua; RoundTrip='PASS'; Plan=$planPath}
}
if ((Get-FileHash -LiteralPath $tool).Hash -ne $toolHash) { throw 'SS2Dtool changed during preparation.' }
[pscustomobject]@{TestKey=$testKey; AppId=1638230; Visibility='Private'; ToolSHA256=$toolHash; PreviewSHA256=$previewHash; Revisions=@($results)} |
    ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $output 'fixture-evidence.json') -Encoding utf8
Write-Output "PASS: Prepared and reverse-verified $($Revisions.Count) no-op revisions at $output. No Steam calls were made."
