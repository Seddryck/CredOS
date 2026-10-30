[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidatePattern('^\d+\.\d+\.0$')]
    [string] $Version,

    [Parameter(Mandatory)]
    [ValidatePattern('^[0-9a-fA-F]{40}$')]
    [string] $Commit,

    [string] $Remote = 'origin'
)

$ErrorActionPreference = 'Stop'
$tag = "v$Version"
$headCommit = git rev-parse HEAD
if ($LASTEXITCODE -ne 0 -or $headCommit -ne $Commit) {
    throw 'The checkout does not identify the tested commit.'
}

function Get-RemoteTagCommit {
    $references = @(git ls-remote --tags $Remote "refs/tags/$tag" "refs/tags/$tag^{}")
    if ($LASTEXITCODE -ne 0) { throw 'Could not read remote release tags.' }
    $peeled = @($references | Where-Object { $_.EndsWith("refs/tags/$tag^{}", [StringComparison]::Ordinal) })
    if ($peeled.Count -gt 0) { return ($peeled[0] -split '\s+')[0] }
    if ($references.Count -gt 0) { return ($references[0] -split '\s+')[0] }
    return $null
}

$remoteCommit = Get-RemoteTagCommit
if ($remoteCommit) {
    if ($remoteCommit -ne $Commit) { throw "Tag '$tag' already identifies a different commit." }
    Write-Host "Reusing '$tag' for the tested commit."
    return
}

# Reject an unexpected local tag before attempting publication.
$localTag = git rev-parse --verify --quiet "refs/tags/$tag"
if ($LASTEXITCODE -eq 0) {
    $localCommit = git rev-list -n 1 $tag
    if ($LASTEXITCODE -ne 0 -or $localCommit -ne $Commit) { throw "Local tag '$tag' identifies a different commit." }
}
else {
    git tag --annotate $tag --message "CredOS $Version" $Commit
    if ($LASTEXITCODE -ne 0) { throw 'Could not create the release tag.' }
}
git push $Remote "refs/tags/$tag"
if ($LASTEXITCODE -ne 0 -and (Get-RemoteTagCommit) -ne $Commit) {
    throw 'Could not reserve the release tag for the tested commit.'
}
Write-Host "Reserved '$tag' for the tested commit."
