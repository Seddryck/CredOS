# CredOS

CredOS is in initial development. This repository currently provides the .NET
project foundation; application features and public APIs are not implemented yet.

The repository conventions and build infrastructure are adapted from
[Packata](https://github.com/Seddryck/Packata).

## Development

Install the .NET 10 SDK or newer. The library targets .NET 8, .NET 9, and .NET 10
and uses C# 14, nullable reference types, and implicit usings.

```powershell
dotnet restore CredOS.slnx
dotnet build CredOS.slnx --configuration Release --no-restore
dotnet pack CredOS.slnx --configuration Release --no-build --output .artifacts/nuget
```

These commands build every target framework and produce a local NuGet package.
The default development version is `0.0.0`; pass `-p:Version=0.1.0` to both build
and pack to override it. No package is published by these commands or by CI.

## Repository layout

| Path | Purpose |
| --- | --- |
| `src/CredOS.Core/` | Initial library project; no public API yet |
| `Directory.Build.props` | Shared frameworks, compiler settings, and package metadata |
| `Directory.Build.targets` | Friend assembly access for matching `.Testing` projects |
| `.github/workflows/ci.yml` | Restore, build, and package validation |
| `.github/skills/` | Repository workflows for .NET delivery and project development |
| `GitVersion.yml` | Packata-style version rules for future release automation |

Add test projects alongside the libraries under `src/`, using the
`CredOS.<Component>.Testing` naming convention. No test projects exist yet.
When adding them, wire focused tests into CI and install their target runtimes.

See [CONTRIBUTING.md](CONTRIBUTING.md) for contribution and validation guidance,
[AGENTS.md](AGENTS.md) for agent workflows, and [SECURITY.md](SECURITY.md) for
security reporting.

## License

CredOS is licensed under [Apache License 2.0](LICENSE).
