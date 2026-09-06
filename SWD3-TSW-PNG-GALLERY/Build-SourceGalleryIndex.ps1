param(
    [string]$GalleryRoot = $PSScriptRoot
)

$ErrorActionPreference = 'Stop'
$manifestPath = Join-Path $GalleryRoot 'tsw_index.ext'
$pngRoot = Join-Path $GalleryRoot 'tsw_png'
$indexPath = Join-Path $GalleryRoot 'tsw_png_index.csv'
$expectedAssetCount = 20091

if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
    throw "TSW manifest not found: $manifestPath"
}
if (-not (Test-Path -LiteralPath $pngRoot -PathType Container)) {
    throw "Extracted PNG folder not found: $pngRoot"
}

$typeNames = @{
    '1' = 'char'
    '2' = 'item'
    '3' = 'effect'
    '4' = 'system'
    '5' = 'map1'
    '6' = 'map2'
    '8' = 'hga'
}

$rows = @(
    foreach ($line in Get-Content -LiteralPath $manifestPath) {
        if (-not $line.StartsWith('TSW ')) { continue }
        $fields = $line.Substring(4).Split(',', 6)
        if ($fields.Count -ne 6) { throw "Malformed TSW line: $line" }

        $id = $fields[0].Trim()
        $sn = $fields[1].Trim()
        $type = $fields[2].Trim()
        $langId = $fields[3].Trim()
        $picFile = $fields[4].Trim()
        $comment = $fields[5].Trim()
        $pngFile = [System.IO.Path]::ChangeExtension($picFile, '.png')

        [pscustomobject]@{
            Id = $id
            SN = $sn
            Type = $type
            TypeName = if ($typeNames.ContainsKey($type)) { $typeNames[$type] } else { 'unknown' }
            LangId = $langId
            PicFile = $picFile
            PngFile = $pngFile
            Comment = $comment
            PngExists = Test-Path -LiteralPath (Join-Path $pngRoot $pngFile) -PathType Leaf
        }
    }
)

$pngCount = @(Get-ChildItem -LiteralPath $pngRoot -File -Filter '*.png').Count
if ($rows.Count -ne $expectedAssetCount -or $rows.Count -ne $pngCount) {
    throw "Index mismatch before rename: manifest=$($rows.Count), PNG=$pngCount."
}
if (@($rows | Where-Object { -not $_.PngExists }).Count -ne 0) {
    throw 'At least one manifest PNG is missing; refusing to create a partial index.'
}

$rows | Export-Csv -LiteralPath $indexPath -NoTypeInformation -Encoding utf8
& (Join-Path $PSScriptRoot 'Rename-PngPreviews.ps1') -GalleryRoot $GalleryRoot

$finalRows = @(Import-Csv -LiteralPath $indexPath)
$missing = @($finalRows | Where-Object { $_.PngExists -ne 'True' }).Count
if ($finalRows.Count -ne $rows.Count -or $missing -ne 0) {
    throw "Final index verification failed: rows=$($finalRows.Count), missing=$missing."
}

Write-Output ("Built source gallery index for {0} PNG previews." -f $finalRows.Count)
