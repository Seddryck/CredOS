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
package. No executable, RID distribution, native dependency, generated icon,
installer, or publishing destination is established. Do not introduce Packata's
CLI, VS Code, schema, website, or release matrices without corresponding CredOS
deliverables.

CI currently restores, builds, packs, and checks package contents on Linux.
There are no test projects yet. When tests are added, run relevant tests on every
supported framework where behavior can differ; install the corresponding
runtimes and reuse built outputs. Add OS runners when implementation or dependency
evidence justifies them. A portable library does not need a distribution RID
matrix.

Before proposing release automation, state the evidence and decision for target
frameworks, test operating systems, package identities, versions, generated
inputs, release triggers, and publishing destinations. `GitVersion.yml` provides
future version rules; current CI uses the local development version `0.0.0`.

For an authorized release workflow, calculate one version from full Git history,
build and validate immutable packages, then publish those same packages. Validate
the tested commit and release tag before publication. Keep publishing credentials
out of PR jobs. Do not add publication as a side effect of an ordinary CI change.

Validate workflow syntax with `actionlint` when available. Run changed commands
locally and inspect NuGet contents, including all framework assemblies, license
metadata, and README. Report exact checks run and any untested runner behavior.
