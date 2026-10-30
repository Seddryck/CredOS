# Contributing to CredOS

Describe bugs with reproduction steps, expected and actual results, and the
affected version. Use natural-language issue titles and exactly one change-type
label: `bug`, `new-feature`, or `enhancement`.

Create a task branch from the latest `origin/main`. Use `fix/`, `feat/`,
`refactor/`, `perf/`, `docs/`, `test/`, or `chore/` according to the change.
Keep commits focused and use Conventional Commit messages, for example
`chore: initialize project infrastructure`.

Follow `.editorconfig`. Shared build settings belong in `Directory.Build.props`;
project files should contain only project-specific settings. Production code
lives under `src/CredOS.<Component>/`, with tests beside it in
`src/CredOS.<Component>.Testing/`.

Run focused tests first, followed by the relevant build. Report the exact commands
run and identify checks not run. Avoid full test suites unless requested or
necessary. Run contract tests before native tests. Follow the README for native
test isolation and the restore, build, and pack commands.

Submit pull requests against `main` with a Conventional Commit-style title, a
description of the behavior changed, and validation results. Link an associated
issue with `Closes #<number>`. Do not apply issue change-type labels to pull
requests unless requested.

Participation follows the [code of conduct](CODE_OF_CONDUCT.md).
