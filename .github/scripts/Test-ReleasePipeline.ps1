[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string] $Version,
    [Parameter(Mandatory)] [string] $Commit,
    [Parameter(Mandatory)] [string] $NuGetDirectory,
    [string] $BrandingDirectory
)

$ErrorActionPreference = 'Stop'
$validator = Join-Path $PSScriptRoot 'Validate-ReleaseArtifacts.ps1'
$reserveTag = Join-Path $PSScriptRoot 'Reserve-ReleaseTag.ps1'
$repositoryRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$fixture = Join-Path $repositoryRoot ".artifacts/release-tests/$([Guid]::NewGuid().ToString('N'))"
New-Item -ItemType Directory -Path $fixture -Force | Out-Null
$packageDirectory = (Resolve-Path -LiteralPath $NuGetDirectory).Path
$script:checks = 0

function Expect-Failure([scriptblock] $Action, [string] $Message) {
    $failed = $false
    try { & $Action }
    catch { $failed = $true }
    if (!$failed) { throw $Message }
    $script:checks++
}

function Copy-Packages([string] $Name) {
    $directory = Join-Path $fixture $Name
    New-Item -ItemType Directory -Path $directory | Out-Null
    Get-ChildItem -LiteralPath $packageDirectory -File | Copy-Item -Destination $directory
    return $directory
}

function Remove-ArchiveEntry([string] $Path, [string] $Entry) {
    $archive = [System.IO.Compression.ZipFile]::Open($Path, [System.IO.Compression.ZipArchiveMode]::Update)
    try { $archive.GetEntry($Entry).Delete() }
    finally { $archive.Dispose() }
}

& $validator -Version $Version -Commit $Commit -NuGetDirectory $packageDirectory
$script:checks++
if ($BrandingDirectory) {
    & $validator -Version $Version -Commit $Commit -NuGetDirectory $packageDirectory -BrandingDirectory $BrandingDirectory
    $script:checks++
    $wrongBranding = Copy-Packages 'wrong-branding'
    $archive = [System.IO.Compression.ZipFile]::Open((Join-Path $wrongBranding "CredOS.$Version.nupkg"), [System.IO.Compression.ZipArchiveMode]::Update)
    try {
        $archive.GetEntry('assets/credos-logo.png').Delete()
        $stream = $archive.CreateEntry('assets/credos-logo.png').Open()
        try { $stream.WriteByte(0) }
        finally { $stream.Dispose() }
    }
    finally { $archive.Dispose() }
    Expect-Failure { & $validator -Version $Version -Commit $Commit -NuGetDirectory $wrongBranding -BrandingDirectory $BrandingDirectory } 'Validator accepted branding that differs from the validated artifact.'
}
$wrongCommit = if ($Commit -eq ('a' * 40)) { 'b' * 40 } else { 'a' * 40 }
Expect-Failure { & $validator -Version $Version -Commit $wrongCommit -NuGetDirectory $packageDirectory } 'Validator accepted a different source commit.'
Expect-Failure { & $validator -Version '999.0.0' -Commit $Commit -NuGetDirectory $packageDirectory } 'Validator accepted a different version.'

$noSymbols = Copy-Packages 'missing-symbols'
# Delete only the fixture-owned copy, never the input package.
Remove-Item -LiteralPath (Join-Path $noSymbols "CredOS.$Version.snupkg")
Expect-Failure { & $validator -Version $Version -Commit $Commit -NuGetDirectory $noSymbols } 'Validator accepted missing symbols.'

$noAssembly = Copy-Packages 'missing-framework'
Remove-ArchiveEntry (Join-Path $noAssembly "CredOS.$Version.nupkg") 'lib/net9.0/CredOS.Core.dll'
Expect-Failure { & $validator -Version $Version -Commit $Commit -NuGetDirectory $noAssembly } 'Validator accepted a missing framework assembly.'

$noPdb = Copy-Packages 'missing-pdb'
Remove-ArchiveEntry (Join-Path $noPdb "CredOS.$Version.snupkg") 'lib/net8.0/CredOS.Core.pdb'
Expect-Failure { & $validator -Version $Version -Commit $Commit -NuGetDirectory $noPdb } 'Validator accepted a missing framework PDB.'

$noReadme = Copy-Packages 'missing-readme'
Remove-ArchiveEntry (Join-Path $noReadme "CredOS.$Version.nupkg") 'README.md'
Expect-Failure { & $validator -Version $Version -Commit $Commit -NuGetDirectory $noReadme } 'Validator accepted missing README documentation.'

$noIcon = Copy-Packages 'missing-icon'
Remove-ArchiveEntry (Join-Path $noIcon "CredOS.$Version.nupkg") 'assets/credos-icon.png'
Expect-Failure { & $validator -Version $Version -Commit $Commit -NuGetDirectory $noIcon } 'Validator accepted a missing package icon.'

foreach ($mismatch in @(
    @{ Property = 'version'; Value = '999.0.0' },
    @{ Property = 'id'; Value = 'CredOS.Core' }
)) {
    $wrongMetadata = Copy-Packages "wrong-$($mismatch.Property)"
    $archive = [System.IO.Compression.ZipFile]::Open((Join-Path $wrongMetadata "CredOS.$Version.nupkg"), [System.IO.Compression.ZipArchiveMode]::Update)
    try {
        $entry = $archive.GetEntry('CredOS.nuspec')
        $reader = [System.IO.StreamReader]::new($entry.Open())
        try { [xml] $metadata = $reader.ReadToEnd() }
        finally { $reader.Dispose() }
        $metadata.package.metadata.($mismatch.Property) = $mismatch.Value
        $entry.Delete()
        $writer = [System.IO.StreamWriter]::new($archive.CreateEntry('CredOS.nuspec').Open())
        try { $writer.Write($metadata.OuterXml) }
        finally { $writer.Dispose() }
    }
    finally { $archive.Dispose() }
    Expect-Failure { & $validator -Version $Version -Commit $Commit -NuGetDirectory $wrongMetadata } "Validator accepted mismatched nuspec $($mismatch.Property)."
}

# A private bare remote exercises publication boundaries without contacting GitHub.
$remote = Join-Path $fixture 'remote.git'
$checkout = Join-Path $fixture 'checkout'
git init --bare --quiet $remote
if ($LASTEXITCODE -ne 0) { throw 'Could not create the fixture remote.' }
git init --quiet --initial-branch main $checkout
if ($LASTEXITCODE -ne 0) { throw 'Could not create the fixture checkout.' }
Push-Location $checkout
try {
    git config user.name 'CredOS release fixture'
    git config user.email 'fixture@example.invalid'
    git config tag.gpgsign false
    git remote add origin $remote
    git -c commit.gpgsign=false commit --quiet --allow-empty -m 'feat: initial library'
    if ($LASTEXITCODE -ne 0) { throw 'Could not create the fixture commit.' }
    $fixtureCommit = git rev-parse HEAD
    & $reserveTag -Version '0.1.0' -Commit $fixtureCommit
    $remoteTag = @(git ls-remote origin 'refs/tags/v0.1.0^{}')
    if ($LASTEXITCODE -ne 0 -or !$remoteTag -or ($remoteTag[0] -split '\s+')[0] -ne $fixtureCommit) {
        throw 'Reserved tag does not identify the fixture commit.'
    }
    $script:checks++
    & $reserveTag -Version '0.1.0' -Commit $fixtureCommit
    $script:checks++
    git -c commit.gpgsign=false commit --quiet --allow-empty -m 'fix: another change'
    if ($LASTEXITCODE -ne 0) { throw 'Could not create the second fixture commit.' }
    $nextCommit = git rev-parse HEAD
    Expect-Failure { & $reserveTag -Version '0.1.0' -Commit $nextCommit } 'Tag reservation accepted a conflicting remote tag.'
    Expect-Failure { & $reserveTag -Version '0.2.0' -Commit $fixtureCommit } 'Tag reservation accepted an untested checkout.'
    Expect-Failure { & $reserveTag -Version '0.1.1' -Commit $nextCommit } 'Tag reservation accepted a nonzero patch version.'
}
finally { Pop-Location }
Write-Host "Passed $script:checks release-pipeline checks. Fixture retained at $fixture."
