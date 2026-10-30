[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidatePattern('^\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?$')]
    [string] $Version,

    [Parameter(Mandatory)]
    [ValidatePattern('^[0-9a-fA-F]{40}$')]
    [string] $Commit,

    [Parameter(Mandatory)]
    [string] $NuGetDirectory
)

$ErrorActionPreference = 'Stop'
$packageId = 'CredOS.Core'
$frameworks = @('net8.0', 'net9.0', 'net10.0')
$packages = @(Get-ChildItem -LiteralPath $NuGetDirectory -Filter '*.nupkg' -File)
$symbols = @(Get-ChildItem -LiteralPath $NuGetDirectory -Filter '*.snupkg' -File)
if ($packages.Count -ne 1 -or $symbols.Count -ne 1) {
    throw 'Expected exactly one CredOS.Core package and one symbol package.'
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
            foreach ($entry in @('README.md', 'docs/api.md', 'docs/releases.md')) {
                if ($entries -cnotcontains $entry) { throw "Package is missing $entry." }
            }
            foreach ($framework in $frameworks) {
                foreach ($extension in @('dll', 'xml')) {
                    if ($entries -cnotcontains "lib/$framework/$packageId.$extension") {
                        throw "Package is missing $framework $extension."
                    }
                }
            }
        }
        else {
            foreach ($framework in $frameworks) {
                if ($entries -cnotcontains "lib/$framework/$packageId.pdb") {
                    throw "Symbol package is missing $framework PDB."
                }
            }
        }
    }
    finally { $archive.Dispose() }
}
Write-Host "Validated CredOS.Core $Version and symbols for commit $Commit on all three frameworks."
