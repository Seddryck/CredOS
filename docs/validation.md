# API validation — 2026-10-30

## NuGet package rename validation

The explicit package ID is now `CredOS`; the assembly remains `CredOS.Core`.
`dotnet pack` built all three frameworks and produced matching
`CredOS.0.1.0-beta.native-credentials.1.nupkg` and `.snupkg` files. The validator
confirmed `CredOS.nuspec`, package ID/version/commit, documentation, license,
and the `CredOS.Core` DLL/XML/PDB entries for .NET 8/9/10.

`Test-ReleasePipeline.ps1` passed **14 checks on Windows**, including rejection
of a nuspec that still uses the old package ID. `actionlint` and whitespace checks
passed. Commands:

```powershell
$version = dotnet tool run dotnet-gitversion -- /nofetch /showvariable SemVer
dotnet pack src/CredOS.Core/CredOS.Core.csproj -c Release --include-symbols --output .artifacts/package-rename -p:Version=$version -p:ContinuousIntegrationBuild=true
./.github/scripts/Test-ReleasePipeline.ps1 -Version $version -Commit (git rev-parse HEAD) -NuGetDirectory .artifacts/package-rename
actionlint .github/workflows/ci.yml
git diff --check
```

Runtime/native tests were not rerun locally for the package-ID-only change.
Their prior results are recorded below. No package was published during validation.

## Versioning and release validation

The release changes were validated separately from the native API changes:

- GitVersion **6.6.0** was installed into `.artifacts/tools` and restored through
  the checked-in local tool manifest. The worktree calculated
  `0.1.0-beta.native-credentials.1`.
- The GitVersion configuration was compared with Packata's and is identical.
- Six private Git-history scenarios passed: initial chore history `0.0.1`, feature
  branch `0.1.0-beta.api.1`, feature merge `0.1.0`, tagged commit `0.1.0`, subsequent
  fix `0.1.1`, and subsequent feature `0.2.0`. These fixtures never contacted GitHub.
- The versioned library and symbols were packed for every target framework with
  `ContinuousIntegrationBuild=true` and checked for version, identity, source commit,
  documentation, license, DLL/XML files, and portable PDBs.
- `Test-ReleasePipeline.ps1` passed **13 checks on both Windows and Linux PowerShell**: valid packages, wrong commit,
  wrong expected version, missing symbols, missing framework assembly, missing PDB,
  missing README, incorrect nuspec version, new local-remote tag, same-commit tag reuse,
  conflicting tag rejection, checkout mismatch rejection, and patch-nonzero tag rejection.
- All **22 contract tests on .NET 10** passed when built with the calculated version.
- Workflow lint (`actionlint`) and `git diff --check` passed.

Focused commands for these changes:

```powershell
dotnet tool restore
dotnet tool run dotnet-gitversion -- /nofetch /showvariable SemVer
./.artifacts/Test-GitVersionConfig.ps1
$version = dotnet tool run dotnet-gitversion -- /nofetch /showvariable SemVer
dotnet test src/CredOS.Core.Testing -c Release -f net10.0 --no-restore --filter "TestCategory!=Native&TestCategory!=IsolatedLinux" -p:Version=$version
dotnet pack src/CredOS.Core/CredOS.Core.csproj -c Release --no-restore --include-symbols --output .artifacts/release-validation/packages -p:Version=$version -p:ContinuousIntegrationBuild=true
./.github/scripts/Test-ReleasePipeline.ps1 -Version $version -Commit (git rev-parse HEAD) -NuGetDirectory .artifacts/release-validation/packages
docker run --rm --mount type=bind,source=D:/users/seddr/Projects/CredOS/.worktrees/native-credentials,target=/source,readonly --entrypoint pwsh credos-linux-tests -NoProfile -File /source/.artifacts/Test-ReleaseOnLinux.ps1 -Commit (git rev-parse HEAD)
```

The Git-history script is a retained local fixture under ignored `.artifacts`;
the package and tag guard checks are repository workflow scripts and run in CI.
No GitHub-hosted workflow, actual release tag, NuGet publication, OIDC exchange,
GitHub release creation, or account-policy change was executed. Native tests and
.NET 8/9 contract tests were not rerun for the CI-only changes; their preceding
API-validation results are below. Windows restore still reported NU1900 for the
unavailable NuGet vulnerability-data endpoint.

## Executed successfully

| Host | Frameworks | Tests |
| --- | --- | --- |
| Windows | .NET 8, 9, 10 | All 22 contract cases plus async lifecycle, synchronous lifecycle/interoperability, and concurrent native creation: 25 passed per framework |
| Linux Docker (Ubuntu, GNOME Keyring/libsecret) | .NET 8, 9, 10 | All 22 contract cases and all three native lifecycle/concurrency cases: 25 passed per framework |
| Linux Docker, private D-Bus session | .NET 10 | `LockedCollectionPreservesPresenceAndRejectsSecretOperations`: passed |
| Linux Docker, absent D-Bus session | .NET 10 | `MissingSessionIsAnErrorRatherThanAbsence`: passed |

The contract cases cover name grammar/case/length, duplicate preservation,
replacement, username changes, idempotent deletion, concurrency across instances,
pre-cancellation for every synchronous/asynchronous operation, caller-thread execution,
specific exception preservation through the base type, credential limits/Unicode, and sanitized
exceptions/credential formatting. Native lifecycle cases additionally verify
application isolation, exact password round trips including embedded NULs and
Unicode, empty passwords, maximum lengths, and missing-entry errors.

Commands (from the task worktree):

```powershell
# Focused contract run, followed by all supported Windows targets.
dotnet test src/CredOS.Core.Testing -c Release -f net10.0 --filter "TestCategory!=Native&TestCategory!=IsolatedLinux" --no-restore --verbosity minimal
$env:CREDOS_TEST_NATIVE = '1'
dotnet test src/CredOS.Core.Testing -c Release --no-restore --filter "TestCategory!=IsolatedLinux" --verbosity minimal
dotnet build CredOS.slnx -c Release --no-restore --verbosity quiet
dotnet pack CredOS.slnx -c Release --no-build --output .artifacts/nuget --verbosity minimal
actionlint .github/workflows/ci.yml
git diff --check
docker build -f build/linux-tests.Dockerfile -t credos-linux-tests .
docker run --rm credos-linux-tests
docker run --rm credos-linux-tests dotnet test src/CredOS.Core.Testing -c Release --no-build --no-restore --filter "TestCategory!=Native&TestCategory!=IsolatedLinux"
```

The initial NuGet archive (before the package rename) was inspected with
`System.IO.Compression.ZipFile`: exactly one `CredOS.Core` package, DLL and XML documentation for every framework,
README, `docs/api.md`, and Apache-2.0 license metadata.
`actionlint` and `git diff --check` passed.

Windows used the installed .NET 11 preview SDK to compile C# 14, with the actual
.NET 8/9/10 runtimes for tests. Windows restore/build reported NU1900 because the
NuGet vulnerability-data endpoint was unavailable. The Linux image used .NET 10
SDK, restored successfully, and built all targets without warnings.

The first native Windows run exposed a username boundary error:
a 513-code-unit username was accepted by validation but rejected by WinCred.
The portable maximum is now 512, and the corrected native boundary tests pass.

## Not executed

- macOS native/contract tests: no macOS host is available here. CI includes all
  three frameworks and a temporary keychain with default/search-list restoration.
- Linux locked-collection and missing-session tests on .NET 8/9: those failure
  scenarios currently run on .NET 10 only; lifecycle tests cover every framework.
- GitHub-hosted CI itself: the workflow was linted locally but not dispatched.
- Publication and consumer integration.

Native tests touched only random fixture-owned entries. Windows entries were
removed in `finally`; Linux sessions/keyring directories were disposable.
