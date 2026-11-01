[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidatePattern('^\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?$')]
    [string] $Version,

    [Parameter(Mandatory)]
    [ValidatePattern('^[0-9a-fA-F]{40}$')]
    [string] $Commit,

    [Parameter(Mandatory)]
    [string] $NuGetDirectory,

    [string] $BrandingDirectory
)

$ErrorActionPreference = 'Stop'
$packageId = 'CredOS'
$assemblyName = 'CredOS.Core'
$frameworks = @('net8.0', 'net9.0', 'net10.0')
if ($BrandingDirectory) {
    & (Join-Path $PSScriptRoot 'Validate-BrandingAssets.ps1') -BrandingDirectory $BrandingDirectory -Version $Version
}
$packages = @(Get-ChildItem -LiteralPath $NuGetDirectory -Filter '*.nupkg' -File)
$symbols = @(Get-ChildItem -LiteralPath $NuGetDirectory -Filter '*.snupkg' -File)
if ($packages.Count -ne 1 -or $symbols.Count -ne 1) {
    throw 'Expected exactly one CredOS package and one symbol package.'
}
if ($packages[0].Name -cne "$packageId.$Version.nupkg" -or $symbols[0].Name -cne "$packageId.$Version.snupkg") {
    throw 'Package filenames do not match the expected identity and version.'
}

foreach ($package in @($packages[0], $symbols[0])) {
    $archive = [System.IO.Compression.ZipFile]::OpenRead($package.FullName)
    try {
        $entries = @($archive.Entries.FullName)
        $nuspec = $archive.GetEntry("$packageId.nuspec")
        if (!$nuspec) { throw "Missing nuspec in $($package.Name)." }
        $reader = [System.IO.StreamReader]::new($nuspec.Open())
        try { [xml] $metadata = $reader.ReadToEnd() }
        finally { $reader.Dispose() }
        $identity = $metadata.package.metadata
        if ($identity.id -cne $packageId -or $identity.version -cne $Version) {
            throw "Package metadata does not match the expected identity/version in $($package.Name)."
        }
        if ($identity.repository.commit -ne $Commit -or $identity.repository.url -ne 'https://github.com/Seddryck/CredOS') {
            throw "Package repository metadata does not identify the tested commit in $($package.Name)."
        }
        if ($package.Extension -eq '.nupkg') {
            if ($identity.license.InnerText -ne 'Apache-2.0') { throw 'Missing Apache-2.0 license metadata.' }
            foreach ($entry in @('README.md', 'docs/api.md', 'docs/releases.md', 'assets/credos-logo.png', 'assets/credos-icon.png')) {
                if ($entries -cnotcontains $entry) { throw "Package is missing $entry." }
            }
            if ($identity.icon -cne 'assets/credos-icon.png') { throw 'Package metadata does not reference the symbol-only icon.' }
            if ($BrandingDirectory) {
                foreach ($name in @('credos-logo.png', 'credos-icon.png')) {
                    $stream = $archive.GetEntry("assets/$name").Open()
                    $hasher = [System.Security.Cryptography.SHA256]::Create()
                    try { $hash = [Convert]::ToHexString($hasher.ComputeHash($stream)) }
                    finally { $stream.Dispose(); $hasher.Dispose() }
                    if ($hash -cne (Get-FileHash -LiteralPath (Join-Path $BrandingDirectory $name) -Algorithm SHA256).Hash) {
                        throw "Package assets/$name differs from validated branding."
                    }
                }
            }
            $icon = $archive.GetEntry('assets/credos-icon.png')
            if ($icon.Length -gt 1MB) { throw 'Package icon exceeds the NuGet size limit.' }
            $stream = $icon.Open()
            try {
                $header = [byte[]]::new(24)
                $stream.ReadExactly($header)
                if ([Convert]::ToHexString($header[0..7]) -ne '89504E470D0A1A0A' -or
                    [Convert]::ToHexString($header[12..15]) -ne '49484452' -or
                    [Convert]::ToHexString($header[16..23]) -ne '0000008000000080') {
                    throw 'Package icon must be a 128x128 PNG.'
                }
            }
            finally { $stream.Dispose() }
            foreach ($framework in $frameworks) {
                foreach ($extension in @('dll', 'xml')) {
                    if ($entries -cnotcontains "lib/$framework/$assemblyName.$extension") {
                        throw "Package is missing $framework $extension."
                    }
                }
            }
        }
        else {
            foreach ($framework in $frameworks) {
                if ($entries -cnotcontains "lib/$framework/$assemblyName.pdb") {
                    throw "Symbol package is missing $framework PDB."
                }
            }
        }
    }
    finally { $archive.Dispose() }
}
Write-Host "Validated CredOS $Version and symbols for commit $Commit on all three frameworks."
