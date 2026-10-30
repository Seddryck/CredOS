# CredOS agent instructions

## Repository workflows

Read matching workflows under `.github/skills/` before changing the build or
project structure. CredOS is a native credential library; do not infer application
features from Packata or copy its product-specific assets and publishing jobs.

## Branches and worktrees

Use a dedicated task branch and worktree for coding tasks, starting from the
latest `origin/main`. Branch prefixes describe the change: `fix/`, `feat/`,
`refactor/`, `perf/`, `docs/`, `test/`, or `chore/`.

For repositories under `D:\users\seddr\Projects`, create worktrees manually with
`git worktree add` under `<repository-root>/.worktrees/<task-name>`. Keep
`.worktrees/` excluded in `.git/info/exclude`, never the shared `.gitignore`.
Do not use Codex-managed worktrees under `C:\Users\seddr\.codex\worktrees`.

## Validation

Run focused tests first. Avoid expensive full suites unless requested or clearly
necessary. Report exactly which tests and build/package checks ran and which did
not. Contract tests are in `src/CredOS.Core.Testing`; native tests are opt-in.
Use the isolated Linux/macOS scripts described in README.md for those stores.

## Issues and pull requests

Use descriptive natural-language issue titles, with exactly one of `bug`,
`new-feature`, or `enhancement`. Use Conventional Commits for commits and PR
titles. Target `main` and link related issues using `Closes #<number>`.
Do not put issue change-type labels on PRs unless requested.

Use `gh` for all GitHub issue and PR operations. First run
`gh auth status -h github.com`. If sandboxed authentication fails while the user
is authenticated on the host, retry with elevated host permission to access the
existing Windows keyring. Do not run a new login or extract tokens.
Do not use GitHub's browser interface for these operations unless explicitly
authorized. Creating these instructions does not itself authorize publishing,
pushing, or creating issues or pull requests.

## Safety

Ask before modifying machine-wide configuration. Never put credentials or secrets
in the repository or command output.
