// Modified for application-scoped storage and typed error handling.
using System.Runtime.InteropServices;
using System.Text;

namespace CredOS;

internal sealed class MacCredentialStore(string applicationName) : INativeCredentialStore
{
    private const string Security = "/System/Library/Frameworks/Security.framework/Security";
    private const string CoreFoundation = "/System/Library/Frameworks/CoreFoundation.framework/CoreFoundation";
    private const string ValueDataKey = "kSecValueData";
    private const int NotFound = -25300;
    private static readonly IntPtr SecurityLibrary = NativeLibrary.Load(Security);
    private static readonly IntPtr FoundationLibrary = NativeLibrary.Load(CoreFoundation);
    private static IntPtr Key(string name) => Marshal.ReadIntPtr(NativeLibrary.GetExport(SecurityLibrary, name));
    private static IntPtr True => Marshal.ReadIntPtr(NativeLibrary.GetExport(FoundationLibrary, "kCFBooleanTrue"));

    public bool Exists(string name, CancellationToken token)
    {
        using var query = Query(name);
        query.Set("kSecReturnAttributes", True);
        token.ThrowIfCancellationRequested();
        var status = SecItemCopyMatching(query.Handle, out var result);
        try { return CheckFound(status); }
        finally { if (result != IntPtr.Zero) CFRelease(result); }
    }

    public UsernamePasswordCredentials Read(string name, CancellationToken token)
    {
        using var query = Query(name);
        query.Set("kSecReturnAttributes", True);
        query.Set("kSecReturnData", True);
        token.ThrowIfCancellationRequested();
        var status = SecItemCopyMatching(query.Handle, out var result);
        try
        {
            if (!CheckFound(status)) throw new CredentialNotFoundException();
            var account = CFDictionaryGetValue(result, Key("kSecAttrAccount"));
            var data = CFDictionaryGetValue(result, Key(ValueDataKey));
            if (account == IntPtr.Zero || data == IntPtr.Zero) throw new CredentialStoreUnavailableException();
            var length = checked((int)CFDataGetLength(data));
            if (length > 5120) throw new CredentialStoreUnavailableException();
            var bytes = new byte[length];
            try
            {
                if (length > 0) Marshal.Copy(CFDataGetBytePtr(data), bytes, 0, length);
                return new(ReadString(account), new UTF8Encoding(false, true).GetString(bytes));
            }
            finally { Array.Clear(bytes); }
        }
        finally { if (result != IntPtr.Zero) CFRelease(result); }
    }

    public void Write(string name, UsernamePasswordCredentials credentials, CancellationToken token)
    {
        var storedUsername = credentials.Username ?? throw new CredentialStoreUnavailableException();
        var storedPassword = credentials.Password ?? throw new CredentialStoreUnavailableException();
        using var query = Query(name);
        using var values = new Dictionary();
        values.SetString("kSecAttrAccount", storedUsername);
        var bytes = Encoding.UTF8.GetBytes(storedPassword);
        try
        {
            // Legacy Keychain updates treat a NULL data pointer as "leave the password unchanged".
            // Empty immutable CFData can have that pointer; reserve capacity in mutable CFData
            // so an empty password still has a non-NULL backing buffer and a zero logical length.
            var data = bytes.Length == 0 ? CFDataCreateMutable(IntPtr.Zero, 1) : CFDataCreate(IntPtr.Zero, bytes, bytes.Length);
            if (data == IntPtr.Zero) throw new CredentialStoreUnavailableException();
            try { values.Set(ValueDataKey, data); }
            finally { CFRelease(data); }
            token.ThrowIfCancellationRequested();
            // Query by service only, so changing the username updates rather than duplicates the entry.
            var status = SecItemUpdate(query.Handle, values.Handle);
            if (status == NotFound)
            {
                query.SetString("kSecAttrAccount", storedUsername);
                query.Set(ValueDataKey, CFDictionaryGetValue(values.Handle, Key(ValueDataKey)));
                status = SecItemAdd(query.Handle, IntPtr.Zero);
            }
            if (status != 0) throw new CredentialStoreUnavailableException();
        }
        finally { Array.Clear(bytes); }
    }

    public void Remove(string name, CancellationToken token)
    {
        using var query = Query(name);
        token.ThrowIfCancellationRequested();
        _ = CheckFound(SecItemDelete(query.Handle));
    }

    private Dictionary Query(string name)
    {
        var query = new Dictionary();
        query.Set("kSecClass", Key("kSecClassGenericPassword"));
        query.SetString("kSecAttrService", applicationName + "/" + name);
        query.Set("kSecUseAuthenticationUI", Key("kSecUseAuthenticationUIFail"));
        return query;
    }

    private static bool CheckFound(int status) => status switch { 0 => true, NotFound => false, _ => throw new CredentialStoreUnavailableException() };

    private static string ReadString(IntPtr value)
    {
        var buffer = new byte[checked((int)CFStringGetMaximumSizeForEncoding(CFStringGetLength(value), 0x08000100) + 1)];
        if (!CFStringGetCString(value, buffer, buffer.Length, 0x08000100)) throw new CredentialStoreUnavailableException();
        return Encoding.UTF8.GetString(buffer, 0, Array.IndexOf(buffer, (byte)0));
    }

    private sealed class Dictionary : IDisposable
    {
        public IntPtr Handle { get; } = CFDictionaryCreateMutable(IntPtr.Zero, 0,
            NativeLibrary.GetExport(FoundationLibrary, "kCFTypeDictionaryKeyCallBacks"),
            NativeLibrary.GetExport(FoundationLibrary, "kCFTypeDictionaryValueCallBacks"));
        public void Set(string key, IntPtr value) => CFDictionarySetValue(Handle, Key(key), value);
        public void SetString(string key, string value)
        {
            var text = CFStringCreateWithCString(IntPtr.Zero, value, 0x08000100);
            if (text == IntPtr.Zero) throw new CredentialStoreUnavailableException();
            try { Set(key, text); }
            finally { CFRelease(text); }
        }
        public void Dispose() => CFRelease(Handle);
        [DllImport(CoreFoundation)] private static extern IntPtr CFDictionaryCreateMutable(IntPtr allocator, nint capacity, IntPtr keys, IntPtr values);
        [DllImport(CoreFoundation)] private static extern void CFDictionarySetValue(IntPtr dictionary, IntPtr key, IntPtr value);
        [DllImport(CoreFoundation)] private static extern IntPtr CFStringCreateWithCString(IntPtr allocator, [MarshalAs(UnmanagedType.LPUTF8Str)] string text, uint encoding);
    }

    [DllImport(Security)] private static extern int SecItemCopyMatching(IntPtr query, out IntPtr result);
    [DllImport(Security)] private static extern int SecItemAdd(IntPtr attributes, IntPtr result);
    [DllImport(Security)] private static extern int SecItemUpdate(IntPtr query, IntPtr attributes);
    [DllImport(Security)] private static extern int SecItemDelete(IntPtr query);
    [DllImport(CoreFoundation)] private static extern IntPtr CFDictionaryGetValue(IntPtr dictionary, IntPtr key);
    [DllImport(CoreFoundation)] private static extern nint CFStringGetLength(IntPtr text);
    [DllImport(CoreFoundation)] private static extern nint CFStringGetMaximumSizeForEncoding(nint length, uint encoding);
    [DllImport(CoreFoundation)] [return: MarshalAs(UnmanagedType.I1)] private static extern bool CFStringGetCString(IntPtr text, byte[] buffer, nint size, uint encoding);
    [DllImport(CoreFoundation)] private static extern IntPtr CFDataCreate(IntPtr allocator, byte[] bytes, nint length);
    [DllImport(CoreFoundation)] private static extern IntPtr CFDataCreateMutable(IntPtr allocator, nint capacity);
    [DllImport(CoreFoundation)] private static extern nint CFDataGetLength(IntPtr data);
    [DllImport(CoreFoundation)] private static extern IntPtr CFDataGetBytePtr(IntPtr data);
    [DllImport(CoreFoundation)] private static extern void CFRelease(IntPtr value);
}
