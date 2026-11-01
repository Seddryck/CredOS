[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string] $BrandingDirectory,
    [Parameter(Mandatory)]
    [ValidatePattern('^\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?$')]
    [string] $Version
)

$ErrorActionPreference = 'Stop'
$expected = @('credos-logo.png', 'credos-icon.png', 'credos.ico', 'favicon.ico') +
    @(256, 128, 64, 32, 16 | ForEach-Object { "credos-icon-$_.png" }) +
    @(512, 256, 128 | ForEach-Object { "credos-logo-$_.png" })
$manifest = Get-Content -LiteralPath (Join-Path $BrandingDirectory 'branding-manifest.json') -Raw | ConvertFrom-Json
if ($manifest.schemaVersion -ne 1 -or $manifest.version -cne $Version -or $manifest.imageMagick -cne '7.1.2-29 Q16-HDRI') {
    throw 'Branding manifest has an unexpected schema, version, or toolchain.'
}
if ($manifest.files.Count -ne $expected.Count -or @($manifest.files.name | Sort-Object -Unique).Count -ne $expected.Count) {
    throw 'Branding manifest must list exactly the expected distinct assets.'
}
foreach ($file in $manifest.files) {
    if ($expected -cnotcontains $file.name) { throw "Unexpected branding asset: $($file.name)" }
    $path = Join-Path $BrandingDirectory $file.name
    if ((Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash -cne $file.sha256) {
        throw "Branding checksum mismatch: $($file.name)"
    }
    if ($file.name -like '*.png') {
        $stream = [System.IO.File]::OpenRead($path)
        try { $header = [byte[]]::new(26); $stream.ReadExactly($header) }
        finally { $stream.Dispose() }
        if ([Convert]::ToHexString($header[0..7]) -cne '89504E470D0A1A0A' -or $header[25] -ne 6) {
            throw "Expected an RGBA PNG: $($file.name)"
        }
        $width = [Convert]::ToInt32([Convert]::ToHexString($header[16..19]), 16)
        $height = [Convert]::ToInt32([Convert]::ToHexString($header[20..23]), 16)
        $expectedWidth, $expectedHeight = if ($file.name -eq 'credos-logo.png') { 1448, 1086 }
            elseif ($file.name -eq 'credos-icon.png') { 128, 128 }
            elseif ($file.name -match '^credos-icon-(\d+)\.png$') { [int] $Matches[1], [int] $Matches[1] }
            elseif ($file.name -match '^credos-logo-(\d+)\.png$') { [int] $Matches[1], ([int] $Matches[1] * 3 / 4) }
        if ($width -ne $expectedWidth -or $height -ne $expectedHeight) {
            throw "Unexpected PNG dimensions: $($file.name) is ${width}x${height}."
        }
    }
}
$archive = [System.IO.Compression.ZipFile]::OpenRead((Join-Path $BrandingDirectory "credos-branding-$Version.zip"))
try {
    if ($archive.Entries.Count -ne ($expected.Count + 1)) { throw 'Branding archive has unexpected contents.' }
    foreach ($name in @($expected + 'branding-manifest.json')) {
        $entries = @($archive.Entries | Where-Object FullName -CEQ $name)
        if ($entries.Count -ne 1) { throw "Branding archive is missing a unique $name entry." }
        $stream = $entries[0].Open()
        $hasher = [System.Security.Cryptography.SHA256]::Create()
        try { $hash = [Convert]::ToHexString($hasher.ComputeHash($stream)) }
        finally { $stream.Dispose(); $hasher.Dispose() }
        if ($hash -cne (Get-FileHash -LiteralPath (Join-Path $BrandingDirectory $name) -Algorithm SHA256).Hash) {
            throw "Branding archive does not contain the validated $name."
        }
    }
}
finally { $archive.Dispose() }
Write-Host "Validated $($expected.Count) branding assets and CredOS $Version branding archive."
