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

CredOS uses NUnit in `CredOS.Core.Testing`. Add tests for new observable behavior.
Native tests are opt-in and use random fixture-owned entries. Use the private
Linux session and temporary macOS keychain scripts for native validation.
Keep CI tests and installed runtimes aligned with the supported frameworks.

Run focused tests first, then build affected frameworks. If package structure or
metadata changes, pack and inspect the resulting archive. Update the README when
project layout or development commands change, and report exact validation.
