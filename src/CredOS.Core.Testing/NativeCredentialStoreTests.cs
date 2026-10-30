using System.Security.Cryptography;
using NUnit.Framework;

namespace CredOS.Core.Testing;

[Category("Native")]
public class NativeCredentialStoreTests
{
    [SetUp]
    public void RequireNativeStore()
    {
        if (Environment.GetEnvironmentVariable("CREDOS_TEST_NATIVE") != "1")
            Assert.Ignore("Set CREDOS_TEST_NATIVE=1 with an unlocked native store. Tests only modify random fixture-owned entries.");
    }

    [Test]
    public async Task LifecyclePreservesPasswordAndIsolatesApplication()
    {
        var application = "credos-test-" + Guid.NewGuid().ToString("N");
        var store = new CredentialStore(application);
        var other = new CredentialStore(application + "-other");
        var secret = " \t" + Convert.ToBase64String(RandomNumberGenerator.GetBytes(24)) + "é\n\0尾😀 ";
        const string name = "entry";
        try
        {
            Assert.That(await store.ExistsAsync(name), Is.False);
            var missing = await Assert.ThrowsAsync<CredentialNotFoundException>(async () => await store.ReadAsync(name));
            Assert.That(missing, Is.TypeOf<CredentialNotFoundException>());
            await store.RemoveAsync(name);
            await store.AddAsync(name, new("alice尾😀", secret));
            Assert.That(await new CredentialStore(application.ToUpperInvariant()).ExistsAsync("ENTRY"), Is.True);
            var first = await store.ReadAsync(name);
            Assert.That(first.Username, Is.EqualTo("alice尾😀"));
            Assert.That(first.Password == secret, Is.True, "Password round trip failed.");
            var duplicate = await Assert.ThrowsAsync<CredentialAlreadyExistsException>(async () => await store.AddAsync(name, new("bob", "")));
            Assert.That(duplicate, Is.TypeOf<CredentialAlreadyExistsException>());
            Assert.That((await store.ReadAsync(name)).Password == secret, Is.True, "Duplicate add changed the password.");
            Assert.That(await other.ExistsAsync(name), Is.False);
            await other.AddAsync(name, new("other", ""));
            await store.AddAsync(name, new("bob", ""), replace: true);
            Assert.That((await store.ReadAsync(name)).Username, Is.EqualTo("bob"));
            Assert.That((await store.ReadAsync(name)).Password.Length, Is.Zero);
            Assert.That((await other.ReadAsync(name)).Username, Is.EqualTo("other"));
            await store.AddAsync(name, new(new string('u', 512), new string('p', 1280)), replace: true);
            Assert.That((await store.ReadAsync(name)).Password.Length, Is.EqualTo(1280));
            await store.RemoveAsync(name);
            await store.RemoveAsync(name);
            Assert.That(await store.ExistsAsync(name), Is.False);
        }
        finally
        {
            try { await store.RemoveAsync(name); }
            finally { await other.RemoveAsync(name); }
        }
    }

    [Test]
    public async Task SynchronousNativeLifecycleSharesDataWithAsyncApi()
    {
        ICredentialStore store = new CredentialStore("credos-test-" + Guid.NewGuid().ToString("N"));
        var secret = " \t" + Convert.ToBase64String(RandomNumberGenerator.GetBytes(24)) + "é\n\0尾😀 ";
        try
        {
            Assert.That(store.Exists("entry"), Is.False);
            Assert.Throws<CredentialNotFoundException>(() => store.Read("entry"));
            store.Add("Entry", new("first", secret));
            Assert.That(store.Exists("ENTRY"), Is.True);
            Assert.That((await store.ReadAsync("entry")).Password == secret, Is.True, "Sync write/async read failed.");
            Assert.Throws<CredentialAlreadyExistsException>(() => store.Add("entry", new("second", "")));
            store.Add("entry", new("second", ""), replace: true);
            Assert.That(store.Read("entry").Username, Is.EqualTo("second"));
            await store.AddAsync("entry", new("third", secret), replace: true);
            Assert.That(store.Read("entry").Password == secret, Is.True, "Async write/sync read failed.");
            store.Remove("entry");
            store.Remove("entry");
            Assert.That(await store.ExistsAsync("entry"), Is.False);
        }
        finally { store.Remove("entry"); }
    }

    [Test]
    public async Task ConcurrentNativeCreateHasOneWinner()
    {
        var application = "credos-test-" + Guid.NewGuid().ToString("N");
        var store = new CredentialStore(application);
        try
        {
            async Task<bool> Add()
            {
                try { await new CredentialStore(application).AddAsync("entry", new("user", "")); return true; }
                catch (CredentialAlreadyExistsException) { return false; }
            }
            var results = await Task.WhenAll(Add(), Add());
            Assert.That(results.Count(x => x), Is.EqualTo(1));
        }
        finally { await store.RemoveAsync("entry"); }
    }
}
