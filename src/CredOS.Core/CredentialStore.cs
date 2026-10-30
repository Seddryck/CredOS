using System.Security.Cryptography;
using System.Text;

namespace CredOS;

/// <summary>Application-scoped native storage on Windows, macOS, and Linux. No file or process fallback.</summary>
public sealed class CredentialStore : ICredentialStore
{
    private readonly string applicationName;
    private readonly Func<INativeCredentialStore> backendFactory;

    /// <summary>Creates a store scoped by a portable application name. macOS authentication UI is disabled.</summary>
    public CredentialStore(string applicationName)
    {
        this.applicationName = CredentialName.Normalize(applicationName);
        backendFactory = CreateBackend;
    }

    internal CredentialStore(string applicationName, Func<INativeCredentialStore> backendFactory) : this(applicationName)
        => this.backendFactory = backendFactory;

    private INativeCredentialStore CreateBackend()
    {
        if (OperatingSystem.IsWindows()) return new WindowsCredentialStore(applicationName);
        if (OperatingSystem.IsMacOS()) return new MacCredentialStore(applicationName);
        if (OperatingSystem.IsLinux()) return new LinuxCredentialStore(applicationName);
        throw new CredentialStoreUnsupportedPlatformException();
    }

    /// <inheritdoc/>
    public bool Exists(string name, CancellationToken cancellationToken = default)
        => Execute(name, (backend, normalized) => backend.Exists(normalized, cancellationToken), cancellationToken);

    /// <inheritdoc/>
    public UsernamePasswordCredentials Read(string name, CancellationToken cancellationToken = default)
        => Execute(name, (backend, normalized) =>
        {
            var credentials = backend.Read(normalized, cancellationToken);
            ValidateCredentials(credentials);
            return credentials;
        }, cancellationToken);

    /// <inheritdoc/>
    public void Add(string name, UsernamePasswordCredentials credentials, bool replace = false, CancellationToken cancellationToken = default)
    {
        ValidateCredentials(credentials);
        Execute(name, (backend, normalized) =>
        {
            if (backend.Exists(normalized, cancellationToken) && !replace)
                throw new CredentialAlreadyExistsException();
            cancellationToken.ThrowIfCancellationRequested();
            backend.Write(normalized, credentials, cancellationToken);
            return true;
        }, cancellationToken);
    }

    internal static void ValidateCredentials(UsernamePasswordCredentials credentials)
    {
        ArgumentNullException.ThrowIfNull(credentials);
        if (string.IsNullOrWhiteSpace(credentials.Username) || credentials.Username.Length > 512
            || credentials.Username.Any(char.IsControl)
            || !IsValidUnicode(credentials.Username) || !IsValidUnicode(credentials.Password)
            || credentials.Password.Length > 1280)
            throw new ArgumentException("A valid Unicode username (1–512 UTF-16 code units, no controls) and password (0–1280 UTF-16 code units) are required.", nameof(credentials));
    }

    private static bool IsValidUnicode(string value)
    {
        for (var i = 0; i < value.Length; i++)
        {
            if (char.IsHighSurrogate(value[i]))
            {
                if (++i == value.Length || !char.IsLowSurrogate(value[i])) return false;
            }
            else if (char.IsLowSurrogate(value[i])) return false;
        }
        return true;
    }

    /// <inheritdoc/>
    public void Remove(string name, CancellationToken cancellationToken = default)
        => Execute(name, (backend, normalized) => { backend.Remove(normalized, cancellationToken); return true; }, cancellationToken);

    /// <inheritdoc/>
    public ValueTask<bool> ExistsAsync(string name, CancellationToken cancellationToken = default)
        => new(Task.Run(() => Exists(name, cancellationToken), cancellationToken));

    /// <inheritdoc/>
    public ValueTask<UsernamePasswordCredentials> ReadAsync(string name, CancellationToken cancellationToken = default)
        => new(Task.Run(() => Read(name, cancellationToken), cancellationToken));

    /// <inheritdoc/>
    public ValueTask AddAsync(string name, UsernamePasswordCredentials credentials, bool replace = false, CancellationToken cancellationToken = default)
        => new(Task.Run(() => Add(name, credentials, replace, cancellationToken), cancellationToken));

    /// <inheritdoc/>
    public ValueTask RemoveAsync(string name, CancellationToken cancellationToken = default)
        => new(Task.Run(() => Remove(name, cancellationToken), cancellationToken));

    private T Execute<T>(string name, Func<INativeCredentialStore, string, T> action, CancellationToken token)
    {
        var normalized = CredentialName.Normalize(name);
        try
        {
            var key = Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(
                Environment.GetFolderPath(Environment.SpecialFolder.UserProfile) + "/" + applicationName + "/" + normalized)));
            using var mutex = new Mutex(false, "CredOS.Credential." + key);
            var acquired = false;
            try
            {
                try
                {
                    // Unix cannot WaitAny on a named mutex and cancellation event.
                    do { token.ThrowIfCancellationRequested(); acquired = mutex.WaitOne(100); } while (!acquired);
                }
                catch (AbandonedMutexException) { acquired = true; }
                token.ThrowIfCancellationRequested();
                return action(backendFactory(), normalized);
            }
            finally { if (acquired) mutex.ReleaseMutex(); }
        }
        catch (OperationCanceledException) { throw; }
        catch (CredentialStoreException) { throw; }
        catch { throw new CredentialStoreUnavailableException(); }
    }
}
