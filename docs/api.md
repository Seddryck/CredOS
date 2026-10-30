# CredOS API contract

Package: `CredOS`. Namespace: `CredOS`. Assembly: `CredOS.Core`.
Frameworks: `net8.0`, `net9.0`, `net10.0`.

```csharp
public interface ICredentialStore
{
    bool Exists(string name, CancellationToken cancellationToken = default);
    UsernamePasswordCredentials Read(string name, CancellationToken cancellationToken = default);
    void Add(string name, UsernamePasswordCredentials credentials,
        bool replace = false, CancellationToken cancellationToken = default);
    void Remove(string name, CancellationToken cancellationToken = default);
    ValueTask<bool> ExistsAsync(string name, CancellationToken cancellationToken = default);
    ValueTask<UsernamePasswordCredentials> ReadAsync(string name, CancellationToken cancellationToken = default);
    ValueTask AddAsync(string name, UsernamePasswordCredentials credentials,
        bool replace = false, CancellationToken cancellationToken = default);
    ValueTask RemoveAsync(string name, CancellationToken cancellationToken = default);
}

public sealed class CredentialStore : ICredentialStore
{
    public CredentialStore(string applicationName);
    // Implements all eight interface methods with the same signatures/defaults.
}

public sealed class UsernamePasswordCredentials
{
    public UsernamePasswordCredentials(string username, string password);
    public string Username { get; }
    public string Password { get; }
    public override string ToString(); // Always "[Credentials redacted]".
}

public static class CredentialName
{
    public static string Normalize(string name);
}

public abstract class CredentialStoreException : Exception
{
    protected CredentialStoreException(string message);
}
public sealed class CredentialNotFoundException : CredentialStoreException
{
    public CredentialNotFoundException();
}
public sealed class CredentialAlreadyExistsException : CredentialStoreException
{
    public CredentialAlreadyExistsException();
}
public sealed class CredentialStoreUnavailableException : CredentialStoreException
{
    public CredentialStoreUnavailableException();
}
public sealed class CredentialStoreUnsupportedPlatformException : CredentialStoreException
{
    public CredentialStoreUnsupportedPlatformException();
}
```

## Names and values

Application and credential names use the same grammar: 1–128 ASCII letters,
digits, dots, hyphens, or underscores, starting with a letter or digit.
Names are lowercased invariantly. Whitespace is rejected, not trimmed.
Null names raise `ArgumentNullException`; other invalid names raise `ArgumentException`.

An application/name pair identifies exactly one username/password pair. Updating
the username replaces that pair rather than creating a second account entry.

Usernames must contain non-whitespace content, no control characters, and at most
512 UTF-16 code units. Passwords may be empty and may contain whitespace, line
breaks, embedded NULs, or other controls; their maximum is 1280 UTF-16 code units.
Both strings must contain well-formed Unicode (no unpaired surrogates).
The value constructor rejects nulls; `AddAsync` validates portable limits before
accessing a native store. Malformed values read from a store raise `CredentialStoreUnavailableException`.

## Operations and failures

| Condition | Result |
| --- | --- |
| Presence in an accessible store | `Exists` / `ExistsAsync` returns `true` or `false` |
| Read / ReadAsync absent entry | `CredentialNotFoundException` |
| Add / AddAsync existing entry with default `replace: false` | `CredentialAlreadyExistsException`; existing pair is preserved |
| Add with `replace: true` | Creates or replaces |
| Remove / RemoveAsync absent entry | Success |
| Missing backend, locked store, access denial, timeout, ambiguous or malformed entry | `CredentialStoreUnavailableException` |
| OS other than Windows/macOS/Linux | `CredentialStoreUnsupportedPlatformException` on an operation |
| Invalid application/name/value | `ArgumentException` or its `ArgumentNullException` subtype |
| Cancellation observed | `OperationCanceledException` |

Backend error text and native exceptions are discarded: `CredentialStoreException`
contains no secret, entry name, application name, native message, or inner exception.
Do not log `Username` or `Password`; only `ToString()` is redacted. Strings remain
in managed memory until collected. Native temporary password buffers are cleared
where the backend grants ownership of those buffers.

`ExistsAsync` does not decode the password. Linux searches without unlock or
load-secret flags and can detect entries in a locked collection. Windows' metadata
enumeration API also returns native blobs; CredOS does not inspect or decode them.
macOS queries attributes without requesting password data. Access policies may
still deny a metadata query; that produces `CredentialStoreUnavailableException`.

## Native persistence

| OS | Identity and representation |
| --- | --- |
| Windows | Generic target `<application>/<name>`, username field, UTF-16 password blob, current-user local-machine persistence |
| macOS | Generic-password service `<application>/<name>`, account attribute, UTF-8 password data, default keychain |
| Linux | Default Secret Service collection; attributes `application=<application>` and `credential=<name>`; JSON containing `Username` and `Password` |

No store enumeration, arbitrary native-target reader, CLI, OAuth flow, database
integration, or file backend is part of this API. The application controls when
to request or cache returned credentials. Instances are reusable and need no disposal.

## Concurrency and cancellation

Synchronous methods execute native APIs directly on the calling thread. Async methods
run those same operations on the thread pool and return `ValueTask` results. Both APIs
have identical storage, validation, cancellation, and exception semantics.
Operations on the same application/name
are serialized using a named OS mutex derived from the user profile, application,
and name. Cooperating CredOS instances/processes therefore have one winner for
concurrent adds with `replace: false`. This does not coordinate with external credential tools.
There is no transaction across entries or coordination across machines.

Cancellation is checked before backend access, while waiting for the mutex, and
at native call boundaries. Linux additionally links a 30-second budget and the
caller token to a native `GCancellable`. Budget exhaustion raises `CredentialStoreUnavailableException`;
caller cancellation raises `OperationCanceledException`. Windows and macOS native
calls cannot be interrupted once in progress. Cancellation does not roll back a
completed write or remove; callers should query the resulting state if uncertain.
Linux never requests unlocking, and macOS authentication UI is disabled. Unlock
the user's store externally before retrying denied operations.
