param(
    [Parameter(Mandatory = $true)]
    [string]$ExtractedPngRoot,

    [Parameter(Mandatory = $true)]
    [string]$ConvertedPngRoot,

    [string]$GalleryRoot = $PSScriptRoot
)

$ErrorActionPreference = 'Stop'
$destination = Join-Path $GalleryRoot 'hd_tsw_png'
if (-not (Test-Path -LiteralPath $ExtractedPngRoot)) {
    throw "HD extraction folder not found: $ExtractedPngRoot"
}

if (Test-Path -LiteralPath $destination) {
    if (@(Get-ChildItem -LiteralPath $destination -Force).Count -ne 0) {
        throw "Gallery output folder must be absent or empty: $destination"
    }
}
else {
    New-Item -ItemType Directory -Path $destination | Out-Null
}
if (-not (Test-Path -LiteralPath $ConvertedPngRoot)) {
    throw "Converted HD PNG folder not found: $ConvertedPngRoot"
}
$files = @(
    Get-ChildItem -LiteralPath $ExtractedPngRoot -File -Filter '*.png'
    Get-ChildItem -LiteralPath $ConvertedPngRoot -File -Filter '*.png'
)
if (@($files | Group-Object Name | Where-Object Count -gt 1).Count -ne 0) {
    throw 'PNG filename collision between extracted and converted assets.'
}
if ($files.Count -ne 20554) {
    throw "Unexpected HD PNG count: expected=20554, actual=$($files.Count)."
}
foreach ($file in $files) {
    Copy-Item -LiteralPath $file.FullName -Destination (Join-Path $destination $file.Name) -Force
}

$files | ForEach-Object {
    [pscustomobject]@{
        Archive = 'Steam HD tsw_index.ssmod'
        ExtractedFile = $_.Name
        PngFile = $_.Name
        TswId = ''
        SN = ''
        MappingStatus = 'unmapped'
        Notes = 'Archive extraction retains this file name but emits no TSW ID/SN index.'
    }
} | Export-Csv -LiteralPath (Join-Path $GalleryRoot 'hd_tsw_png_index.csv') -NoTypeInformation -Encoding utf8

@(
    [pscustomobject]@{
        TswId = '9385'; SN = '0'; Status = 'verified'; Purpose = '物品頁背景'; Evidence = 'GameData.ACTdef.MenuWallPaper_BG_TSW；實機繪製確認不透明。'; MatchingPng = ''
    }
    [pscustomobject]@{
        TswId = '10007'; SN = '0'; Status = 'verified'; Purpose = '戰鬥 AI 說明底圖'; Evidence = '原版 OnEvent_Battle.lua 註解與實機繪製確認半透明藍色。'; MatchingPng = ''
    }
) | Export-Csv -LiteralPath (Join-Path $GalleryRoot 'hd_tsw_known_references.csv') -NoTypeInformation -Encoding utf8

$missing = @($files | Where-Object { -not (Test-Path -LiteralPath (Join-Path $destination $_.Name)) }).Count
Write-Output ("Copied {0} HD PNG files; missing={1}" -f $files.Count, $missing)
