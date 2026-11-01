[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string] $Version,
    [Parameter(Mandatory)] [string] $BrandingDirectory
)

$ErrorActionPreference = 'Stop'
$root = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$builder = Join-Path $root 'Build-Logo.ps1'
$validator = Join-Path $PSScriptRoot 'Validate-BrandingAssets.ps1'
$inputDirectory = (Resolve-Path -LiteralPath $BrandingDirectory).Path
$fixture = Join-Path $root ('.artifacts/branding-tests/' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $fixture -Force | Out-Null
$script:checks = 0
function Expect-Failure([scriptblock] $Action, [string] $Message) {
    $failed = $false
    try { & $Action }
    catch { $failed = $true }
    if (!$failed) { throw $Message }
    $script:checks++
}

& $validator -BrandingDirectory $inputDirectory -Version $Version
$script:checks++
$repeat = Join-Path $fixture 'repeat'
& $builder -OutputDirectory $repeat -Version $Version -CheckTrackedAssets
& $validator -BrandingDirectory $repeat -Version $Version
foreach ($file in Get-ChildItem -LiteralPath $inputDirectory -File) {
    if ((Get-FileHash -LiteralPath $file.FullName).Hash -cne (Get-FileHash -LiteralPath (Join-Path $repeat $file.Name)).Hash) {
        throw "Repeated branding build differs: $($file.Name)"
    }
}
$script:checks++

# Inspect actual grayscale values and alpha, independently of the coloring step.
$mapping = Get-Content -LiteralPath (Join-Path $root 'assets/logo/layer-colors.json') -Raw | ConvertFrom-Json
foreach ($item in $mapping) {
    $mask = Join-Path $root ('assets/logo/' + $item.layer)
    $difference = & magick $mask '(' +clone -colorspace Gray -set colorspace sRGB ')' -channel RGBA -metric AE -compare -format '%[distortion]' info:
    if ($LASTEXITCODE -ne 0 -or [double] $difference -ne 0) { throw "Source is not grayscale: $($item.layer)" }
    $details = & magick identify -format '%w %h %[opaque] %[fx:minima.a] %[fx:maxima.a]' $mask
    if ($LASTEXITCODE -ne 0 -or $details -cne '1448 1086 False 0 1') { throw "Unexpected canvas/transparency: $($item.layer): $details" }
}
$script:checks++

# A fixture copy of the builder checks freshness without editing tracked files.
$staleRoot = Join-Path $fixture 'stale-preview'
New-Item -ItemType Directory -Path (Join-Path $staleRoot 'assets') -Force | Out-Null
Copy-Item -LiteralPath $builder -Destination (Join-Path $staleRoot 'Build-Logo.ps1')
Copy-Item -LiteralPath (Join-Path $root 'assets/credos-icon.png') -Destination (Join-Path $staleRoot 'assets/credos-icon.png')
[System.IO.File]::WriteAllBytes((Join-Path $staleRoot 'assets/credos-logo.png'), [byte[]] @(0))
Expect-Failure {
    & (Join-Path $staleRoot 'Build-Logo.ps1') -SourceDirectory (Join-Path $root 'assets/logo') -OutputDirectory (Join-Path $staleRoot 'output') -Version $Version -CheckTrackedAssets
} 'Build accepted a stale tracked README preview.'

$modifiedSource = Join-Path $fixture 'source'
Copy-Item -LiteralPath (Join-Path $root 'assets/logo') -Destination $modifiedSource -Recurse
$first = Join-Path $modifiedSource $mapping[0].layer
Remove-Item -LiteralPath $first
Expect-Failure { & $builder -SourceDirectory $modifiedSource -OutputDirectory (Join-Path $fixture 'missing-layer') -Version $Version } 'Build accepted a missing layer.'
Copy-Item -LiteralPath (Join-Path $root ('assets/logo/' + $mapping[0].layer)) -Destination $first
& magick $first -channel RGB -evaluate set 0 +channel $first
if ($LASTEXITCODE -ne 0) { throw 'Could not mutate the fixture layer.' }
Expect-Failure { & $builder -SourceDirectory $modifiedSource -OutputDirectory (Join-Path $fixture 'changed-layer') -Version $Version } 'Build accepted changed artwork.'
Expect-Failure { & $validator -BrandingDirectory $inputDirectory -Version '999.0.0' } 'Validator accepted the wrong branding version.'

$zipPath = Join-Path $repeat "credos-branding-$Version.zip"
$archive = [System.IO.Compression.ZipFile]::Open($zipPath, [System.IO.Compression.ZipArchiveMode]::Update)
try { $archive.GetEntry('credos-logo.png').Delete() }
finally { $archive.Dispose() }
Expect-Failure { & $validator -BrandingDirectory $repeat -Version $Version } 'Validator accepted an incomplete branding archive.'
[System.IO.File]::WriteAllBytes((Join-Path $repeat 'credos-icon.png'), [byte[]] @(0))
Expect-Failure { & $validator -BrandingDirectory $repeat -Version $Version } 'Validator accepted a changed asset.'
Write-Host "Passed $script:checks branding-pipeline checks. Fixture retained at $fixture."
