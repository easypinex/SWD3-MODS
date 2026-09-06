param(
    [string]$GalleryRoot = $PSScriptRoot
)

$ErrorActionPreference = 'Stop'
$pngRoot = Join-Path $GalleryRoot 'tsw_png'
$indexPath = Join-Path $GalleryRoot 'tsw_png_index.csv'
$rows = @(Import-Csv -LiteralPath $indexPath)

function Get-SafeLabel([string]$Text) {
    if ([string]::IsNullOrWhiteSpace($Text)) { return $null }
    $label = $Text -replace '[<>:"/\\|?*\x00-\x1F]', '-'
    $label = $label -replace '\s+', '-'
    $label = $label.Trim(' ', '.', '-')
    if ($label.Length -gt 48) { $label = $label.Substring(0, 48).TrimEnd(' ', '.', '-') }
    if ([string]::IsNullOrWhiteSpace($label)) { return $null }
    return $label
}

foreach ($row in $rows) {
    $id = [int]$row.Id
    $sn = [int]$row.SN
    $type = Get-SafeLabel $row.TypeName
    $label = Get-SafeLabel $row.Comment
    $newName = 'SRC-TSW{0:D5}-SN{1:D2}__{2}' -f $id, $sn, $type
    if ($null -ne $label) { $newName += "__$label" }
    $newName += '.png'

    $oldPath = Join-Path $pngRoot $row.PngFile
    $newPath = Join-Path $pngRoot $newName
    if (Test-Path -LiteralPath $oldPath) {
        if ((Test-Path -LiteralPath $newPath) -and ($oldPath -ne $newPath)) {
            throw "Target filename already exists: $newName"
        }
        if ($oldPath -ne $newPath) { Move-Item -LiteralPath $oldPath -Destination $newPath }
    }
    elseif (-not (Test-Path -LiteralPath $newPath)) {
        throw "Preview PNG not found: $($row.PngFile)"
    }
    $row.PngFile = $newName
    $row.PngExists = (Test-Path -LiteralPath $newPath)
}

$rows | Export-Csv -LiteralPath $indexPath -NoTypeInformation -Encoding utf8
$missing = @($rows | Where-Object { $_.PngExists -ne $true }).Count
Write-Output ("Renamed {0} PNG previews; missing={1}" -f $rows.Count, $missing)
