[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$InputRoot,
    [Parameter(Mandatory)]
    [string]$OutputPath
)

$ErrorActionPreference = 'Stop'
$inputRootPath = (Resolve-Path -LiteralPath $InputRoot).Path
$assemblyPath = Join-Path $inputRootPath 'SWD3Works.exe'

$resolver = [System.ResolveEventHandler]{
    param($sender, $args)
    $simpleName = ([System.Reflection.AssemblyName]$args.Name).Name + '.dll'
    $candidate = Join-Path $inputRootPath $simpleName
    if (Test-Path -LiteralPath $candidate -PathType Leaf) {
        return [System.Reflection.Assembly]::ReflectionOnlyLoadFrom($candidate)
    }
    try {
        return [System.Reflection.Assembly]::ReflectionOnlyLoad($args.Name)
    } catch {
        return $null
    }
}
[AppDomain]::CurrentDomain.add_ReflectionOnlyAssemblyResolve($resolver)
try {
    $steamworksAssembly = Join-Path $inputRootPath 'Steamworks.NET.dll'
    if (Test-Path -LiteralPath $steamworksAssembly -PathType Leaf) {
        [void][System.Reflection.Assembly]::ReflectionOnlyLoadFrom($steamworksAssembly)
    }
    $assembly = [System.Reflection.Assembly]::ReflectionOnlyLoadFrom($assemblyPath)
    try {
        $types = $assembly.GetTypes()
        $loaderErrors = @()
    } catch [System.Reflection.ReflectionTypeLoadException] {
        $types = $_.Exception.Types | Where-Object { $_ -ne $null }
        $loaderErrors = $_.Exception.LoaderExceptions | ForEach-Object Message
    }
    $typeRows = foreach ($type in $types | Sort-Object FullName) {
        $methods = @($type.GetMethods([System.Reflection.BindingFlags]'Public,NonPublic,Instance,Static,DeclaredOnly') | ForEach-Object Name)
        $fields = @($type.GetFields([System.Reflection.BindingFlags]'Public,NonPublic,Instance,Static,DeclaredOnly') | ForEach-Object Name)
        if ((($type.FullName + ' ' + ($methods -join ' ') + ' ' + ($fields -join ' ')) -match '(?i)workshop|ugc|item|update|published|install|steam')) {
            [pscustomobject]@{
                Type = $type.FullName
                Methods = ($methods | Sort-Object -Unique) -join ', '
                Fields = ($fields | Sort-Object -Unique) -join ', '
            }
        }
    }
    @(
        'SWD3Works managed metadata inventory (Windows PowerShell reflection-only)',
        "Assembly: $($assembly.FullName)",
        'Assembly references:',
        ($assembly.GetReferencedAssemblies() | ForEach-Object FullName),
        '',
        'Workshop/UGC/item/update/install-related types:',
        ($typeRows | Format-List | Out-String),
        'Type-load diagnostics:',
        ($loaderErrors | Sort-Object -Unique)
    ) | Set-Content -LiteralPath $OutputPath -Encoding utf8
} finally {
    [AppDomain]::CurrentDomain.remove_ReflectionOnlyAssemblyResolve($resolver)
}
