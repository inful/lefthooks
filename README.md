# inful/lefthooks

Centralized [lefthook](https://lefthook.dev/) configuration for
[`github.com/inful/*`](https://github.com/inful) repositories.

This repo is the source of truth. Consumer repos import it via lefthook's
[`remotes:`](https://lefthook.dev/configuration/remotes/) mechanism and
inherit exactly the hooks that apply to their project shape.

## Design

The master [`lefthook.yml`](./lefthook.yml) defines the **full** set of
hooks used across our repos. **Every hook self-gates** — it only fires
when its preconditions are met:

| Gate | Mechanism | What it does |
|------|-----------|--------------|
| **File type** | `glob:` on each command | If no staged files match the pattern, lefthook auto-skips the command. |
| **Project shape** | `skip:` with shell conditions | E.g. Go hooks skip when there's no `go.mod`; `sqlc-check` skips when there's no `sqlc.yaml`; any tool-not-installed hook skips silently. |

Result: any consumer repo that imports this config picks up exactly the
hooks that apply to it, with **no per-repo overrides required**. A repo
with only Markdown files gets markdownlint; a Go repo gets the Go suite;
a Go repo with sqlc.yaml additionally gets the sqlc drift check.

## Hook inventory

| Hook | Stage | Precondition | Action |
|------|-------|--------------|--------|
| `gofmt` | pre-commit | `*.go` staged, `gofmt` installed, `go.mod` present | Check formatting; auto-stage fixes |
| `govet` | pre-commit | `*.go` staged, `go` installed, `go.mod` present | Run `go vet ./...` |
| `golangci-lint` | pre-commit | `*.go` staged, `golangci-lint` installed | Run lint suite |
| `go-test` | pre-commit | `*.go` staged, `go` installed, `go.mod` present | Run short race tests |
| `markdownlint` | pre-commit | `*.md` staged, `markdownlint` installed | Lint markdown |
| `sqlc-check` | pre-commit | `*.sql` staged, `sqlc` installed, `sqlc.yaml` present | Verify generated code is up to date |
| `docbuilder-lint` | pre-commit | `*.md` / image assets staged, docbuilder binary on PATH OR local `cmd/docbuilder` fallback in `go.mod` | Lint staged documentation tree via `docbuilder lint` |
| `check-conventional-commit.sh` | commit-msg | always | Validate Conventional Commits format |
| `go-test-race` | pre-push | `go` installed, `go.mod` present | Run full race tests |
| `golangci-lint` | pre-push | `go` installed, `go.mod` present | Lint with longer timeout |

## Adding a consumer repo

### Quick path — `bin/install-into.sh`

```sh
# From this repo's root
bin/install-into.sh /path/to/infra/repo
```

The script:
1. Verifies the consumer is a git repo.
2. Copies [`templates/lefthook.yml`](./templates/lefthook.yml) into the
   consumer if `lefthook.yml` is missing.
3. Warns (does not fail) if the existing `lefthook.yml` doesn't
   reference `github.com/inful/lefthooks`.
4. Runs `lefthook install` in the consumer to wire up git hooks.
5. Prints a summary.

Idempotent. Safe to run on every fresh clone.

### Bulk path — `make install-all`

```sh
make install-all   # loops over the 6 known consumers
```

Or override the list:

```sh
make install-all CONSUMERS='/path/to/a /path/to/b'
```

### Manual path

Replace the consumer repo's `lefthook.yml` with:

```yaml
# yaml-language-server: $schema=https://lefthook.dev/schema.json
#
# Imports the shared lefthook configuration from github.com/inful/lefthooks.
# Pin `ref` to a tag for reproducible builds.

min_version: 2.1.0

remotes:
  - git_url: git@github.com:inful/lefthooks.git
    ref: v0.2.0
    configs:
      - lefthook.yml
```

Then from the consumer repo:

```sh
lefthook install    # wire up git hooks
```

The first time hooks fire, lefthook clones this repo, merges the config
into the consumer's effective config, and runs only the hooks that apply.

### Pinning the version

Tag a release of this repo, e.g. `v0.2.0`, and have consumer repos pin
their `remotes[].ref` to that tag. Bump the pin when you want consumers
to pick up a new shared version. This keeps a known-good config frozen
per-consumer and lets you stage rollouts repo-by-repo.

### Local-only overrides

If a consumer repo needs a hook the shared config doesn't cover (or
needs to disable one), create a `lefthook-local.yml` in the consumer.
Lefthook's merge order is `lefthook.yml` → `extends` → `remotes` →
`lefthook-local.yml`, so `lefthook-local.yml` overrides anything from
the shared remote config.

Add `lefthook-local.yml` to the consumer's `.gitignore` so overrides
stay local.

## Adding a new shared hook

1. Edit `lefthook.yml` in this repo.
2. Add the hook with both a `glob:` (file-type gate) and a `skip:` with
   any additional shell-conditional gates (tool presence, config-file
   presence, project layout).
3. Bump the version tag and have consumers update their `ref`.
4. Document the new hook in the table above.

## Repo requirements for developers

- lefthook `>= 2.1.0` (matches `min_version` in `lefthook.yml`).
- For Go projects: a working `go` toolchain and (optionally)
  `golangci-lint`.
- For Markdown projects: optionally `markdownlint-cli`.
- For sqlc projects: optionally `sqlc`.

Missing tools cause their respective hooks to skip cleanly, never to
fail the commit.

## Layout

```
.
├── README.md                                  # this file
├── Makefile                                   # test / validate / install-into / install-all
├── lefthook.yml                               # the master hook set
├── templates/
│   └── lefthook.yml                           # canonical consumer config
├── bin/
│   └── install-into.sh                        # one-shot consumer bootstrap
├── .lefthook/
│   └── commit-msg/
│       └── check-conventional-commit.sh       # canonical commit-msg validator
└── tests/
    └── check-conventional-commit_test.sh      # 16-case test suite
```

The `.lefthook/` directory is lefthook's default `source_dir`. The
script inside is referenced from the remote config and resolved by
lefthook at hook-execution time.

## Migrating an existing consumer repo

1. Replace its `lefthook.yml` with the 7-line import above.
2. Delete any local commit-msg / format-check scripts (e.g.
   `scripts/check-commit-msg.sh`, `lefthook/check-fmt.sh`,
   `lefthook/check-conventional-commit.sh`, `hack/commitlint.sh`) —
   they are now provided by this repo.
3. Re-run `lefthook install` to refresh the git-hook symlinks.
4. Update CI / docs that referenced the deleted scripts.
5. Commit. The migration is a no-op for users who have already
   installed lefthook, except the deleted scripts become unused.

## Versioning

This repo follows [Semantic Versioning](https://semver.org/).

- **Major** bumps indicate a breaking change to the hook inventory
  (e.g. a hook that used to be opt-in becomes default, or vice versa).
- **Minor** bumps add new hooks (always gated, so safe to adopt).
- **Patch** bumps fix scripts or comment-only changes.

Consumers should pin `ref:` to a tag and bump deliberately.