namespace CredOS;

/// <summary>Portable, case-insensitive application and credential names.</summary>
public static class CredentialName
{
    /// <summary>Validates 1–128 ASCII letters/digits/dots/hyphens/underscores, starting with a letter/digit, and lowercases.</summary>
    public static string Normalize(string name)
    {
        ArgumentNullException.ThrowIfNull(name);
        if (name.Length is 0 or > 128 || !char.IsAsciiLetterOrDigit(name[0])
            || name.Any(c => !char.IsAsciiLetterOrDigit(c) && c is not '-' and not '_' and not '.'))
            throw new ArgumentException("Names must contain 1–128 ASCII letters, digits, dots, hyphens or underscores, starting with a letter or digit.", nameof(name));
        return name.ToLowerInvariant();
    }
}
