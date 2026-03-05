# CLAUDE.md — projini

This file is read automatically by Claude at the start of every session in this repository. It provides full context about the codebase, architecture, and open work so Claude can assist without needing repeated explanation.

---

## Project overview

**projini** is a cross-platform CLI tool written in **Rust** that scaffolds production-ready projects across six languages: Rust, TypeScript, Python, Dart, Go, and Kotlin. It runs post-init commands automatically (`npm install`, `cargo check`, etc.) and generates publish-ready boilerplate with CI/CD pre-configured.

Single static binary. No runtime dependencies. Built with Clap v4.

---

## Workspace structure

```
projini/
├── Cargo.toml                     # Virtual workspace manifest + shared [workspace.dependencies]
├── README.md
├── CLAUDE.md                      # This file
├── .github/workflows/ci.yml       # CI: fmt, clippy, build, test (Linux/macOS/Windows)
└── crates/
    ├── projini-core/              # Scaffolder trait, types, errors, output helpers, runner
    ├── projini-rust/              # RustScaffolder
    ├── projini-typescript/        # TypeScriptScaffolder
    ├── projini-python/            # PythonScaffolder
    ├── projini-dart/              # DartScaffolder
    ├── projini-go/                # GoScaffolder
    ├── projini-kotlin/            # KotlinScaffolder
    └── projini-cli/               # Binary entrypoint — `projini` (Clap)
```

Each language crate is a single `src/lib.rs` implementing the `Scaffolder` trait. Do not add extra files to language crates unless explicitly asked.

---

## Core trait (`projini-core/src/scaffolder.rs`)

Every language crate implements this — it is the only public interface language crates expose:

```rust
pub trait Scaffolder {
    fn name(&self) -> &'static str;   // Human name, e.g. "Rust"
    fn id(&self) -> &'static str;     // CLI alias, e.g. "rust"
    fn files(&self, config: &ProjectConfig) -> Vec<(String, String)>;           // (rel_path, content)
    fn post_init_command(&self, config: &ProjectConfig) -> Option<Vec<String>>;  // e.g. ["cargo", "check"]
    fn required_tool(&self) -> Option<&'static str> { None }                    // verified with `which`

    // Default implementation — do not override in language crates:
    fn scaffold(&self, config: &ProjectConfig) -> Result<(), ProjectError> { ... }
}
```

The default `scaffold()` handles the full lifecycle in order:
1. Dry-run check → print tree, return early
2. `required_tool()` check via `which::which()`
3. Force-clean existing directory if `config.force`
4. Write all files from `self.files(config)`
5. `git init` if `config.git_init`
6. Run `post_init_command()` unless `config.skip_post_init`

**Do not override `scaffold()` in language crates.** Only implement `files()` and `post_init_command()`.

---

## Key types (`projini-core/src/types.rs`)

```rust
pub struct ProjectConfig {
    pub name: String,
    pub language: Language,
    pub author: Option<String>,
    pub email: Option<String>,
    pub license: String,          // default: "MIT"
    pub git_init: bool,
    pub skip_post_init: bool,
    pub dry_run: bool,
    pub force: bool,
    pub variant: Option<String>,
}

pub enum Language { Rust, TypeScript, Python, Dart, Go, Kotlin }

// Language::from_str() supports aliases:
// "ts" | "typescript" -> TypeScript
// "py" | "python"     -> Python
// "kt" | "kotlin"     -> Kotlin
// "go" | "golang"     -> Go
```

---

## Error types (`projini-core/src/error.rs`)

```rust
pub enum ProjectError {
    AlreadyExists(String),
    UnknownLanguage(String),
    FileCreation { path: String, source: io::Error },
    PostInitFailed(String),
    ToolNotFound(String),
    Io(#[from] io::Error),
    Other(#[from] anyhow::Error),
}
```

All errors are caught in `projini-cli/src/main.rs`, printed via `output::error()`, and result in exit code `1`.

---

## Output conventions (`projini-core/src/output.rs`)

All terminal output must go through these helpers. Never use raw `println!` inside scaffolders or the runner:

```rust
output::success("src/main.rs")              // "  ✔ src/main.rs"  — green
output::info("Running cargo check")         // "⠹ Running ..."    — cyan
output::error("Directory already exists")   // "✘ ..."            — red, stderr
output::done("my-app", "cd my-app && cargo run")  // final ✨ message
```

---

## CLI interface (`projini-cli/src/main.rs`)

```
projini new <language> <name> [OPTIONS]
projini list
projini config edit | set <key> <value> | get [key]   ← v1.1, not yet implemented
```

Flags for `projini new`:

| Flag | Short | Effect |
|------|-------|--------|
| `--git` | | `git init` after scaffolding |
| `--no-init` | `-I` | Skip post-init command |
| `--dry-run` | | Preview files, no writes |
| `--force` | `-f` | Overwrite existing directory |
| `--author NAME` | | Override author |
| `--license LICENSE` | | Override license (default: MIT) |
| `--variant VAR` | | Template variant (reserved for v1.2) |

Exit codes: `0` = success, `1` = any error.

---

## Post-init commands

| Language   | Command              | Required tool |
|------------|----------------------|---------------|
| Rust       | `cargo check`        | `cargo`       |
| TypeScript | `npm install`        | `npm`         |
| Python     | `pip install -e .`   | `pip`         |
| Dart       | `dart pub get`       | `dart`        |
| Go         | `go mod tidy`        | `go`          |
| Kotlin     | `gradle build`       | `gradle`      |

---

## Adding a new language (reference)

1. `cargo new --lib crates/projini-<lang>`
2. Add `projini-core.workspace = true` to its `Cargo.toml`
3. Add to `[workspace.members]` in root `Cargo.toml`
4. Implement `Scaffolder` for `<Lang>Scaffolder` in `src/lib.rs`
5. Add `Language::<Lang>` variant in `projini-core/src/types.rs`
6. Add match arm in `projini-cli/src/main.rs`

---

## Open issues

All issues are tracked in [Linear](https://linear.app/welsylab/project/projini-3ce189dfbc69). The dependency graph is:

```
WEL-5 ──► WEL-6, WEL-7, WEL-8, WEL-9, WEL-10   (v1.0 — all parallel after WEL-5)
WEL-11 ──► WEL-12 ──► WEL-13                     (v1.1 — sequential)
```

---

### WEL-5 · Implement core Scaffolder trait with projini-core
**Branch:** `feature/wel-5-implement-core-scaffolder-trait-with-projini-core`
**Milestone:** v1.0 — Core scaffolding
**Status:** Backlog — **start here**

Implement all modules in `crates/projini-core/src/`:

- `scaffolder.rs` — the `Scaffolder` trait with the full default `scaffold()` impl
- `types.rs` — `Language` enum with `Display`, `FromStr` (all aliases), and `ProjectConfig`
- `error.rs` — `ProjectError` using `thiserror`
- `output.rs` — `success()`, `error()`, `info()`, `done()` using `colored`
- `runner.rs` — `run_post_init(cmd: &[String], cwd: &str)` and `git_init(cwd: &str)` using `std::process::Command`
- `lib.rs` — re-exports

Acceptance criteria:
- [ ] `ProjectConfig` has all fields listed in this file
- [ ] `ProjectError` covers all variants listed in this file
- [ ] `cargo check -p projini-core` passes with zero warnings
- [ ] Unit tests for `Language::from_str()` covering all aliases (`ts`, `py`, `kt`, `golang`)

---

### WEL-6 · Implement language scaffolders (Dart, Go, Kotlin, Python, Rust, TS)
**Branch:** `feature/wel-6-implement-language-scaffolders-dart-go-kotlin-python-rust-ts`
**Milestone:** v1.0 — Core scaffolding
**Blocked by:** WEL-5

One `src/lib.rs` per crate. Files each scaffolder must generate:

**Rust:** `src/main.rs`, `Cargo.toml` (publish-ready: `license`, `repository`, `publish = false`), `tests/integration_test.rs`, `.gitignore`, `README.md`

**TypeScript:** `src/index.ts`, `src/index.test.ts`, `package.json` (jest + ts-jest), `tsconfig.json` (strict, ES2022), `.gitignore`, `README.md`

**Python:** `src/<pkg>/__init__.py`, `src/<pkg>/main.py`, `tests/__init__.py`, `tests/test_<pkg>.py`, `pyproject.toml` (hatchling), `.gitignore`, `README.md`

**Dart:** `bin/<pkg>.dart`, `lib/<pkg>.dart`, `test/<pkg>_test.dart`, `pubspec.yaml`, `analysis_options.yaml`, `.gitignore`, `README.md`

**Go:** `cmd/<name>/main.go`, `internal/app/app.go`, `internal/app/app_test.go`, `pkg/README.md`, `go.mod`, `.gitignore`, `README.md`

**Kotlin:** `src/main/kotlin/Main.kt`, `src/test/kotlin/MainTest.kt`, `build.gradle.kts`, `settings.gradle.kts`, `gradle/wrapper/gradle-wrapper.properties`, `.gitignore`, `README.md`

Notes:
- Python and Dart: normalise project name to package name — hyphens → underscores (`my-app` → `my_app`)
- Interpolate `config.author`, `config.email`, `config.license` where relevant
- Every README must include build, run, and test commands

Acceptance criteria:
- [ ] `cargo build --workspace` passes
- [ ] Each scaffolder generates syntactically valid boilerplate
- [ ] Package name normalisation correct for Python and Dart
- [ ] `config.author`/`config.license` interpolated in generated files

---

### WEL-7 · Add post-init automation
**Branch:** `feature/wel-7-add-post-init-automation-npm-install-cargo-check-etc`
**Milestone:** v1.0 — Core scaffolding
**Blocked by:** WEL-5

Implement `projini-core/src/runner.rs`:

```rust
pub fn run_post_init(cmd: &[String], cwd: &str) -> Result<(), ProjectError>
pub fn git_init(cwd: &str) -> Result<(), ProjectError>
```

`run_post_init`: split `cmd` into program + args, call `Command::new(program).args(args).current_dir(cwd).status()`. Non-zero exit → `PostInitFailed`.

Integrate into `Scaffolder::scaffold()`:
- Check `required_tool()` with `which::which()` before running → `ToolNotFound` if absent
- Skip entirely when `config.skip_post_init == true`
- Call `git_init()` when `config.git_init == true` (after files written, before post-init)

Acceptance criteria:
- [ ] Post-init runs automatically after file creation
- [ ] `--no-init` / `-I` skips it cleanly
- [ ] Missing tool → `ToolNotFound("cargo")` (not a panic or opaque IO error)
- [ ] Non-zero exit → `PostInitFailed` with the full command string

---

### WEL-8 · Implement styled terminal output
**Branch:** `feature/wel-8-implement-styled-terminal-output-with-colored-indicatif`
**Milestone:** v1.0 — Core scaffolding
**Blocked by:** WEL-5

Implement `projini-core/src/output.rs` using `colored` and `indicatif`.

Wrap post-init execution in an `indicatif` spinner:

```rust
let pb = ProgressBar::new_spinner();
pb.set_style(
    ProgressStyle::default_spinner()
        .template("{spinner:.cyan} {msg}")
        .unwrap(),
);
pb.set_message(format!("Running {}", cmd.join(" ")));
pb.enable_steady_tick(Duration::from_millis(80));
// ... run command ...
pb.finish_and_clear();
```

Colors must degrade gracefully on non-TTY. Check `std::io::stdout().is_terminal()` (or use `colored`'s built-in detection) and disable color when not a TTY.

Acceptance criteria:
- [ ] `success()` → green `✔`, `error()` → red `✘` to stderr, `info()` → cyan `⠹`
- [ ] Spinner shown during post-init command
- [ ] No raw `println!` in scaffolders — all output through helpers
- [ ] No ANSI codes when piped (CI-safe)

---

### WEL-9 · Implement --dry-run flag
**Branch:** `feature/wel-9-implement-dry-run-flag-for-preview-mode`
**Milestone:** v1.0 — Core scaffolding
**Blocked by:** WEL-5

When `config.dry_run == true`, the `scaffold()` default impl must:
1. Call `self.files(config)` to get the file list
2. Print a tree preview — no filesystem writes
3. Return `Ok(())` — no post-init, no git init

Expected output format:
```
📋 Preview (no files written):
  my-app/
  ├── src/main.rs
  ├── Cargo.toml
  ├── tests/integration_test.rs
  ├── README.md
  └── .gitignore
```

Acceptance criteria:
- [ ] No files created when `--dry-run` is passed
- [ ] Correct tree printed for all 6 languages
- [ ] Exit code `0`
- [ ] Compatible with `--force` (still no writes)

---

### WEL-10 · Implement --git flag
**Branch:** `feature/wel-10-implement-git-flag-for-automatic-git-initialization`
**Milestone:** v1.0 — Core scaffolding
**Blocked by:** WEL-5

When `config.git_init == true`, call `runner::git_init(&config.name)` after all files are written and after post-init completes. Print `output::success(".git/")` on success.

Check `which::which("git")` before running; return `ProjectError::ToolNotFound("git".into())` if missing.

Acceptance criteria:
- [ ] `--git` triggers `git init` in the new project directory
- [ ] Runs after post-init, not before
- [ ] Missing `git` binary → `ToolNotFound` error, not a panic
- [ ] No git activity without `--git`

---

### WEL-11 · Create config file (~/.config/projini/config.toml)
**Branch:** `feature/wel-11-create-config-file-configprojiniconfigtoml`
**Milestone:** v1.1 — Configuration & interactive mode
**Blocked by:** nothing (begin after v1.0 ships)

Add `dirs` to `[workspace.dependencies]`. Config path: `dirs::config_dir().unwrap().join("projini/config.toml")`.

Schema:
```toml
[defaults]
author = "Jane Doe"
email = "jane@example.com"
license = "MIT"
git_user = "janedoe"

[languages.typescript]
package_manager = "npm"   # npm | yarn | pnpm

[languages.python]
python_version = "3.11"
```

Add `Config::load() -> Result<Config>` to `projini-core`. Silently return `Config::default()` if the file is absent — never error on a missing config. Merge in `projini-cli/src/main.rs` before building `ProjectConfig`. Priority: **CLI flags > config file > built-in defaults**.

Acceptance criteria:
- [ ] `Config::load()` exists in `projini-core`
- [ ] Missing file silently returns defaults
- [ ] CLI flags override config values
- [ ] `dirs` added to `[workspace.dependencies]`

---

### WEL-12 · Implement projini config command (edit, set, get)
**Branch:** `feature/wel-12-implement-projini-config-command-edit-set-get`
**Milestone:** v1.1 — Configuration & interactive mode
**Blocked by:** WEL-11

Add `config` subcommand to Clap:

```rust
#[derive(Subcommand)]
enum ConfigCommands {
    Edit,
    Set { key: String, value: String },
    Get { key: Option<String> },
}
```

Behaviour:
- `edit` → spawn `$EDITOR` (fallback `nano` on Unix, `notepad` on Windows). Create file with a commented-out template if missing.
- `set defaults.author "Jane"` → parse dotted key path, update `toml::Value`, write back to disk.
- `get defaults.license` → print value; no key → print full config.

Acceptance criteria:
- [ ] `projini config edit` opens `$EDITOR`
- [ ] `projini config set` persists correctly to disk
- [ ] `projini config get` prints a value or the full config
- [ ] Invalid key path → clear error message, exit `1`
- [ ] Commented template created on first `config edit` when file is absent

---

### WEL-13 · Implement interactive mode for projini new
**Branch:** `feature/wel-13-implement-interactive-mode-for-projini-new`
**Milestone:** v1.1 — Configuration & interactive mode
**Blocked by:** WEL-11, WEL-12

Trigger: `projini new` with no positional arguments. Non-interactive mode is unchanged.

Use `dialoguer` with `ColorfulTheme`:

```rust
// Language picker
let idx = Select::with_theme(&ColorfulTheme::default())
    .with_prompt("Language")
    .items(&["Rust", "TypeScript", "Python", "Dart", "Go", "Kotlin"])
    .default(0)
    .interact()?;

// Project name with validation
let name: String = Input::with_theme(&ColorfulTheme::default())
    .with_prompt("Project name")
    .validate_with(|s: &String| {
        if s.is_empty() { Err("name cannot be empty") } else { Ok(()) }
    })
    .interact_text()?;

// Boolean flags
let git = Confirm::with_theme(&ColorfulTheme::default())
    .with_prompt("Initialize git repo?")
    .default(false)
    .interact()?;
```

After prompts, build `ProjectConfig` and call the same `scaffolder.scaffold()` path as non-interactive mode. Config file defaults (WEL-11) should pre-populate prompts where applicable.

Acceptance criteria:
- [ ] `projini new` (no args) enters interactive mode
- [ ] All 6 languages shown in picker
- [ ] Name input rejects empty string and whitespace-only
- [ ] Ctrl-C exits cleanly with code `1`
- [ ] Resulting behaviour identical to equivalent `projini new <lang> <name>` invocation

---

## Development commands

```bash
# Build everything
cargo build --workspace

# Run the CLI from source
cargo run -p projini-cli -- list
cargo run -p projini-cli -- new rust my-test --dry-run
cargo run -p projini-cli -- new typescript my-app --git --no-init

# Check a single crate
cargo check -p projini-core
cargo check -p projini-go

# Run tests
cargo test --workspace

# Lint (must pass before merging)
cargo fmt --all
cargo clippy --all-targets --all-features -- -D warnings
```

---

## CI

`.github/workflows/ci.yml` runs `fmt --check`, `clippy -D warnings`, `build`, and `test` on every push and PR, across Ubuntu, macOS, and Windows. All three must be green before a PR is merged. The release job builds a binary on `v*` tags.

---

## Coding conventions

- Use `workspace.dependencies` for all shared crates and external deps — never pin versions directly in a language crate's `Cargo.toml`
- All public errors use `thiserror` — no `unwrap()` or `expect()` outside of tests
- All terminal output through `projini-core::output::*` — no raw `println!` in scaffolders
- `edition = "2024"` across the workspace
- Keep language crates to a single `src/lib.rs` unless there is a strong reason to split
