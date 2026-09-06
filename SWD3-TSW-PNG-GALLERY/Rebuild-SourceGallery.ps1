param(
    [Parameter(Mandatory = $true)]
    [string]$GameRoot,

    [string]$GalleryRoot = $PSScriptRoot
)

$ErrorActionPreference = 'Stop'
$tool = Join-Path $GameRoot 'Tools\SS2Dtool.exe'
$sourceRoot = Join-Path $GameRoot 'swd3DVD'
$manifestPath = Join-Path $GalleryRoot 'tsw_index.ext'
$picRoot = Join-Path $GalleryRoot 'tsw'
$pngRoot = Join-Path $GalleryRoot 'tsw_png'
$expectedAssetCount = 20091
$requiredArchives = @(
    'all_char.tsw',
    'all_item.tsw',
    'all_magic.tsw',
    'all_sys.tsw',
    'all_map1.tsw',
    'all_map2.tsw'
)

if (-not (Test-Path -LiteralPath $tool -PathType Leaf)) {
    throw "SS2Dtool not found: $tool"
}
foreach ($archive in $requiredArchives) {
    $archivePath = Join-Path $sourceRoot $archive
    if (-not (Test-Path -LiteralPath $archivePath -PathType Leaf)) {
        throw "Required source archive not found: $archivePath"
    }
}

foreach ($outputRoot in @($picRoot, $pngRoot)) {
    if (Test-Path -LiteralPath $outputRoot) {
        if (@(Get-ChildItem -LiteralPath $outputRoot -Force).Count -ne 0) {
            throw "Output folder must be absent or empty: $outputRoot"
        }
    }
    else {
        New-Item -ItemType Directory -Path $outputRoot | Out-Null
    }
}

# SS2Dtool tep silently writes an empty manifest when the output subfolders do not
# already exist, so they are deliberately created above before invoking the tool.
& $tool tep ("-i" + $sourceRoot) ("-o" + $GalleryRoot)

$picCount = @(Get-ChildItem -LiteralPath $picRoot -File -Filter '*.pic').Count
$pngCount = @(Get-ChildItem -LiteralPath $pngRoot -File -Filter '*.png').Count
$manifestRows = if (Test-Path -LiteralPath $manifestPath -PathType Leaf) {
    @(Select-String -LiteralPath $manifestPath -Pattern '^TSW ').Count
}
else {
    0
}
if ($picCount -ne $expectedAssetCount -or $picCount -ne $pngCount -or $picCount -ne $manifestRows) {
    throw "Source gallery extraction incomplete: PIC=$picCount, PNG=$pngCount, manifest=$manifestRows."
}

& (Join-Path $PSScriptRoot 'Build-SourceGalleryIndex.ps1') -GalleryRoot $GalleryRoot
Write-Output ("Rebuilt source TSW gallery with {0} images." -f $pngCount)
