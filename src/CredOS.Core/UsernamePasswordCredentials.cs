namespace CredOS;

/// <summary>A username and password. Diagnostic formatting never includes either value.</summary>
/// <remarks>Strings remain in managed memory until collected; this type does not promise secure erasure.</remarks>
public sealed class UsernamePasswordCredentials
{
    /// <summary>Creates credentials. Store operations validate portable length and character limits.</summary>
    public UsernamePasswordCredentials(string username, string password)
    {
        ArgumentNullException.ThrowIfNull(username);
        ArgumentNullException.ThrowIfNull(password);
        Username = username;
        Password = password;
    }

    /// <summary>The account name.</summary>
    public string Username { get; }
    /// <summary>The password, including any whitespace or embedded NUL characters.</summary>
    public string Password { get; }
    /// <inheritdoc/>
    public override string ToString() => "[Credentials redacted]";
}
