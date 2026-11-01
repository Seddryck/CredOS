# Versioning and releases

CredOS follows Packata's GitVersion configuration and release cadence. The one
deliverable is the `CredOS` NuGet package, containing `net8.0`, `net9.0`, and `net10.0` assemblies
and XML API documentation. Each release also includes a matching `.snupkg` with
portable symbols for all three frameworks. There are no executable distributions
or installers. Packing requires generated branding assets.
The project and assembly remain named `CredOS.Core`; the explicit package ID is `CredOS`.
Artifacts are named `CredOS.<version>.nupkg` and `CredOS.<version>.snupkg`.
The package embeds the full README logo and a 128×128 symbol-only PNG icon.
`PackageIcon` references `assets/credos-icon.png`; CI checks its presence, dimensions,
size, and metadata reference.
Branding sources and their color mapping live under `assets/logo/`.
`Build-Logo.ps1` uses pinned ImageMagick 7.1.2-29 Q16-HDRI to reconstruct the approved
transparent logo exactly, then generate symbol-only icons and a branding ZIP.
See [the source layers and build instructions](../assets/logo/LAYER-COLORS.md).

## Version calculation

CI uses GitVersion **6.6.0**, installed by the same pinned GitTools action revision
as Packata (`v4.7.0`). `GitVersion.yml` is identical to Packata's configuration;
the local tool manifest pins the same tool version.

The version job checks out full Git history, including tags, calculates and
validates `SemVer`, and exposes it to every build and packaging job. No framework
or OS gets its own version. `feat:` commits request minor increments, while
`fix:`, `chore:`, `refactor:`, and the other configured prefixes request patches.
Breaking-change messages request major increments. `v` is the tag prefix.
Feature branches receive `beta.<branch>` prerelease labels.

The first feature merge using a `feat:` commit calculates `0.1.0` on `main`.
A history containing only initial/chore commits can calculate `0.0.1`. Versions
depend on the actual commits and tags; the pipeline does not hard-code `0.1.0`.
A local build without a version override remains `0.0.0`.

## Pipeline and release cadence

1. **Calculate version:** fetch full history and calculate one validated version.
2. **Build and test:** use that version on Windows, macOS, and Linux for .NET 8/9/10.
   Linux native tests use private Secret Service sessions; macOS uses a temporary keychain.
   In parallel, a Windows branding job installs a checksum-verified portable
   ImageMagick toolchain and generates the branding assets once. It checks exact
   RGBA reconstruction, tracked README/icon freshness, deterministic repeat builds,
   grayscale masks, and missing/modified source and artifact rejection. It uploads
   the validated images, hash manifest, and `credos-branding-<version>.zip`.
3. **Package and validate:** after every OS and branding validation succeeds, download
   those branding assets and build the portable library
   into one NuGet package and matching symbol package. Validate filenames, nuspec
   identity/version, repository commit, license, documentation, assemblies, and symbols.
   Package logo and icon bytes must match the validated branding artifact. The
   source masks and reference image are not packed. Negative package-validation
   cases and isolated tag-reservation tests also run here.
4. **Verify release identity:** only for pushes to `main`, refresh tags and recalculate
   the version for the tested commit. Fail if the checkout or version differs.
   For patch-zero versions, reserve `v<version>`; reuse an existing tag only if it
   identifies the tested commit, including when another process creates it concurrently.
5. **Publish NuGet:** on successful pushes to `main`, download and revalidate the
   exact package and branding artifacts, including hashes and branding ZIP contents.
   Exchange GitHub OIDC identity through `NuGet/login`,
   then push the package and symbols. Packages are not rebuilt during publication.
6. **Publish GitHub release:** for patch-zero versions only, after NuGet publication
   succeeds, create or update the release using `gh`, generated release notes, and
   the validated `.nupkg`/`.snupkg` assets and branding ZIP. The release uses the
   verified existing tag. No images or packages are rebuilt during publication.

For example, `0.1.0` gets a `v0.1.0` tag, NuGet publication, and a GitHub release.
`0.1.1` is published to NuGet without a GitHub release page or new tag, matching
Packata's policy. Pull requests and manual dispatches calculate, test, and package
without tagging or publishing. Main-branch runs are serialized and are not
automatically cancelled; obsolete PR runs can be cancelled.

## Required account setup

- Configure the GitHub **`release` environment** in `Seddryck/CredOS`, including
  any desired approval or branch rules. Publication jobs use this environment.
- Configure a NuGet trusted publishing policy for user **`Seddryck`**, owner
  **`Seddryck`**, repository **`CredOS`**, workflow **`ci.yml`**, environment **`release`**,
  covering **`CredOS`**. Package ownership/name availability must allow its first publication.
- Permit the workflow to create tags and GitHub releases. Write permissions are
  limited to the tag and GitHub-release jobs; only NuGet publication requests an OIDC token.

No long-lived publishing secret is stored in the repository. The short-lived
NuGet key is passed through the publication job's environment and never printed.
Account policies and environment approvals are configured outside this repository;
adding the workflow does not create a NuGet trusted publishing policy.

## Local validation

```powershell
dotnet tool restore
$version = dotnet tool run dotnet-gitversion -- /nofetch /showvariable SemVer
pwsh -File ./Build-Logo.ps1 -Version $version -CheckTrackedAssets
./.github/scripts/Test-BrandingPipeline.ps1 -Version $version -BrandingDirectory .artifacts/branding
dotnet pack src/CredOS.Core/CredOS.Core.csproj -c Release --include-symbols -p:Version=$version --output .artifacts/versioned
./.github/scripts/Test-ReleasePipeline.ps1 -Version $version -Commit (git rev-parse HEAD) -NuGetDirectory .artifacts/versioned -BrandingDirectory .artifacts/branding
actionlint .github/workflows/ci.yml
```

Use a fresh output directory so validation finds exactly one version of each
package. The release tests use fixture copies of packages and a private local
bare Git remote under `.artifacts/release-tests`; they never push tags to GitHub.
