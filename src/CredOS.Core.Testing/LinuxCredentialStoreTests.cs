using System.Runtime.InteropServices;
using NUnit.Framework;

namespace CredOS.Core.Testing;

[Category("IsolatedLinux")]
public class LinuxCredentialStoreTests
{
    [Test]
    public async Task LockedCollectionPreservesPresenceAndRejectsSecretOperations()
    {
        if (!OperatingSystem.IsLinux() || Environment.GetEnvironmentVariable("CREDOS_TEST_ISOLATED_SECRET_SERVICE") != "1")
            Assert.Ignore("Only run through build/test-linux.sh in its private D-Bus session.");
        var store = new CredentialStore("credos-test-" + Guid.NewGuid().ToString("N"));
        await store.AddAsync("entry", new("alice", ""));
        LockPrivateCollection();
        // The private session and collection are destroyed by the runner after this test.
        Assert.That(await store.ExistsAsync("entry"), Is.True);
        var read = await Assert.ThrowsAsync<CredentialStoreUnavailableException>(async () => await store.ReadAsync("entry"));
        Assert.That(read, Is.TypeOf<CredentialStoreUnavailableException>());
        var write = await Assert.ThrowsAsync<CredentialStoreUnavailableException>(async () => await store.AddAsync("entry", new("bob", ""), replace: true));
        Assert.That(write, Is.TypeOf<CredentialStoreUnavailableException>());
        var remove = await Assert.ThrowsAsync<CredentialStoreUnavailableException>(async () => await store.RemoveAsync("entry"));
        Assert.That(remove, Is.TypeOf<CredentialStoreUnavailableException>());
    }

    [Test]
    public async Task MissingSessionIsAnErrorRatherThanAbsence()
    {
        if (!OperatingSystem.IsLinux() || Environment.GetEnvironmentVariable("CREDOS_TEST_MISSING_SESSION") != "1")
            Assert.Ignore("Only run through build/test-linux.sh with an absent D-Bus session.");
        var store = new CredentialStore("credos-test");
        var error = await Assert.ThrowsAsync<CredentialStoreUnavailableException>(async () => await store.ExistsAsync("absent"));
        Assert.That(error, Is.TypeOf<CredentialStoreUnavailableException>());
    }

    private static void LockPrivateCollection()
    {
        var service = secret_service_get_sync(0, IntPtr.Zero, out var error);
        Check(error);
        Assert.That(service, Is.Not.EqualTo(IntPtr.Zero));
        var collection = IntPtr.Zero;
        var list = IntPtr.Zero;
        var locked = IntPtr.Zero;
        try
        {
            collection = secret_collection_for_alias_sync(service, "default", 0, IntPtr.Zero, out error);
            Check(error);
            Assert.That(collection, Is.Not.EqualTo(IntPtr.Zero));
            list = g_list_append(IntPtr.Zero, collection);
            var count = secret_service_lock_sync(service, list, IntPtr.Zero, out locked, out error);
            Check(error);
            Assert.That(count, Is.GreaterThan(0));
        }
        finally
        {
            for (var node = locked; node != IntPtr.Zero; node = Marshal.ReadIntPtr(node, IntPtr.Size)) g_object_unref(Marshal.ReadIntPtr(node));
            if (locked != IntPtr.Zero) g_list_free(locked);
            if (list != IntPtr.Zero) g_list_free(list);
            if (collection != IntPtr.Zero) g_object_unref(collection);
            g_object_unref(service);
        }
    }

    private static void Check(IntPtr error)
    {
        if (error == IntPtr.Zero) return;
        g_error_free(error);
        Assert.Fail("Could not lock the isolated fixture's default collection.");
    }

    [DllImport("libsecret-1.so.0")] private static extern IntPtr secret_service_get_sync(int flags, IntPtr cancellable, out IntPtr error);
    [DllImport("libsecret-1.so.0")] private static extern IntPtr secret_collection_for_alias_sync(IntPtr service, [MarshalAs(UnmanagedType.LPUTF8Str)] string alias, int flags, IntPtr cancellable, out IntPtr error);
    [DllImport("libsecret-1.so.0")] private static extern int secret_service_lock_sync(IntPtr service, IntPtr objects, IntPtr cancellable, out IntPtr locked, out IntPtr error);
    [DllImport("libglib-2.0.so.0")] private static extern IntPtr g_list_append(IntPtr list, IntPtr value);
    [DllImport("libglib-2.0.so.0")] private static extern void g_list_free(IntPtr list);
    [DllImport("libglib-2.0.so.0")] private static extern void g_error_free(IntPtr error);
    [DllImport("libgobject-2.0.so.0")] private static extern void g_object_unref(IntPtr value);
}
