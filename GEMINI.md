# GEMINI.md — projini

This file provides context for AI coding agents (Gemini, Claude, Copilot, etc.) working in this repository.

## Project overview

**projini** is a cross-platform CLI tool written in **Rust** that scaffolds production-ready projects across six languages: Rust, TypeScript, Python, Dart, Go, and Kotlin. It runs post-init commands automatically (`npm install`, `cargo check`, etc.) and generates publish-ready boilerplate with CI/CD pre-configured.

Single binary. No runtime. Built with Clap.

---

## Workspace structure

```
projini/
├── Cargo.toml                     # Virtual workspace manifest + shared [workspace.dependencies]
├── README.md
├── GEMINI.md                      # This file
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

Each language crate is a single `src/lib.rs` file implementing the `Scaffolder` trait.

---

## Core trait

Every language crate implements this trait from `projini-core`:

```rust
pub trait Scaffolder {
    fn name(&self) -> &'static str;   // e.g. "Rust"
    fn id(&self) -> &'static str;     // e.g. "rust"
    fn files(&self, config: &ProjectConfig) -> Vec<(String, String)>;          // (rel_path, content)
    fn post_init_command(&self, config: &ProjectConfig) -> Option<Vec<String>>; // e.g. ["cargo", "check"]
    fn required_tool(&self) -> Option<&'static str> { None }                   // checked with `which`

    // Default impl — do not override unless necessary:
    fn scaffold(&self, config: &ProjectConfig) -> Result<(), ProjectError> { ... }
}
```

The default `scaffold()` handles everything in order: dry-run preview → tool check → force-clean → file writing → git init → post-init command.

---

## Key types (`projini-core`)

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

---

## CLI commands

```bash
projini new <language> <name> [OPTIONS]
projini list
projini config edit | set <key> <value> | get [key]   # v1.1
```

Language aliases: `ts` = typescript, `py` = python, `kt`/`kotlin` = kotlin, `golang`/`go` = go.

Flags on `projini new`:

| Flag | Short | Description |
|------|-------|-------------|
| `--git` | | Run `git init` after scaffolding |
| `--no-init` | `-I` | Skip post-init command |
| `--dry-run` | | Preview files without writing |
| `--force` | `-f` | Overwrite existing directory |
| `--author NAME` | | Override author |
| `--license MIT` | | Override license |
| `--variant VAR` | | Template variant (future) |

Exit codes: `0` = success, `1` = error.

---

## Output conventions (`projini-core/src/output.rs`)

All terminal output must go through these helpers — never use raw `println!` in scaffolders:

```rust
output::success("src/main.rs")   // "  ✔ src/main.rs"  (green)
output::info("Running cargo check")  // "⠹ Running ..." (cyan)
output::error("Directory exists")    // "✘ ..."         (red, stderr)
output::done("my-app", "cd my-app && cargo run")  // final success message
```

---

## Post-init commands per language

| Language   | Command              | Required tool |
|------------|----------------------|---------------|
| Rust       | `cargo check`        | `cargo`       |
| TypeScript | `npm install`        | `npm`         |
| Python     | `pip install -e .`   | `pip`         |
| Dart       | `dart pub get`       | `dart`        |
| Go         | `go mod tidy`        | `go`          |
| Kotlin     | `gradle build`       | `gradle`      |

Tool availability is checked with `which::which(tool)` before running. Missing tool → `ProjectError::ToolNotFound`.

---

## Adding a new language

1. `cargo new --lib crates/projini-<lang>`
2. Add `projini-core.workspace = true` to its `Cargo.toml`
3. Add `[workspace.members]` entry in root `Cargo.toml`
4. Implement `Scaffolder` for `<Lang>Scaffolder` in `src/lib.rs`
5. Add `Language::<Lang>` variant to `types.rs` in `projini-core`
6. Add the match arm in `projini-cli/src/main.rs`

---

## Open issues (Linear)

### v1.0 — Core scaffolding

#### WEL-5 · Implement core Scaffolder trait with projini-core
**Branch:** `feature/wel-5-implement-core-scaffolder-trait-with-projini-core`
**Blocked by:** nothing — start here

Implement all files in `crates/projini-core/src/`:
- `scaffolder.rs` — the `Scaffolder` trait (see above)
- `types.rs` — `Language` enum with `FromStr` (aliases: `ts`, `py`, `kt`, `golang`) + `ProjectConfig`
- `error.rs` — `ProjectError` via `thiserror`
- `output.rs` — `success()`, `error()`, `info()`, `done()` using `colored`
- `runner.rs` — `run_post_init(cmd, cwd)` and `git_init(cwd)` using `std::process::Command`
- `lib.rs` — re-exports

Acceptance criteria:
- [ ] `ProjectConfig` has all fields listed above
- [ ] `ProjectError` covers all variants listed above
- [ ] `cargo check -p projini-core` passes with zero warnings
- [ ] Unit tests for `Language::from_str()` covering all aliases

---

#### WEL-6 · Implement language scaffolders (Dart, Go, Kotlin, Python, Rust, TS)
**Branch:** `feature/wel-6-implement-language-scaffolders-dart-go-kotlin-python-rust-ts`
**Blocked by:** WEL-5

One `lib.rs` per crate implementing `Scaffolder`. Files each scaffolder must generate:

**Rust** — `src/main.rs`, `Cargo.toml` (publish-ready with `license`, `repository`, `publish = false`), `tests/integration_test.rs`, `.gitignore`, `README.md`

**TypeScript** — `src/index.ts`, `src/index.test.ts`, `package.json` (jest + ts-jest devDeps), `tsconfig.json` (strict, ES2022), `.gitignore`, `README.md`

**Python** — `src/<pkg>/__init__.py`, `src/<pkg>/main.py`, `tests/__init__.py`, `tests/test_<pkg>.py`, `pyproject.toml` (hatchling build backend), `.gitignore`, `README.md`

**Dart** — `bin/<pkg>.dart`, `lib/<pkg>.dart`, `test/<pkg>_test.dart`, `pubspec.yaml`, `analysis_options.yaml`, `.gitignore`, `README.md`

**Go** — `cmd/<name>/main.go`, `internal/app/app.go`, `internal/app/app_test.go`, `pkg/README.md`, `go.mod`, `.gitignore`, `README.md`

**Kotlin** — `src/main/kotlin/Main.kt`, `src/test/kotlin/MainTest.kt`, `build.gradle.kts`, `settings.gradle.kts`, `gradle/wrapper/gradle-wrapper.properties`, `.gitignore`, `README.md`

Notes:
- Python/Dart package names: hyphens in project name → underscores (`my-app` → `my_app`)
- Interpolate `config.author`, `config.email`, `config.license` where relevant
- Every README includes build, run, and test commands

Acceptance criteria:
- [ ] `cargo build --workspace` passes
- [ ] Each scaffolder generates valid boilerplate (manually verify at least Rust + TypeScript)
- [ ] Package name normalisation correct for Python and Dart

---

#### WEL-7 · Add post-init automation
**Branch:** `feature/wel-7-add-post-init-automation-npm-install-cargo-check-etc`
**Blocked by:** WEL-5

The `runner` module in `projini-core/src/runner.rs`:

```rust
pub fn run_post_init(cmd: &[String], cwd: &str) -> Result<(), ProjectError>
pub fn git_init(cwd: &str) -> Result<(), ProjectError>
```

`run_post_init` calls `std::process::Command::new(program).args(rest).current_dir(cwd).status()`. Non-zero exit → `ProjectError::PostInitFailed`.

Integrate into `Scaffolder::scaffold()` default impl:
- Skip entirely if `config.skip_post_init == true`
- Check `required_tool()` with `which::which()` first → `ProjectError::ToolNotFound` if missing
- Call `git_init()` when `config.git_init == true` (after files, before post-init)

Acceptance criteria:
- [ ] Post-init runs automatically after file creation
- [ ] `--no-init` (`-I`) flag skips it
- [ ] Missing tool returns `ToolNotFound` with the tool name
- [ ] Non-zero exit returns `PostInitFailed` with full command string

---

#### WEL-8 · Implement styled terminal output
**Branch:** `feature/wel-8-implement-styled-terminal-output-with-colored-indicatif`
**Blocked by:** WEL-5

Implement `projini-core/src/output.rs` using `colored` and `indicatif`.

Wrap post-init execution in an `indicatif` spinner:

```rust
let pb = ProgressBar::new_spinner();
pb.set_style(ProgressStyle::default_spinner()
    .template("{spinner:.cyan} {msg}").unwrap());
pb.set_message(format!("Running {}", cmd.join(" ")));
pb.enable_steady_tick(Duration::from_millis(80));
// run command...
pb.finish_and_clear();
```

Colors must degrade gracefully on non-TTY (CI/pipe). Use `colored::control::set_override(false)` when stdout is not a TTY.

Acceptance criteria:
- [ ] `success()` → green `✔`, `error()` → red `✘` to stderr, `info()` → cyan `⠹`
- [ ] Spinner visible during post-init
- [ ] No raw `println!` in scaffolders — all output through helpers
- [ ] Clean output when piped (no ANSI codes)

---

#### WEL-9 · Implement --dry-run flag
**Branch:** `feature/wel-9-implement-dry-run-flag-for-preview-mode`
**Blocked by:** WEL-5

When `config.dry_run == true`, the `scaffold()` default impl must:
1. Call `self.files(config)` to get the file list
2. Print a tree preview (no filesystem writes)
3. Return `Ok(())` immediately — no post-init, no git init

Expected output:
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
- [ ] No files created when `--dry-run` is set
- [ ] Correct tree printed for all 6 languages
- [ ] Exit code `0`
- [ ] Compatible with `--force` (still no writes)

---

#### WEL-10 · Implement --git flag
**Branch:** `feature/wel-10-implement-git-flag-for-automatic-git-initialization`
**Blocked by:** WEL-5

When `config.git_init == true`, call `runner::git_init(&config.name)` after all files are written and after post-init completes. Show `output::success(".git/")` on success.

Check `which::which("git")` before calling and return `ProjectError::ToolNotFound("git")` if missing.

Acceptance criteria:
- [ ] `--git` flag triggers `git init` in project directory
- [ ] Runs after post-init, not before
- [ ] Missing git → clear `ToolNotFound` error
- [ ] No git without `--git`

---

### v1.1 — Configuration & interactive mode

#### WEL-11 · Create config file (~/.config/projini/config.toml)
**Branch:** `feature/wel-11-create-config-file-configprojiniconfigtoml`
**Blocked by:** nothing (v1.1, start after v1.0 ships)

Config location: `dirs::config_dir().unwrap().join("projini/config.toml")`. Use the `dirs` crate (add to workspace deps).

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

Rust structs (add to `projini-core`):
```rust
#[derive(Debug, Deserialize, Default)]
pub struct Config {
    pub defaults: Defaults,
    pub languages: Option<LanguageConfig>,
}
```

Loading: `Config::load() -> Result<Config>` — silently return `Default::default()` if file missing. Merge in `projini-cli/src/main.rs` before building `ProjectConfig`. Priority: CLI flags > config file > built-in defaults.

Acceptance criteria:
- [ ] `Config::load()` in `projini-core`
- [ ] Missing file silently ignored
- [ ] CLI flags override config values
- [ ] `dirs` added to `[workspace.dependencies]`

---

#### WEL-12 · Implement projini config command (edit, set, get)
**Branch:** `feature/wel-12-implement-projini-config-command-edit-set-get`
**Blocked by:** WEL-11

Add `config` subcommand to Clap in `projini-cli/src/main.rs`:

```rust
#[derive(Subcommand)]
enum ConfigCommands {
    Edit,
    Set { key: String, value: String },
    Get { key: Option<String> },
}
```

- `edit` → open `$EDITOR` (fallback: `nano` / `notepad`). Create file with commented template if missing.
- `set defaults.author "Jane"` → parse dotted key path, update `toml::Value`, write back.
- `get defaults.license` → print value; no key → print entire config.

Acceptance criteria:
- [ ] `projini config edit` opens `$EDITOR`
- [ ] `projini config set` persists to disk
- [ ] `projini config get` prints value or full config
- [ ] Invalid key → clear error message
- [ ] Template file created on first `config edit` if missing

---

#### WEL-13 · Implement interactive mode for projini new
**Branch:** `feature/wel-13-implement-interactive-mode-for-projini-new`
**Blocked by:** WEL-11, WEL-12

Trigger: `projini new` with no positional arguments.

Use `dialoguer`:
```rust
// Language picker
Select::with_theme(&ColorfulTheme::default())
    .with_prompt("Language")
    .items(&["Rust", "TypeScript", "Python", "Dart", "Go", "Kotlin"])
    .default(0)
    .interact()?;

// Project name
Input::<String>::with_theme(&ColorfulTheme::default())
    .with_prompt("Project name")
    .validate_with(|s: &String| if s.is_empty() { Err("required") } else { Ok(()) })
    .interact_text()?;

// Boolean flags
Confirm::with_theme(&ColorfulTheme::default())
    .with_prompt("Initialize git repo?")
    .default(false)
    .interact()?;
```

After prompts, build `ProjectConfig` and call `scaffolder.scaffold()` — identical path to non-interactive mode.

Acceptance criteria:
- [ ] `projini new` (no args) enters interactive mode
- [ ] All 6 languages shown in picker
- [ ] Name input rejects empty string
- [ ] Config file defaults pre-populate prompts where applicable
- [ ] Ctrl-C exits cleanly with code `1`

---

## Dependency graph

```
WEL-5 ──► WEL-6
      ──► WEL-7
      ──► WEL-8
      ──► WEL-9
      ──► WEL-10

WEL-11 ──► WEL-12 ──► WEL-13
```

Start with WEL-5. WEL-6 through WEL-10 can be worked in parallel once WEL-5 is done.

---

## Development commands

```bash
# Build everything
cargo build --workspace

# Run the CLI
cargo run -p projini-cli -- list
cargo run -p projini-cli -- new rust my-test --dry-run
cargo run -p projini-cli -- new typescript my-app --git --no-init

# Check a single crate
cargo check -p projini-core
cargo check -p projini-go

# Test
cargo test --workspace

# Lint
cargo fmt --all
cargo clippy --all-targets --all-features -- -D warnings
```

---

## CI

`.github/workflows/ci.yml` runs `fmt`, `clippy`, `build`, and `test` on every push/PR across Ubuntu, macOS, and Windows. All clippy warnings are treated as errors. PRs should be green on all three platforms before merging.
