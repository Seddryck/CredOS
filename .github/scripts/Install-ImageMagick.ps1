[CmdletBinding()]
param([string] $OutputDirectory = (Join-Path $PSScriptRoot '../../.artifacts/tools/imagemagick'))

$ErrorActionPreference = 'Stop'
if (!$IsWindows -or [System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture -ne 'X64') {
    throw 'This CI bootstrap installs the pinned portable Windows x64 toolchain only.'
}
$version = '7.1.2-29'
$sha256 = 'B68E312B21556AE8872704E37DF3C69CBDC0EA7100366BF823E7E3A1B69405BC'
$directory = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($OutputDirectory)
New-Item -ItemType Directory -Path $directory -Force | Out-Null
$archive = Join-Path $directory 'imagemagick.7z'
Invoke-WebRequest -Uri "https://github.com/ImageMagick/ImageMagick/releases/download/$version/ImageMagick-$version-portable-Q16-HDRI-x64.7z" -OutFile $archive
if ((Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash -cne $sha256) {
    throw 'ImageMagick archive SHA-256 does not match the pinned release.'
}
& 7z x $archive "-o$directory" -y | Out-Host
if ($LASTEXITCODE -ne 0) { throw 'ImageMagick extraction failed.' }
$binary = Join-Path $directory 'magick.exe'
if (!(Test-Path -LiteralPath $binary)) { throw 'Portable ImageMagick executable not found.' }
$env:PATH = "$directory$([System.IO.Path]::PathSeparator)$env:PATH"
if ($env:GITHUB_PATH) { $directory >> $env:GITHUB_PATH }
& $binary -version
if ($LASTEXITCODE -ne 0) { throw 'Portable ImageMagick could not start.' }
