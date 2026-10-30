# Changelog

## Unreleased

- Add the CredOS logo to the README and a symbol-only NuGet package icon.

- Publish the library under the NuGet package ID `CredOS`, with matching CI validation and release artifacts.

- Calculate CI package versions with GitVersion and adopt the Packata-style NuGet and patch-zero GitHub release process.

- Implement Windows Credential Manager, macOS Keychain, and Linux libsecret stores in `CredOS.Core`.
- Define application-scoped credentials, specific credential-store exceptions, and matching synchronous/asynchronous APIs.
- Add contract and native tests on Windows, macOS, and Linux across .NET 8/9/10.

- Initialize the CredOS .NET solution and repository infrastructure using Packata
  conventions.
