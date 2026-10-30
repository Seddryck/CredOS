namespace CredOS;

/// <summary>Stores one username/password pair per name in the current user's native store.</summary>
public interface ICredentialStore
{
    /// <summary>Checks presence synchronously without decoding the password.</summary>
    bool Exists(string name, CancellationToken cancellationToken = default);

    /// <summary>Reads synchronously, or throws <see cref="CredentialNotFoundException"/>.</summary>
    UsernamePasswordCredentials Read(string name, CancellationToken cancellationToken = default);

    /// <summary>Adds synchronously. Existing entries require an explicit <paramref name="replace"/>.</summary>
    void Add(string name, UsernamePasswordCredentials credentials, bool replace = false, CancellationToken cancellationToken = default);

    /// <summary>Removes synchronously. Removing an absent entry succeeds.</summary>
    void Remove(string name, CancellationToken cancellationToken = default);

    /// <summary>Checks presence without decoding the password. Unavailable stores raise an error.</summary>
    ValueTask<bool> ExistsAsync(string name, CancellationToken cancellationToken = default);

    /// <summary>Reads a pair, or throws with <see cref="CredentialNotFoundException"/>.</summary>
    ValueTask<UsernamePasswordCredentials> ReadAsync(string name, CancellationToken cancellationToken = default);

    /// <summary>Adds a pair. Existing entries require an explicit <paramref name="replace"/>.</summary>
    ValueTask AddAsync(string name, UsernamePasswordCredentials credentials, bool replace = false, CancellationToken cancellationToken = default);

    /// <summary>Removes an entry. Removing an absent entry succeeds.</summary>
    ValueTask RemoveAsync(string name, CancellationToken cancellationToken = default);
}

internal interface INativeCredentialStore
{
    bool Exists(string name, CancellationToken token);
    UsernamePasswordCredentials Read(string name, CancellationToken token);
    void Write(string name, UsernamePasswordCredentials credentials, CancellationToken token);
    void Remove(string name, CancellationToken token);
}
