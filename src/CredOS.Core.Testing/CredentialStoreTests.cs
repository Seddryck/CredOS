using NUnit.Framework;

namespace CredOS.Core.Testing;

public class CredentialStoreTests
{
    [TestCase("Alice.Prod_1-x", "alice.prod_1-x")]
    [TestCase("0", "0")]
    public void NormalizesPortableNames(string name, string expected)
        => Assert.That(CredentialName.Normalize(name), Is.EqualTo(expected));

    [TestCase("")]
    [TestCase(" leading")]
    [TestCase("a/b")]
    [TestCase("a\0b")]
    [TestCase("é")]
    [TestCase("-a")]
    public void RejectsInvalidNames(string name)
    {
        Assert.Throws<ArgumentException>(() => CredentialName.Normalize(name));
        Assert.Throws<ArgumentException>(() => new CredentialStore(name));
    }

    [Test]
    public void NameLengthBoundary()
    {
        Assert.That(CredentialName.Normalize(new string('a', 128)).Length, Is.EqualTo(128));
        Assert.Throws<ArgumentException>(() => CredentialName.Normalize(new string('a', 129)));
        Assert.Throws<ArgumentNullException>(() => CredentialName.Normalize(null!));
    }

    [Test]
    public async Task DuplicateDoesNotWriteAndReplacementUpdatesUsername()
    {
        var backend = new MemoryBackend();
        var store = new CredentialStore("test", () => backend);
        await store.AddAsync("Entry", new("first", ""));
        var error = await Assert.ThrowsAsync<CredentialAlreadyExistsException>(async () => await store.AddAsync("ENTRY", new("second", "")));
        Assert.That(error, Is.TypeOf<CredentialAlreadyExistsException>());
        Assert.That(backend.Writes, Is.EqualTo(1));
        await store.AddAsync("ENTRY", new("second", ""), replace: true);
        Assert.That((await store.ReadAsync("entry")).Username, Is.EqualTo("second"));
        Assert.That(backend.LastName, Is.EqualTo("entry"));
        await store.RemoveAsync("entry");
        await store.RemoveAsync("entry");
        Assert.That(await store.ExistsAsync("entry"), Is.False);
    }

    [Test]
    public async Task ConcurrentCreationAcrossInstancesHasOneWinner()
    {
        var backend = new MemoryBackend();
        var application = "test-" + Guid.NewGuid().ToString("N");
        async Task<bool> Add()
        {
            try { await new CredentialStore(application, () => backend).AddAsync("entry", new("user", "")); return true; }
            catch (CredentialAlreadyExistsException) { return false; }
        }
        var results = await Task.WhenAll(Enumerable.Range(0, 8).Select(_ => Add()));
        Assert.That(results.Count(x => x), Is.EqualTo(1));
        Assert.That(backend.Writes, Is.EqualTo(1));
    }

    [Test]
    public async Task PrecancelledOperationsNeverCreateBackend()
    {
        var calls = 0;
        var store = new CredentialStore("test", () => { calls++; return new MemoryBackend(); });
        using var source = new CancellationTokenSource();
        source.Cancel();
        await Assert.CatchAsync<OperationCanceledException>(async () => await store.ExistsAsync("entry", source.Token));
        await Assert.CatchAsync<OperationCanceledException>(async () => await store.ReadAsync("entry", source.Token));
        await Assert.CatchAsync<OperationCanceledException>(async () => await store.AddAsync("entry", new("user", ""), cancellationToken: source.Token));
        await Assert.CatchAsync<OperationCanceledException>(async () => await store.RemoveAsync("entry", source.Token));
        Assert.That(calls, Is.Zero);
    }

    [Test]
    public async Task InvalidCredentialsNeverReachBackend()
    {
        var calls = 0;
        var store = new CredentialStore("test", () => { calls++; return new MemoryBackend(); });
        foreach (var pair in new[] { new UsernamePasswordCredentials(" ", ""), new("a\0b", ""), new(new string('u', 513), ""), new("u", new string('p', 1281)), new("u", "\ud800"), new("\udc00", "") })
            await Assert.ThrowsAsync<ArgumentException>(async () => await store.AddAsync("entry", pair));
        await Assert.ThrowsAsync<ArgumentNullException>(async () => await store.AddAsync("entry", null!));
        Assert.That(calls, Is.Zero);
    }

    [Test]
    public void PortableCredentialBoundaries()
    {
        Assert.DoesNotThrow(() => CredentialStore.ValidateCredentials(new(new string('u', 512), new string('p', 1280))));
        Assert.DoesNotThrow(() => CredentialStore.ValidateCredentials(new("尾é😀", " \t\n\0尾😀 ")));
    }

    [Test]
    public async Task NativeFailuresAreSanitized()
    {
        var marker = Guid.NewGuid().ToString("N");
        var store = new CredentialStore("test", () => throw new InvalidOperationException(marker));
        var error = await Assert.ThrowsAsync<CredentialStoreUnavailableException>(async () => await store.ReadAsync("entry"));
        Assert.That(error, Is.TypeOf<CredentialStoreUnavailableException>());
        Assert.That(error!.InnerException, Is.Null);
        Assert.That(error!.ToString().Contains(marker, StringComparison.Ordinal), Is.False);
        Assert.That(new UsernamePasswordCredentials(marker, marker).ToString().Contains(marker, StringComparison.Ordinal), Is.False);
    }

    [Test]
    public async Task SynchronousLifecycleSharesDataWithAsyncApiAndRunsOnCallerThread()
    {
        var thread = Environment.CurrentManagedThreadId;
        var backend = new MemoryBackend();
        ICredentialStore store = new CredentialStore("sync-test", () =>
        {
            Assert.That(Environment.CurrentManagedThreadId, Is.EqualTo(thread));
            return backend;
        });
        Assert.That(store.Exists("Entry"), Is.False);
        Assert.Throws<CredentialNotFoundException>(() => store.Read("entry"));
        store.Add("ENTRY", new("first", ""));
        Assert.Throws<CredentialAlreadyExistsException>(() => store.Add("entry", new("second", "")));
        Assert.That(store.Read("entry").Username, Is.EqualTo("first"));
        store.Add("entry", new("second", ""), replace: true);
        // Async calls use a second instance without the caller-thread assertion.
        var asyncStore = new CredentialStore("sync-test", () => backend);
        Assert.That((await asyncStore.ReadAsync("entry")).Username, Is.EqualTo("second"));
        await asyncStore.AddAsync("entry", new("third", ""), replace: true);
        // The continuation can move threads; establish its current identity before more sync calls.
        thread = Environment.CurrentManagedThreadId;
        Assert.That(store.Read("entry").Username, Is.EqualTo("third"));
        store.Remove("entry");
        store.Remove("entry");
        Assert.That(store.Exists("entry"), Is.False);
    }

    [Test]
    public void SynchronousCancellationNeverCreatesBackend()
    {
        var calls = 0;
        var store = new CredentialStore("sync-test", () => { calls++; return new MemoryBackend(); });
        using var source = new CancellationTokenSource();
        source.Cancel();
        Assert.Catch<OperationCanceledException>(() => store.Exists("entry", source.Token));
        Assert.Catch<OperationCanceledException>(() => store.Read("entry", source.Token));
        Assert.Catch<OperationCanceledException>(() => store.Add("entry", new("user", ""), cancellationToken: source.Token));
        Assert.Catch<OperationCanceledException>(() => store.Remove("entry", source.Token));
        Assert.That(calls, Is.Zero);
    }

    [Test]
    public void SynchronousInvalidArgumentsNeverCreateBackend()
    {
        var calls = 0;
        var store = new CredentialStore("sync-test", () => { calls++; return new MemoryBackend(); });
        Assert.Throws<ArgumentException>(() => store.Exists("invalid/name"));
        Assert.Throws<ArgumentException>(() => store.Read("invalid/name"));
        Assert.Throws<ArgumentException>(() => store.Remove("invalid/name"));
        Assert.Throws<ArgumentException>(() => store.Add("entry", new(" ", "")));
        Assert.Throws<ArgumentNullException>(() => store.Add("entry", null!));
        Assert.That(calls, Is.Zero);
    }

    [TestCase(typeof(CredentialNotFoundException))]
    [TestCase(typeof(CredentialAlreadyExistsException))]
    [TestCase(typeof(CredentialStoreUnavailableException))]
    [TestCase(typeof(CredentialStoreUnsupportedPlatformException))]
    public async Task SpecificFailuresCanBeCaughtThroughBaseClassAndArePreserved(Type type)
    {
        var failure = (CredentialStoreException)Activator.CreateInstance(type)!;
        var store = new CredentialStore("typed-errors", () => throw failure);
        var sync = Assert.Catch<CredentialStoreException>(() => store.Read("entry"));
        var asyncFailure = await Assert.CatchAsync<CredentialStoreException>(async () => await store.ReadAsync("entry"));
        Assert.That(sync, Is.SameAs(failure));
        Assert.That(asyncFailure, Is.SameAs(failure));
    }

    private sealed class MemoryBackend : INativeCredentialStore
    {
        private UsernamePasswordCredentials? entry;
        public int Writes { get; private set; }
        public string? LastName { get; private set; }
        public bool Exists(string name, CancellationToken token) => entry is not null;
        public UsernamePasswordCredentials Read(string name, CancellationToken token) { LastName = name; return entry ?? throw new CredentialNotFoundException(); }
        public void Write(string name, UsernamePasswordCredentials credentials, CancellationToken token) { Writes++; entry = credentials; }
        public void Remove(string name, CancellationToken token) => entry = null;
    }
}
