# CredOS

CredOS stores application-scoped username/password pairs in the current user's
native credential store. The `CredOS` NuGet package targets .NET 8, .NET 9, and .NET 10 and has
no CLI, configuration, or dependency-injection dependency.

```sh
dotnet add package CredOS
```

```csharp
using CredOS;

ICredentialStore store = new CredentialStore("my-application");
// Obtain these values from your application's input; do not log credentials.
await store.AddAsync("production", new UsernamePasswordCredentials(username, password));
if (await store.ExistsAsync("production"))
{
    var credentials = await store.ReadAsync("production");
    // Pass credentials.Username and credentials.Password to the service client.
}
await store.AddAsync("production", new(username, updatedPassword), replace: true);
await store.RemoveAsync("production");
```

## Public API

All types are in the `CredOS` namespace. See [the complete API contract](docs/api.md)
for naming, failure, persistence, concurrency, and cancellation semantics.

| Member | Behavior |
| --- | --- |
| `new CredentialStore(applicationName)` | Scopes all names to the application |
| `ExistsAsync(name, cancellationToken)` | Checks presence without decoding passwords; inaccessible stores raise errors |
| `ReadAsync(name, cancellationToken)` | Returns `UsernamePasswordCredentials`; missing entries raise `CredentialNotFoundException` |
| `AddAsync(name, credentials, replace: false, cancellationToken)` | Creates; duplicates raise `CredentialAlreadyExistsException`; `replace: true` creates or updates |
| `RemoveAsync(name, cancellationToken)` | Deletes; an absent entry succeeds |
| `CredentialName.Normalize(name)` | Validates a portable name and lowercases it |
| `CredentialStoreException` | Base class for missing-entry, duplicate-entry, unavailable-store, and unsupported-platform exceptions |

The synchronous API has matching `Exists`, `Read`, `Add`, and `Remove` methods,
with the same arguments, cancellation, replacement, and exception behavior:

```csharp
ICredentialStore store = new CredentialStore("my-application");
store.Add("production", new(username, password));
var credentials = store.Read("production");
store.Remove("production");
```

Catch a specific exception when handling a known failure, or catch
`CredentialStoreException` to handle all native-store failures.

## Operating systems

| OS | Backend | Requirements |
| --- | --- | --- |
| Windows | WinCred generic credentials | Current user's Credential Manager |
| macOS | Security.framework generic passwords | Accessible, unlocked default Keychain; authentication UI is disabled |
| Linux | libsecret / Secret Service | `libsecret-1.so.0`, GLib/GObject/GIO, a session D-Bus, and an unlocked default collection (e.g. GNOME Keyring) |

CredOS uses native APIs. It has no plaintext fallback and never puts passwords in
subprocess arguments. Missing dependencies, locked stores, denied access, and
malformed native data raise `CredentialStoreUnavailableException`, rather than reporting absence.
Application scoping prevents accidental collisions; it is not an authorization
boundary against other applications running as the same OS user.

## Development and tests

Install the .NET 10 SDK or newer and .NET 8/9/10 runtimes to run every target.

```powershell
dotnet restore CredOS.slnx
dotnet test src/CredOS.Core.Testing -c Release --no-restore --filter "TestCategory!=Native&TestCategory!=IsolatedLinux"
dotnet build CredOS.slnx -c Release --no-restore
dotnet pack CredOS.slnx -c Release --no-build --output .artifacts/nuget
```

Native tests write random fixture-owned entries and remove them in `finally`.
On Windows, run against the current user's store:

```powershell
$env:CREDOS_TEST_NATIVE = '1'
dotnet test src/CredOS.Core.Testing -c Release --no-build --no-restore --filter "TestCategory=Native"
```

On macOS, after the build, run `bash build/test-macos.sh`; it creates a temporary
keychain and restores the prior default and search list. On Linux, install
`dbus`, `gnome-keyring`, and `libsecret-1-0`, then run `bash build/test-linux.sh`.
That script creates a private D-Bus session and keyring data directories. It runs
lifecycle tests on all frameworks, then verifies locked-collection and missing-session
failures on .NET 10. Never set the isolated-session flags against a desktop keyring.

Linux tests can also run entirely in Docker:

```sh
docker build -f build/linux-tests.Dockerfile -t credos-linux-tests .
docker run --rm credos-linux-tests
```

CI calculates a version using GitVersion 6.6.0 and `GitVersion.yml`, then runs
contract and native lifecycle tests on Windows, macOS, and Linux on all three
frameworks. It builds and validates one versioned `CredOS` package with symbols.
Successful pushes to `main` publish those validated artifacts to NuGet. Versions
whose patch number is zero also receive a `v<version>` tag and GitHub release.
Pull requests and manual workflow runs validate packages without publishing.
See [the release process and required setup](docs/releases.md).

The commands above use a local development version of `0.0.0` and do not publish.
To build the same version as GitVersion calculates for the current branch:

```powershell
dotnet tool restore
$version = dotnet tool run dotnet-gitversion -- /nofetch /showvariable SemVer
dotnet pack src/CredOS.Core/CredOS.Core.csproj -c Release --include-symbols -p:Version=$version --output .artifacts/versioned
```

See [CONTRIBUTING.md](CONTRIBUTING.md), [AGENTS.md](AGENTS.md), and
[SECURITY.md](SECURITY.md) for repository guidance.

## License

[Apache License 2.0](LICENSE).
