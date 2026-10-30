namespace CredOS;

/// <summary>A sanitized failure; backend messages and credentials are never attached.</summary>
public abstract class CredentialStoreException : Exception
{
    /// <summary>Initializes a store failure with a sanitized message.</summary>
    protected CredentialStoreException(string message) : base(message) { }
}

/// <summary>The requested entry does not exist in an accessible store.</summary>
public sealed class CredentialNotFoundException : CredentialStoreException
{
    /// <summary>Creates a missing-entry failure.</summary>
    public CredentialNotFoundException() : base("Credential not found.") { }
}

/// <summary>An add without replacement encountered an existing entry.</summary>
public sealed class CredentialAlreadyExistsException : CredentialStoreException
{
    /// <summary>Creates a duplicate-entry failure.</summary>
    public CredentialAlreadyExistsException() : base("Credential already exists. Enable replacement to update it.") { }
}

/// <summary>The store is missing, locked, denied, timed out, or contains malformed/ambiguous data.</summary>
public sealed class CredentialStoreUnavailableException : CredentialStoreException
{
    /// <summary>Creates an unavailable-store failure.</summary>
    public CredentialStoreUnavailableException()
        : base("OS credential store unavailable or access denied. Ensure the current user's store is installed and unlocked.") { }
}

/// <summary>The operating system has no supported credential backend.</summary>
public sealed class CredentialStoreUnsupportedPlatformException : CredentialStoreException
{
    /// <summary>Creates an unsupported-platform failure.</summary>
    public CredentialStoreUnsupportedPlatformException() : base("This operating system has no supported credential store.") { }
}
