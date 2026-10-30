---
name: dotnet-project
description: Add or restructure CredOS library and test projects while preserving shared build settings and package boundaries.
---

# CredOS project development

Read `AGENTS.md`, `CONTRIBUTING.md`, and shared build properties before adding
projects. Keep libraries under `src/CredOS.<Component>/` and matching tests under
`src/CredOS.<Component>.Testing/`. Register projects in `CredOS.slnx`.

Frameworks, C# version, nullable settings, package metadata, and the packed README
are inherited from `Directory.Build.props`. Use project-level overrides only when
the component requires them. Shared asset paths must use
`$(MSBuildThisFileDirectory)` so project nesting does not break packing.

`Directory.Build.targets` grants internals access to the matching `.Testing`
assembly by default. Set explicit `InternalsVisibleTo` or
`InternalsVisibleToSuffix` items when another assembly genuinely needs access.
Projects ending in `Testing` are excluded from NuGet packing. Mark other
non-library projects non-packable explicitly.

CredOS currently has no application behavior or test framework. Add tests for
new observable behavior and select dependencies based on the actual need; avoid
creating placeholder tests for empty scaffolding. Update CI when introducing the
first test project so tests execute and every required runtime is installed.

Run focused tests first, then build affected frameworks. If package structure or
metadata changes, pack and inspect the resulting archive. Update the README when
project layout or development commands change, and report exact validation.
