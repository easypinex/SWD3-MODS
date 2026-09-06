param(
    [Parameter(Mandatory = $true)]
    [string]$ToolPath,

    [Parameter(Mandatory = $true)]
    [string]$ExtractedPicRoot,

    [Parameter(Mandatory = $true)]
    [string]$OutputRoot,

    [int]$ThrottleLimit = 8
)

$ErrorActionPreference = 'Stop'
if (-not (Test-Path -LiteralPath $ToolPath)) { throw "SS2Dtool not found: $ToolPath" }
if (-not (Test-Path -LiteralPath $ExtractedPicRoot)) { throw "HD extraction folder not found: $ExtractedPicRoot" }
if (Test-Path -LiteralPath $OutputRoot) {
    if (@(Get-ChildItem -LiteralPath $OutputRoot -Force).Count -ne 0) {
        throw "Output folder must be empty to avoid overwriting previews: $OutputRoot"
    }
}
else {
    New-Item -ItemType Directory -Path $OutputRoot | Out-Null
}

$pictures = @(Get-ChildItem -LiteralPath $ExtractedPicRoot -File -Filter '*.pic')
$failed = @(
    $pictures | ForEach-Object -Parallel {
        $picture = $_
        $outputFile = Join-Path $using:OutputRoot ($picture.BaseName + '.png')
        & $using:ToolPath pg ("-i" + $using:ExtractedPicRoot) ("-I" + $picture.Name) ("-o" + $using:OutputRoot) ("-O" + $picture.BaseName + '.png')
        if (-not (Test-Path -LiteralPath $outputFile)) { return $picture.Name }
    } -ThrottleLimit $ThrottleLimit
)

$converted = @(Get-ChildItem -LiteralPath $OutputRoot -File -Filter '*.png').Count
if ($failed.Count -ne 0 -or $converted -ne $pictures.Count) {
    throw "Conversion incomplete: source=$($pictures.Count), output=$converted, failures=$($failed.Count)."
}
Write-Output ("Converted {0} HD PIC files to PNG." -f $converted)
