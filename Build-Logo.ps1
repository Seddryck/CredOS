[CmdletBinding()]
param(
    [string] $OutputDirectory = (Join-Path $PSScriptRoot '.artifacts/branding'),
    [ValidatePattern('^\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?$')]
    [string] $Version,
    [string] $SourceDirectory = (Join-Path $PSScriptRoot 'assets/logo'),
    [switch] $CheckTrackedAssets
)

$ErrorActionPreference = 'Stop'
$magick = (Get-Command magick -ErrorAction Stop).Source
$toolVersion = (& $magick -version)[0]
if ($LASTEXITCODE -ne 0 -or $toolVersion -notmatch '^Version: ImageMagick 7\.1\.2-29 Q16-HDRI ') {
    throw 'Branding requires ImageMagick 7.1.2-29 Q16-HDRI. See assets/logo/LAYER-COLORS.md.'
}
$output = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($OutputDirectory)
$source = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($SourceDirectory)
New-Item -ItemType Directory -Path $output -Force | Out-Null
$temporary = Join-Path $output ('.tmp-' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $temporary | Out-Null
$files = [System.Collections.Generic.List[string]]::new()

function Invoke-ImageMagick([string[]] $Arguments) {
    & $magick @Arguments
    if ($LASTEXITCODE -ne 0) { throw "ImageMagick failed with exit code $LASTEXITCODE." }
}

function Write-Png([string[]] $Arguments, [string] $Name) {
    Invoke-ImageMagick ($Arguments + @('-strip', '-define', 'png:exclude-chunk=date,time', '-depth', '8', ('PNG32:' + (Join-Path $output $Name))))
    $files.Add($Name)
}

try {
    $mapping = @(Get-Content -LiteralPath (Join-Path $source 'layer-colors.json') -Raw | ConvertFrom-Json)
    if ($mapping.Count -ne 54 -or @($mapping.layer | Sort-Object -Unique).Count -ne 54) {
        throw 'Expected 54 distinct grayscale layers.'
    }
    $allLayers = [System.Collections.Generic.List[string]]::new()
    $symbolLayers = [System.Collections.Generic.List[string]]::new()
    foreach ($layer in $mapping) {
        if ($layer.layer -notmatch '^layers/(?<element>0[1-9]|1[0-8])-[a-z-]+-(?<channel>[RGB])\.png$') {
            throw "Invalid layer path: $($layer.layer)"
        }
        $element = [int] $Matches.element
        $channel = $Matches.channel
        $zero = switch ($channel) { R { 'G,B' } G { 'R,B' } B { 'R,G' } }
        $color = switch ($channel) { R { '#FF0000' } G { '#00FF00' } B { '#0000FF' } }
        if ($layer.channel -cne $channel -or $layer.color -cne $color -or $layer.blend -cne 'Plus' -or
            $layer.opacity -ne 1 -or $layer.x -ne 0 -or $layer.y -ne 0) {
            throw "Unsupported mapping for $($layer.layer)."
        }
        $inputFile = Join-Path $source $layer.layer
        $colored = Join-Path $temporary (Split-Path $layer.layer -Leaf)
        # Keep grayscale intensity and alpha; multiply RGB by the assigned primary.
        # Flat -colorize would destroy the logo's gradients.
        Invoke-ImageMagick @($inputFile, '-channel', $zero, '-evaluate', 'set', '0', '+channel', '-depth', '8', ('PNG32:' + $colored))
        $allLayers.Add($colored)
        if ($element -le 12) { $symbolLayers.Add($colored) }
    }
    Write-Png ($allLayers.ToArray() + @('-background', 'none', '-compose', 'Plus', '-layers', 'merge')) 'credos-logo.png'
    $logo = Join-Path $output 'credos-logo.png'
    $reference = Join-Path $source 'reference.png'
    $difference = & $magick $reference $logo -channel RGBA -metric AE -compare -format '%[distortion]' info:
    if ($LASTEXITCODE -ne 0 -or [double] $difference -ne 0) {
        throw "Logo differs from the approved transparent reference: $difference RGBA pixels."
    }
    Write-Host '[logo] Exact reconstruction verified: zero differing RGBA pixels.'

    $symbol = Join-Path $temporary 'symbol.png'
    Invoke-ImageMagick ($symbolLayers.ToArray() + @('-background', 'none', '-compose', 'Plus', '-layers', 'merge', '-trim', '+repage', ('PNG32:' + $symbol)))
    $dimensions = (& $magick identify -format '%w %h' $symbol) -split ' '
    if ($LASTEXITCODE -ne 0 -or $dimensions.Count -ne 2) { throw 'Could not measure the symbol.' }
    $contentSize = [Math]::Max([int] $dimensions[0], [int] $dimensions[1])
    $canvasSize = $contentSize + 2 * [Math]::Ceiling($contentSize * 0.075)
    $square = Join-Path $temporary 'symbol-square.png'
    Invoke-ImageMagick @($symbol, '-background', 'none', '-gravity', 'center', '-extent', "${canvasSize}x${canvasSize}", ('PNG32:' + $square))
    foreach ($size in @(256, 128, 64, 32, 16)) {
        Write-Png @($square, '-filter', 'Lanczos', '-resize', "${size}x${size}") "credos-icon-$size.png"
    }
    # Stable package paths are independent of the distribution filenames.
    Copy-Item -LiteralPath (Join-Path $output 'credos-icon-128.png') -Destination (Join-Path $output 'credos-icon.png') -Force
    $files.Add('credos-icon.png')
    foreach ($size in @(512, 256, 128)) {
        Write-Png @($logo, '-filter', 'Lanczos', '-resize', "${size}x${size}") "credos-logo-$size.png"
    }
    $frames = @(256, 128, 64, 32, 16 | ForEach-Object { Join-Path $output "credos-icon-$_.png" })
    Invoke-ImageMagick ($frames + (Join-Path $output 'credos.ico'))
    $files.Add('credos.ico')
    Copy-Item -LiteralPath (Join-Path $output 'credos.ico') -Destination (Join-Path $output 'favicon.ico') -Force
    $files.Add('favicon.ico')

    if ($CheckTrackedAssets) {
        foreach ($name in @('credos-logo.png', 'credos-icon.png')) {
            $generatedHash = (Get-FileHash -LiteralPath (Join-Path $output $name) -Algorithm SHA256).Hash
            $trackedHash = (Get-FileHash -LiteralPath (Join-Path $PSScriptRoot "assets/$name") -Algorithm SHA256).Hash
            if ($generatedHash -cne $trackedHash) { throw "Tracked assets/$name is stale. Run Build-Logo.ps1 and copy the generated file." }
        }
        Write-Host '[logo] Tracked README logo and package icon match generated files.'
    }
    $entries = @($files | Sort-Object | ForEach-Object {
        [ordered]@{ name = $_; sha256 = (Get-FileHash -LiteralPath (Join-Path $output $_) -Algorithm SHA256).Hash }
    })
    [ordered]@{ schemaVersion = 1; version = $Version; imageMagick = '7.1.2-29 Q16-HDRI'; files = $entries } |
        ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $output 'branding-manifest.json') -Encoding utf8NoBOM
    if ($Version) {
        $archivePath = Join-Path $output "credos-branding-$Version.zip"
        # Only replace this build's explicitly named archive; stale output files
        # are never swept into it. Fixed entry timestamps make repeated builds stable.
        if (Test-Path -LiteralPath $archivePath) { Remove-Item -LiteralPath $archivePath }
        $archive = [System.IO.Compression.ZipFile]::Open($archivePath, [System.IO.Compression.ZipArchiveMode]::Create)
        try {
            foreach ($name in @($files.ToArray() + 'branding-manifest.json' | Sort-Object)) {
                $entry = $archive.CreateEntry($name, [System.IO.Compression.CompressionLevel]::Optimal)
                $entry.LastWriteTime = [DateTimeOffset]::new(1980, 1, 1, 0, 0, 0, [TimeSpan]::Zero)
                $inputStream = [System.IO.File]::OpenRead((Join-Path $output $name))
                $outputStream = $entry.Open()
                try { $inputStream.CopyTo($outputStream) }
                finally { $inputStream.Dispose(); $outputStream.Dispose() }
            }
        }
        finally { $archive.Dispose() }
    }
}
finally {
    # The GUID directory was created inside the resolved output directory above.
    if ([System.IO.Path]::GetDirectoryName([System.IO.Path]::GetFullPath($temporary)) -ne $output.TrimEnd([System.IO.Path]::DirectorySeparatorChar)) {
        throw 'Refusing cleanup outside the branding output directory.'
    }
    Remove-Item -LiteralPath $temporary -Recurse -Force
}
Write-Host "[logo] Branding output: $output"
