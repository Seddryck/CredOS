---
name: dotnet-ci-release
description: Change CredOS .NET CI, NuGet packaging, or release workflows using the repository's declared frameworks and deliverables.
---

# CredOS .NET delivery

Adapted from Packata's delivery skill. Inspect `Directory.Build.props`,
`Directory.Build.targets`, `CredOS.slnx`, project files, `GitVersion.yml`, and
`.github/workflows/` before changing delivery behavior.

The initial deliverable is one portable managed library, `CredOS.Core`, targeting
`net8.0`, `net9.0`, and `net10.0`. Compile all three and pack them into one NuGet
package with ID `CredOS` and a matching symbol package. The assembly remains
`CredOS.Core`. NuGet publication and patch-zero GitHub
releases are configured in `ci.yml`; see `docs/releases.md`. No executable, RID
distribution or installer is established. The package embeds its logo and icon
from validated generated files in `.artifacts/branding/`; preserve their package
paths under `assets/`, metadata, and package validation. Source masks and color
mapping live in `assets/logo/`. Run `Build-Logo.ps1` before packing, with pinned
ImageMagick 7.1.2-29 Q16-HDRI. Branding is generated once in CI and consumed by
packaging and publication without rebuilding; patch-zero GitHub releases also
include the versioned branding ZIP. Preserve the zero-difference reference and
tracked-preview freshness checks. Do not introduce Packata's
CLI, VS Code, schema, website, or release matrices without corresponding CredOS
deliverables.

CI restores, builds, packs, and checks package contents on Linux. Contract and
native lifecycle tests run on Windows, macOS, and Linux on every target framework.
Keep corresponding runtimes installed and reuse built outputs. Linux store tests
use a private D-Bus session; macOS uses a temporary keychain. Preserve that isolation.
A portable library does not need a distribution RID matrix.

Before proposing release automation, state the evidence and decision for target
frameworks, test operating systems, package identities, versions, generated
inputs, release triggers, and publishing destinations. CI calculates one version
with GitVersion 6.6.0 and `GitVersion.yml`. Keep the local tool manifest aligned.
Local builds without a version override use the development version `0.0.0`.

For an authorized release workflow, calculate one version from full Git history,
build and validate immutable packages, then publish those same packages. Validate
the tested commit and release tag before publication. Keep publishing credentials
out of PR jobs. Do not add publication as a side effect of an ordinary CI change.

Validate workflow syntax with `actionlint` when available. Run changed commands
locally and inspect NuGet contents, including all framework assemblies, license
metadata, and README. Report exact checks run and any untested runner behavior.
