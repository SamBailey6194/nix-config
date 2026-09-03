//! Hyprland dev layout launcher.
//!
//! Two modes:
//!
//!   dev-layout               Mode A - the nix-config layout, pinned to
//!                            workspace 2 by static window rules.
//!                            Bound to SUPER + SHIFT + Z.
//!
//!   dev-layout --new [PATH]  Mode B - a generic dev layout, placed on the
//!                            lowest free workspace in the dynamic pool
//!                            (workspaces 3-6 by default).
//!                            Bound to SUPER + CTRL + Z.
//!
//! Both modes produce the same shape: Zed on the left at 75% width, with two
//! Kitty terminals stacked in the remaining 25%. Both modes are placed by
//! STATIC window rules matched on class (and, for Zed, title); the only
//! difference is that Mode A's rules live in the Lua config and Mode B's are
//! registered at launch time, because the target workspace is not known until
//! then. See `register_pool_rules` for why per-launch `hl.exec_cmd` rules are
//! not an option.
//!
//! DIAGNOSTICS
//!
//! When Hyprland execs this binary from a keybind it dup2()s /dev/null over
//! both stdout and stderr, so every `println!` and every error message below is
//! thrown away. Anything the user must actually see therefore goes through
//! `notify` as well as the terminal — see `main`.

use std::env;
use std::ffi::OsStr;
use std::fs::{self, OpenOptions};
use std::io::{ErrorKind, Write as _};
use std::path::{Path, PathBuf};
use std::process::{self, Command, Stdio};
use std::thread;
use std::time::{Duration, Instant};

use anyhow::{bail, ensure, Context, Result};
use colored::Colorize;

/// Default first and last workspace of the generic dev pool. Workspace 1 is the
/// dashboard, workspace 2 is reserved for the nix-config layout, 6 is mail
/// (Claws Mail), 7-9 are browsers/Affinity/comms and 10 is the catch-all, so
/// the pool is 3-5.
///
/// The pool used to run 3-6. Workspace 6 was handed to Claws Mail so that mail
/// has a fixed home like the browsers and comms do; a dev layout landing on
/// top of the mail client would defeat the point of pinning it.
///
/// These are only the DEFAULTS. `60-keybinds.lua` is shared by every device,
/// but `devices/devtower.lua` pins DaVinci Resolve to workspace 5 and OBS to
/// workspace 6, and `devices/framework.lua` pins Resolve to workspace 5 — still
/// inside the narrowed pool in Resolve's case. Those devices can narrow it
/// further with the environment variables below instead of forking the keybind.
const DEFAULT_POOL_FIRST: u32 = 3;
const DEFAULT_POOL_LAST: u32 = 5;

/// Workspace the nix-config layout is pinned to by the static window rules.
const NIX_CONFIG_WS: u32 = 2;

/// Environment variable that overrides where the nix-config repo lives.
const NIX_CONFIG_ENV: &str = "DEV_LAYOUT_NIX_CONFIG";

/// Environment variables that override the dev pool bounds.
const POOL_FIRST_ENV: &str = "DEV_LAYOUT_POOL_FIRST";
const POOL_LAST_ENV: &str = "DEV_LAYOUT_POOL_LAST";

/// Path used when `DEV_LAYOUT_NIX_CONFIG` is unset, relative to $HOME.
const NIX_CONFIG_DEFAULT_REL: &str = "Repos/personal/nix-config";

/// Folder name the nix-config layout's workspace 2 rule matches on.
const NIX_CONFIG_FOLDER: &str = "nix-config";

/// RE2 pattern matching Zed's window class. Zed has no `--class` flag, so every
/// Zed window on the system reports this same class; the title is the only
/// thing that tells two Zed windows apart. The dots are RE2 metacharacters and
/// are escaped so this cannot also match e.g. `devxzedxZed`.
const ZED_CLASS_PATTERN: &str = r"^(dev\.zed\.Zed)$";

/// Windows a dev layout is made of: one editor and two terminals.
const LAYOUT_WINDOWS: usize = 3;

/// How long to wait for a Mode B layout's windows to appear on their target
/// workspace, and how often to look.
const WINDOW_WAIT: Duration = Duration::from_secs(10);
const WINDOW_POLL_INTERVAL: Duration = Duration::from_millis(250);

/// A lock file older than this is assumed to belong to a dev-layout run that
/// died without cleaning up. A successful run is bounded by `WINDOW_WAIT` plus
/// a handful of hyprctl round trips, so this is a generous margin.
const LOCK_STALE_AFTER: Duration = Duration::from_secs(60);

fn main() {
    if let Err(err) = run() {
        // `{err:#}` flattens the anyhow context chain onto one line.
        let message = format!("{err:#}");
        eprintln!("{} {}", "dev-layout:".red(), message);
        notify(Urgency::Critical, "dev-layout failed", &message);
        process::exit(1);
    }
}

fn run() -> Result<()> {
    match parse_args(env::args().skip(1).collect())? {
        Mode::Help => {
            print_help();
            Ok(())
        }
        Mode::NixConfig => nix_config_layout(),
        Mode::New { path } => new_dev_space(path.as_deref()),
    }
}

// ── Argument parsing ──────────────────────────────────────────────────

enum Mode {
    Help,
    NixConfig,
    New { path: Option<String> },
}

fn parse_args(args: Vec<String>) -> Result<Mode> {
    let mut new_space = false;
    let mut path: Option<String> = None;

    for arg in args {
        match arg.as_str() {
            "-h" | "--help" => return Ok(Mode::Help),
            "--new" => new_space = true,
            other if other.starts_with('-') => {
                bail!("Unknown option '{other}'. Run 'dev-layout --help' for usage.")
            }
            other => {
                if path.is_some() {
                    bail!("Too many paths given: only one project path is accepted.");
                }
                path = Some(other.to_string());
            }
        }
    }

    if new_space {
        Ok(Mode::New { path })
    } else {
        // Mode A always opens the nix-config repo, so a stray path argument
        // would be silently ignored. Say so rather than pretend.
        if let Some(path) = path {
            bail!("A path ('{path}') only applies to --new; the default mode always opens the nix-config repo.");
        }
        Ok(Mode::NixConfig)
    }
}

fn print_help() {
    println!("{}", "dev-layout - Hyprland dev layout launcher".green());
    println!();
    println!("USAGE:");
    println!("    dev-layout                 nix-config layout on workspace {NIX_CONFIG_WS}");
    println!("    dev-layout --new [PATH]    generic dev layout on the lowest free");
    println!(
        "                               workspace in the pool \
         (default {DEFAULT_POOL_FIRST}-{DEFAULT_POOL_LAST})"
    );
    println!("    dev-layout --help          show this help");
    println!();
    println!("PATH defaults to the current directory. Under a Hyprland keybind that is");
    println!("HYPRLAND's working directory, not a terminal's, so pass the project");
    println!("explicitly when launching from a keybind.");
    println!();
    println!("ENVIRONMENT:");
    println!("    {NIX_CONFIG_ENV}   override the nix-config repo path");
    println!("                            (default: $HOME/{NIX_CONFIG_DEFAULT_REL})");
    println!("    {POOL_FIRST_ENV}  first workspace of the dev pool (default: {DEFAULT_POOL_FIRST})");
    println!("    {POOL_LAST_ENV}   last workspace of the dev pool (default: {DEFAULT_POOL_LAST})");
}

// ── Mode A: the nix-config layout ─────────────────────────────────────

/// Launch the nix-config dev layout and let the static workspace 2 window
/// rules place it.
///
/// Placement coupling, worth stating plainly: Zed has no `--class` flag, so
/// every Zed window carries the class `dev.zed.Zed`. The only thing that
/// distinguishes this window from any other Zed window is its TITLE, which
/// Zed sets to the name of the folder it opened. The workspace 2 rule
/// therefore matches class + title `nix-config`, which means the directory
/// this function opens MUST still be named `nix-config` — rename the folder
/// (or point the override at a differently named checkout) and the rule stops
/// firing, so the editor lands on the catch-all workspace instead.
///
/// The terminals have no such problem: Kitty does support `--class`, so they
/// are launched as `nixcfg-term` and matched on class alone.
fn nix_config_layout() -> Result<()> {
    let repo = nix_config_path()?;
    let repo_path = Path::new(&repo);

    // `as_str()` rather than `repo.cyan()`: `repo_path` borrows `repo`, and the
    // colored trait is implemented on `&str`, so this keeps the call a borrow.
    println!(
        "{} {}",
        "Launching nix-config dev layout:".green(),
        repo.as_str().cyan()
    );

    if !repo_path.is_dir() {
        warn(&format!(
            "{repo} is not a directory; Zed may open an empty window."
        ));
    }

    // An independent check, not an `else if`: a path can be a perfectly good
    // directory AND be named something the workspace 2 rule will never match,
    // and that is precisely the case worth warning about. Compared as a path
    // COMPONENT rather than a string suffix, so that a sibling directory named
    // e.g. `old-nix-config` is not mistaken for the real thing.
    if repo_path.file_name() != Some(OsStr::new(NIX_CONFIG_FOLDER)) {
        // See the placement coupling note above.
        warn(&format!(
            "repo folder is not named '{NIX_CONFIG_FOLDER}'; the workspace \
             {NIX_CONFIG_WS} window rule matches on Zed's title and will not fire."
        ));
    }

    // Spawn Zed editor on the repo. No per-launch rules needed: the static
    // window rules pin both the editor and the nixcfg-term terminals.
    Command::new("zeditor")
        .arg("-n")
        .arg(&repo)
        .spawn()
        .context("Failed to launch zeditor")?;
    thread::sleep(Duration::from_secs(1));

    // Two terminals, tagged so the workspace 2 rule can match them.
    for _ in 0..2 {
        Command::new("kitty")
            .args(["--class", "nixcfg-term"])
            .spawn()
            .context("Failed to launch kitty")?;
        thread::sleep(Duration::from_millis(500));
    }

    // Move to workspace 2 before arranging the split. If the static rules
    // place these windows without `silent`, focus has already followed them
    // here and this is a no-op; if they ever gain `silent`, this is what stops
    // the split being applied to whatever workspace we happened to be on.
    focus_workspace(NIX_CONFIG_WS)?;
    thread::sleep(Duration::from_millis(200));

    arrange_active_workspace()?;

    println!("{}", "Dev layout ready.".green());
    Ok(())
}

/// Resolve the nix-config repo path, honouring the environment override.
fn nix_config_path() -> Result<String> {
    if let Ok(path) = env::var(NIX_CONFIG_ENV) {
        if !path.is_empty() {
            return Ok(path);
        }
    }

    let home = env::var("HOME").context("HOME is unset, cannot locate the nix-config repo")?;
    Ok(format!("{home}/{NIX_CONFIG_DEFAULT_REL}"))
}

// ── Mode B: a generic dev space in the pool ───────────────────────────

/// Launch a generic dev layout on the lowest free workspace in the pool.
///
/// The order below matters, so it is spelled out:
///
///   1. take the pool lock, so two quick presses of the keybind cannot both
///      pick the same "free" workspace;
///   2. resolve the project directory, because its folder name is what the
///      editor rule matches on and nothing can be launched without it;
///   3. pick the target workspace;
///   4. register the two window rules for this launch;
///   5. launch the three windows as direct children;
///   6. wait for them to actually land, then arrange the split.
fn new_dev_space(path: Option<&str>) -> Result<()> {
    let _lock = PoolLock::acquire()?;

    let project = resolve_project(path)?;
    let target = first_free_pool_workspace()?;

    println!(
        "{} {} {} {}",
        "Launching dev layout for".green(),
        project.path.display().to_string().cyan(),
        "on workspace".green(),
        target.to_string().cyan()
    );

    register_pool_rules(target, &project.name)?;

    // Direct children of this process, exactly as Mode A launches its windows:
    // no shell is involved, so nothing needs quoting, and the child inherits
    // OUR working directory rather than the compositor's.
    //
    // The sleeps between launches are about ORDER, not readiness — the poll
    // below handles readiness. Dwindle splits in the order windows map, so the
    // editor has to map first to end up as the left-hand column that
    // `arrange_active_workspace` then widens.
    Command::new("zeditor")
        .arg("-n")
        .arg(&project.path)
        .current_dir(&project.path)
        .spawn()
        .context("Failed to launch zeditor")?;
    thread::sleep(Duration::from_secs(1));

    let term_class = pool_term_class(target);
    for _ in 0..2 {
        Command::new("kitty")
            .args(["--class", term_class.as_str()])
            .current_dir(&project.path)
            .spawn()
            .context("Failed to launch kitty")?;
        thread::sleep(Duration::from_millis(500));
    }

    // Bounded poll rather than a fixed sleep: Zed's start-up time varies by an
    // order of magnitude between a cold start and a hand-off to a running
    // instance, so any single sleep is either too short or wasteful.
    wait_for_workspace_windows(target, LAYOUT_WINDOWS)?;

    // The windows were placed 'silent', so focus never followed them: the
    // focus/splitratio dispatches below act on the ACTIVE workspace, which is
    // still whichever one we were on. Switch to the target workspace first so
    // the split is applied to the layout we just built. Scoping the dispatches
    // to a workspace instead is not an option — the Lua stubs expose no
    // workspace-scoped variant of `focus` or `layout`, and `HL.Window` has no
    // per-window move setter. Switching is also the behaviour the keybind
    // wants: SUPER + CTRL + Z opens a new dev space and takes you to it.
    focus_workspace(target)?;
    thread::sleep(Duration::from_millis(200));

    arrange_active_workspace()?;

    println!(
        "{} {}",
        "Dev layout ready on workspace".green(),
        target.to_string().cyan()
    );
    Ok(())
}

/// Class the Mode B terminals are launched with, and matched on.
///
/// The target workspace is baked into the class so that two pool layouts can
/// never collide: a leftover `devpool-term-4` rule cannot capture terminals
/// meant for workspace 5.
fn pool_term_class(workspace: u32) -> String {
    format!("devpool-term-{workspace}")
}

/// The project a Mode B layout is built around: an absolute, symlink-free path
/// and the folder name Zed will use as the window title.
struct Project {
    path: PathBuf,
    name: String,
}

/// Resolve and validate the project directory.
///
/// Canonicalising first is not tidiness: the folder name IS the editor's window
/// title and therefore the only thing the editor rule can match on, so it has
/// to be known before anything is launched. It also pins down a relative path,
/// which the editor would otherwise resolve against a different working
/// directory than the one this process was started in.
fn resolve_project(path: Option<&str>) -> Result<Project> {
    let requested: PathBuf = match path {
        Some(path) => PathBuf::from(path),
        None => env::current_dir()
            .context("No project path was given and the working directory cannot be read")?,
    };

    let resolved = fs::canonicalize(&requested).with_context(|| {
        format!(
            "Cannot resolve project path '{}' — check that it exists.",
            requested.display()
        )
    })?;

    ensure!(
        resolved.is_dir(),
        "Project path '{}' is not a directory.",
        resolved.display()
    );

    // With no path given, the working directory is the project. That is right
    // in a terminal and wrong from a keybind, where Hyprland execs through
    // /bin/sh -c and the child inherits the COMPOSITOR's working directory —
    // usually $HOME. Opening $HOME in Zed is never what was meant, and it would
    // set the editor's title to the home folder's name, so refuse instead.
    if path.is_none() {
        if let Some(home) = env::var_os("HOME") {
            let home_is_project = fs::canonicalize(&home)
                .map(|home| home == resolved)
                .unwrap_or(false);
            if home_is_project {
                bail!(
                    "No project path given and the working directory is your home folder \
                     ('{}'). From a keybind the working directory is Hyprland's, not a \
                     terminal's — pass the project explicitly, e.g. \
                     'dev-layout --new ~/Repos/personal/some-project'.",
                    resolved.display()
                );
            }
        }
    }

    let name = resolved
        .file_name()
        .and_then(OsStr::to_str)
        .with_context(|| {
            format!(
                "Project path '{}' has no usable folder name, so the editor window rule \
                 would have no title to match on.",
                resolved.display()
            )
        })?
        .to_string();

    ensure!(
        !name.is_empty() && !name.contains('\n'),
        "Project folder name '{name}' cannot be used in a window rule."
    );

    Ok(Project {
        path: resolved,
        name,
    })
}

/// Register the two window rules that place this launch's windows.
///
/// WHY NOT `hl.exec_cmd(cmd, { workspace = 'N silent' })`
///
/// A per-launch exec rule attaches to the window spawned by THAT command, by
/// matching the child's pid / the `HL_EXEC_RULE_TOKEN` it is handed. It does
/// beat the static catch-all — but only if the window actually belongs to the
/// process Hyprland spawned. `zeditor` is a single-instance CLI: when Zed is
/// already running it forwards the request to the existing process over IPC and
/// exits immediately, so the window is created by a process Hyprland never
/// spawned and the exec rule never attaches. The editor then falls through to
/// the ws10 catch-all, which is exactly the bug this rewrite fixes. Do not
/// "simplify" this back to exec rules.
///
/// Static rules have no such problem: they are matched at window-map time
/// against class and title and are completely pid-independent, which is why
/// Mode A has always worked. The only thing Mode A gets for free is that its
/// rules can live in the Lua config — a pool workspace is not known until
/// launch time, so Mode B registers the same kind of rule dynamically, one
/// `hyprctl eval` immediately before launching.
///
/// Two details worth keeping:
///
///   * Rules are matched in registration order and the LAST match wins (see the
///     ordering note in `devices/laptop-intel.lua`), so rules registered now,
///     after the config has loaded, beat the catch-all.
///   * The rules outlive this process — they are torn down by a config reload,
///     not by us. Re-registering under a stable name per workspace keeps that
///     bounded, and the previous rule handle is disabled first where the Lua
///     state lets us reach it.
fn register_pool_rules(target: u32, project_name: &str) -> Result<()> {
    let editor_rule = lua_string(&format!("dev-layout-pool-{target}-editor"))?;
    let term_rule = lua_string(&format!("dev-layout-pool-{target}-term"))?;
    let editor_class = lua_string(ZED_CLASS_PATTERN)?;
    let editor_title = lua_string(&format!("^({})$", re2_escape(project_name)))?;
    let term_class = lua_string(&format!("^({})$", re2_escape(&pool_term_class(target))))?;
    let workspace = lua_string(&format!("{target} silent"))?;

    // One expression, on one line. An immediately-invoked function is used
    // rather than a `do ... end` block so the text is valid both as a chunk and
    // as an expression, whichever way `hyprctl eval` chooses to wrap it. The
    // registry bookkeeping is wrapped in pcall throughout: if the Lua state
    // does not expose `_G`, we simply lose the ability to disable the previous
    // rule, and registration itself must still go through.
    let expression = format!(
        "(function() \
         local store = nil; \
         pcall(function() _G.__dev_layout_rules = _G.__dev_layout_rules or {{}}; \
         store = _G.__dev_layout_rules end); \
         local names = {{ {editor_rule}, {term_rule} }}; \
         if store then for _, n in ipairs(names) do \
         local old = store[n]; store[n] = nil; \
         if old then pcall(function() old:set_enabled(false) end) end \
         end end; \
         local editor = hl.window_rule({{ name = names[1], \
         match = {{ class = {editor_class}, title = {editor_title} }}, \
         workspace = {workspace} }}); \
         local term = hl.window_rule({{ name = names[2], \
         match = {{ class = {term_class} }}, \
         workspace = {workspace} }}); \
         if store then store[names[1]] = editor; store[names[2]] = term end \
         end)()"
    );

    hyprctl(&["eval", expression.as_str()])
        .context("Failed to register the window rules for this dev space")
}

/// Find the lowest workspace in the pool that holds no windows.
///
/// A workspace counts as free if Hyprland does not know about it yet, or if it
/// exists with a window count of zero. Anything we cannot positively prove is
/// empty is treated as occupied.
fn first_free_pool_workspace() -> Result<u32> {
    let (first, last) = pool_range()?;
    let occupied = occupied_workspaces()?;

    for ws in first..=last {
        if !occupied.contains(&i64::from(ws)) {
            return Ok(ws);
        }
    }

    let count = last - first + 1;
    bail!(
        "No free workspace in the dev pool ({first}-{last}); all {count} are in use. \
         Close a dev space or use one of them directly."
    )
}

/// The dev pool bounds, after applying the environment overrides.
fn pool_range() -> Result<(u32, u32)> {
    let first = pool_bound(POOL_FIRST_ENV, DEFAULT_POOL_FIRST)?;
    let last = pool_bound(POOL_LAST_ENV, DEFAULT_POOL_LAST)?;

    ensure!(
        first >= 1,
        "{POOL_FIRST_ENV} must be at least 1; workspace 0 does not exist."
    );
    ensure!(
        first <= last,
        "{POOL_FIRST_ENV} ({first}) is above {POOL_LAST_ENV} ({last}); the dev pool is empty."
    );
    ensure!(
        !(first..=last).contains(&NIX_CONFIG_WS),
        "The dev pool ({first}-{last}) covers workspace {NIX_CONFIG_WS}, which is reserved \
         for the nix-config layout."
    );

    Ok((first, last))
}

/// Read one pool bound from the environment, falling back to `default`.
fn pool_bound(name: &str, default: u32) -> Result<u32> {
    match env::var(name) {
        Ok(raw) if !raw.trim().is_empty() => raw
            .trim()
            .parse::<u32>()
            .with_context(|| format!("{name} must be a workspace number, but is '{raw}'")),
        // Unset, empty, or not valid UTF-8: use the default.
        _ => Ok(default),
    }
}

/// Ids of every workspace that currently holds at least one window.
///
/// Fails CLOSED. An unparsable or unexpected response must never be read as
/// "nothing is occupied", because that answer hands out the first pool
/// workspace and drops somebody's windows on top of an existing layout.
fn occupied_workspaces() -> Result<Vec<i64>> {
    let json = hyprctl_stdout(&["workspaces", "-j"])?;
    let trimmed = json.trim();

    ensure!(
        trimmed.starts_with('[') && trimmed.ends_with(']'),
        "hyprctl workspaces -j did not return a JSON array; refusing to guess which \
         workspaces are free."
    );

    let workspaces = parse_workspace_windows(trimmed)?;
    ensure!(
        !workspaces.is_empty(),
        "hyprctl workspaces -j listed no workspaces at all, which cannot be true while \
         Hyprland is running; refusing to guess which workspaces are free."
    );

    Ok(workspaces
        .into_iter()
        .filter(|(_, windows)| *windows > 0)
        .map(|(id, _)| id)
        .collect())
}

/// Pull the `(id, windows)` pair out of every object in `hyprctl workspaces -j`.
///
/// This is a deliberately small scanner rather than a JSON dependency: the
/// crate carries only anyhow and colored, and adding serde_json would mean
/// regenerating the workspace Cargo.lock that the nix build pins.
///
/// It is safe against string values that look like keys, because Hyprland
/// escapes quotes inside JSON strings: a window title containing `id":` shows
/// up as `\"id\":`, which never matches the `"id":` byte sequence searched for
/// here. Note also that `"monitorID":` differs in case and so is not matched.
fn parse_workspace_windows(json: &str) -> Result<Vec<(i64, i64)>> {
    let mut found = Vec::new();
    let mut rest = json;

    while let Some(pos) = rest.find(ID_KEY) {
        rest = &rest[pos + ID_KEY.len()..];

        // Refuse to skip a workspace we cannot identify: silently dropping it
        // would make an occupied workspace look free.
        let id = read_int(rest).context(
            "hyprctl workspaces -j contained a workspace with no readable id; refusing to \
             guess which workspaces are free.",
        )?;

        // The window count for this workspace lies between this "id" key and
        // the next one, i.e. inside the same JSON object.
        let object_end = rest.find(ID_KEY).unwrap_or(rest.len());
        let object = &rest[..object_end];

        // If the count is missing or unparsable, assume the workspace is busy.
        // Never claim a workspace we cannot prove is empty.
        let windows = object
            .find(WINDOWS_KEY)
            .and_then(|pos| read_int(&object[pos + WINDOWS_KEY.len()..]))
            .unwrap_or(1);

        found.push((id, windows));
    }

    Ok(found)
}

/// Count the windows currently sitting on `workspace`, from `hyprctl clients -j`.
///
/// Same scanning approach, and the same fail-closed stance: an unrecognisable
/// response is an error, not "no windows yet".
fn clients_on_workspace(json: &str, workspace: u32) -> Result<usize> {
    const WORKSPACE_KEY: &str = "\"workspace\":";

    let trimmed = json.trim();
    ensure!(
        trimmed.starts_with('[') && trimmed.ends_with(']'),
        "hyprctl clients -j did not return a JSON array."
    );

    let mut count = 0;
    let mut rest = trimmed;

    while let Some(pos) = rest.find(WORKSPACE_KEY) {
        rest = &rest[pos + WORKSPACE_KEY.len()..];

        // Each client's "workspace" value is an object holding the id, so the
        // first "id" after this key belongs to this client.
        let object_end = rest.find(WORKSPACE_KEY).unwrap_or(rest.len());
        let object = &rest[..object_end];

        let id = object
            .find(ID_KEY)
            .and_then(|pos| read_int(&object[pos + ID_KEY.len()..]))
            .context("hyprctl clients -j contained a client with no readable workspace id.")?;

        if id == i64::from(workspace) {
            count += 1;
        }
    }

    Ok(count)
}

const ID_KEY: &str = "\"id\":";
const WINDOWS_KEY: &str = "\"windows\":";

/// Read a leading (optionally negative) integer, skipping leading whitespace.
fn read_int(text: &str) -> Option<i64> {
    let text = text.trim_start();
    let (negative, digits_start) = match text.strip_prefix('-') {
        Some(rest) => (true, rest),
        None => (false, text),
    };

    let digits: String = digits_start
        .chars()
        .take_while(char::is_ascii_digit)
        .collect();
    if digits.is_empty() {
        return None;
    }

    let value: i64 = digits.parse().ok()?;
    Some(if negative { -value } else { value })
}

// ── The pool lock ─────────────────────────────────────────────────────

/// An exclusive lock over "picking and filling a pool workspace".
///
/// Without it, two quick presses of SUPER + CTRL + Z both sample the free
/// workspace before either has opened a window, both get the same answer, and
/// two projects land on top of each other. The whole run is held, not just the
/// sampling, because the workspace does not look occupied until its first
/// window maps — roughly a second later.
///
/// O_EXCL creation is the lock; the file is removed on drop. A lock left behind
/// by a run that died is reclaimed once it is older than `LOCK_STALE_AFTER`.
struct PoolLock {
    path: PathBuf,
}

impl PoolLock {
    fn acquire() -> Result<Self> {
        let path = lock_path();

        if let Some(lock) = Self::try_create(&path)? {
            return Ok(lock);
        }

        if lock_is_stale(&path) {
            // Best effort: if the removal races another process the retry
            // below simply fails again, which is the safe outcome.
            let _ = fs::remove_file(&path);
            if let Some(lock) = Self::try_create(&path)? {
                return Ok(lock);
            }
        }

        bail!(
            "Another 'dev-layout --new' is still setting up a dev space (lock: {}). \
             Wait for it to finish, or remove that file if nothing is running.",
            path.display()
        )
    }

    /// `Ok(None)` means somebody else holds the lock.
    fn try_create(path: &Path) -> Result<Option<Self>> {
        match OpenOptions::new().write(true).create_new(true).open(path) {
            Ok(mut file) => {
                // Purely for the human who finds a stale lock file.
                let _ = writeln!(file, "{}", process::id());
                Ok(Some(Self {
                    path: path.to_path_buf(),
                }))
            }
            Err(err) if err.kind() == ErrorKind::AlreadyExists => Ok(None),
            Err(err) => {
                Err(err).with_context(|| format!("Cannot create lock file {}", path.display()))
            }
        }
    }
}

impl Drop for PoolLock {
    fn drop(&mut self) {
        let _ = fs::remove_file(&self.path);
    }
}

fn lock_path() -> PathBuf {
    // $XDG_RUNTIME_DIR is per-user, on tmpfs, and cleared at logout, so a lock
    // can never survive into the next session.
    if let Some(dir) = env::var_os("XDG_RUNTIME_DIR") {
        if !dir.is_empty() {
            return PathBuf::from(dir).join("dev-layout.lock");
        }
    }

    let user = env::var("USER").unwrap_or_else(|_| "unknown".to_string());
    PathBuf::from("/tmp").join(format!("dev-layout-{user}.lock"))
}

fn lock_is_stale(path: &Path) -> bool {
    fs::metadata(path)
        .and_then(|meta| meta.modified())
        // A modification time in the future yields Err here, which is read as
        // "not stale" — the conservative answer.
        .map(|modified| {
            modified
                .elapsed()
                .map(|age| age > LOCK_STALE_AFTER)
                .unwrap_or(false)
        })
        .unwrap_or(false)
}

// ── Hyprland plumbing ─────────────────────────────────────────────────

/// Wait until `expected` windows are sitting on `workspace`.
///
/// Bounded, and it does not pretend to have succeeded: on timeout the caller
/// must leave the workspace alone rather than arrange a half-built layout.
fn wait_for_workspace_windows(workspace: u32, expected: usize) -> Result<()> {
    let deadline = Instant::now() + WINDOW_WAIT;
    let mut seen;

    loop {
        let json = hyprctl_stdout(&["clients", "-j"])?;
        seen = clients_on_workspace(&json, workspace)?;

        if seen >= expected {
            return Ok(());
        }
        if Instant::now() >= deadline {
            break;
        }
        thread::sleep(WINDOW_POLL_INTERVAL);
    }

    bail!(
        "Only {seen} of {expected} windows reached workspace {workspace} within {}s. \
         Leaving it as it is rather than arranging a half-built layout.",
        WINDOW_WAIT.as_secs()
    )
}

/// Switch to `workspace`, making it the active one.
fn focus_workspace(workspace: u32) -> Result<()> {
    let expression = format!("hl.dsp.focus({{ workspace = {workspace} }})");
    hyprctl(&["dispatch", expression.as_str()])
}

/// Focus the editor and give it 75% of the width.
///
/// Two `focus left` dispatches, not one: whichever of the three windows holds
/// focus, two steps left always lands on the editor column (a third step would
/// be a no-op, so overshooting is harmless). `splitratio` then applies to the
/// focused window.
///
/// Hyprland 0.56 runs a Lua config provider, under which `hyprctl dispatch`
/// wraps its argument as `hl.dispatch(<text>)`. The legacy flat forms
/// (`dispatch movefocus l`, `dispatch splitratio exact 0.75`) are therefore
/// Lua syntax errors and exit 7, which would make this helper bail. Each
/// dispatch must be a single argument holding a Lua expression.
///
/// The `splitratio` message itself has two traps, both of which produce a
/// layout that is silently wrong rather than an obvious one:
///
///   * ARGUMENT ORDER. 0.56 parses `ARGS[1]` as the delta and only then tests
///     `ARGS[2]` for `exact`, so the value comes FIRST. The pre-0.56 spelling
///     `splitratio exact 0.75` now fails outright with
///     `failed to parse "exact" as a delta`.
///   * THE VALUE IS NOT A FRACTION. Dwindle sizes the first child as
///     `box.w / 2 * splitRatio`, so the ratio that gives the editor 75% of the
///     width is 1.5; 0.75 would ask for a 37.5% column. The accepted range is
///     0.1 to 1.9, i.e. 5% to 95%.
fn arrange_active_workspace() -> Result<()> {
    hyprctl(&["dispatch", "hl.dsp.focus({ direction = 'left' })"])?;
    hyprctl(&["dispatch", "hl.dsp.focus({ direction = 'left' })"])?;
    hyprctl(&["dispatch", "hl.dsp.layout('splitratio 1.5 exact')"])?;
    Ok(())
}

/// Run a hyprctl command and check for errors.
fn hyprctl(args: &[&str]) -> Result<()> {
    hyprctl_stdout(args).map(|_| ())
}

/// Run a hyprctl command, check for errors, and return its stdout.
///
/// hyprctl reports Lua evaluation failures on STDOUT with an `error:` prefix
/// (and exits 7), so both the exit status and the output are inspected.
fn hyprctl_stdout(args: &[&str]) -> Result<String> {
    let output = Command::new("hyprctl")
        .args(args)
        .output()
        .context("Failed to run hyprctl")?;

    let stdout = String::from_utf8_lossy(&output.stdout).into_owned();

    if !output.status.success() || stdout.trim_start().starts_with("error:") {
        let stderr = String::from_utf8_lossy(&output.stderr);
        let detail = if stdout.trim().is_empty() {
            stderr.trim().to_string()
        } else {
            stdout.trim().to_string()
        };
        anyhow::bail!("hyprctl {} failed: {}", args.join(" "), detail);
    }

    Ok(stdout)
}

// ── Lua and RE2 quoting ───────────────────────────────────────────────

/// Wrap `text` in a Lua long-bracket string at level 2: `[==[ … ]==]`.
///
/// Long brackets are used rather than quotes because the values here are RE2
/// patterns full of backslashes, and a long bracket applies no escaping at all
/// — what is written is what RE2 receives. Level 2 rather than the bare `[[ ]]`
/// so that content containing `]` or `]]` (a plausible thing for a folder name
/// to contain, and the case the previous helper got wrong) needs no thought: a
/// level-2 string is closed only by the exact sequence `]==]`.
fn lua_string(text: &str) -> Result<String> {
    ensure!(
        !text.contains("]==]"),
        "Cannot embed ']==]' in a Lua long-bracket string: {text}"
    );
    // Lua discards a newline immediately after the opening bracket, which would
    // silently change the value.
    ensure!(
        !text.starts_with('\n'),
        "Cannot embed a leading newline in a Lua long-bracket string: {text}"
    );

    Ok(format!("[==[{text}]==]"))
}

/// Escape RE2 metacharacters so `text` matches itself literally.
///
/// A project folder name is user data: `my.app`, `client (2024)`, `v1+fix` and
/// `[wip]` are all legal directory names and all contain metacharacters. Left
/// unescaped, `my.app` would also match `myXapp`, and `[wip]` would compile to
/// a character class that matches a single letter — or fail to compile at all,
/// which Hyprland's rule parser reports by silently never matching.
///
/// Only the true metacharacters are escaped, and only ASCII ones: RE2 accepts a
/// backslash before any ASCII punctuation but rejects it before a non-ASCII
/// character, so anything outside ASCII is passed through untouched.
fn re2_escape(text: &str) -> String {
    const META: &str = r"\.+*?()|[]{}^$";

    let mut escaped = String::with_capacity(text.len());
    for ch in text.chars() {
        if META.contains(ch) {
            escaped.push('\\');
        }
        escaped.push(ch);
    }
    escaped
}

// ── User-visible messages ─────────────────────────────────────────────

enum Urgency {
    Normal,
    Critical,
}

/// Print a warning and put it on screen.
fn warn(message: &str) {
    println!("{} {}", "Warning:".yellow(), message.yellow());
    notify(Urgency::Normal, "dev-layout", message);
}

/// Put `message` on screen, because stdout and stderr go nowhere.
///
/// Hyprland dup2()s /dev/null over both streams of anything it execs, so a
/// binary launched from a keybind cannot report anything by printing. Best
/// effort by design: a missing notification daemon must never turn into a
/// second failure on top of the one being reported.
fn notify(urgency: Urgency, summary: &str, body: &str) {
    let level = match urgency {
        Urgency::Normal => "normal",
        Urgency::Critical => "critical",
    };

    let sent = Command::new("notify-send")
        .args(["--app-name", "dev-layout", "--urgency", level, summary, body])
        .stdout(Stdio::null())
        .stderr(Stdio::null())
        .status()
        .map(|status| status.success())
        .unwrap_or(false);

    if sent {
        return;
    }

    // No notification daemon (or no libnotify): fall back to Hyprland's own
    // on-screen notification. -1 is "no icon", 0 is the default colour.
    let text = format!("{summary}: {body}");
    let _ = Command::new("hyprctl")
        .args(["notify", "-1", "6000", "0", text.as_str()])
        .stdout(Stdio::null())
        .stderr(Stdio::null())
        .status();
}
