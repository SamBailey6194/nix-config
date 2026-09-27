//! Running a recipe in the real terminal and taking the screen back afterwards.
//!
//! Recipes do not run inside the TUI. `sudo` reads its password from the
//! terminal device itself, editors and `fzf` draw on it, and some recipes
//! print for minutes: they all need the real terminal, in its normal state.
//! So the panel steps aside, lets just have the terminal, and comes back when
//! just exits.

use std::io::{self, stdout, Write};
use std::path::Path;
use std::process::{Command, ExitStatus};
use std::sync::atomic::AtomicBool;
use std::sync::Arc;
use std::time::Duration;

use ratatui::crossterm::event;
use ratatui::crossterm::terminal::{
    disable_raw_mode, enable_raw_mode, EnterAlternateScreen, LeaveAlternateScreen,
};
use ratatui::crossterm::ExecutableCommand;
use ratatui::DefaultTerminal;
use signal_hook::consts::SIGINT;

use crate::app::Run;
use crate::justfile::{self, Parameter, ParameterKind, Recipe};

/// Recipes that deserve a second keypress although the justfile never asks:
/// they end the session you are sitting in, delete something for good, or
/// rewrite secrets or disks. A trailing `*` matches any ending.
///
/// The rule is a table rather than code so that it is easy to extend: when
/// you add a recipe you would hate to run by accident, add its name here.
/// Recipes that run `sudo` or carry `[confirm]` are asked about anyway (see
/// `cautions`), so they need no entry.
const CAUTION: &[(&str, &str)] = &[
    ("lock", "locks the screen"),
    ("sleep", "suspends the machine"),
    ("logout", "ends the Hyprland session"),
    ("clean-*", "deletes build output or old generations"),
    ("fuzz-clean", "deletes fuzzing crashes and corpus"),
    ("rekey-*", "re-encrypts every secret"),
    ("quarantine-delete", "deletes a quarantined file for good"),
    ("restic-prune", "deletes old backup snapshots"),
    ("zfs-pool", "creates a ZFS pool on raw disks"),
    ("raid-create", "builds a RAID array on raw disks"),
    ("raid-fail", "marks a disk in an array as failed"),
    ("raid-remove", "removes a disk from an array"),
    ("install-nixos", "installs NixOS onto a disk"),
    ("gen-hardware", "overwrites hardware-configuration.nix"),
];

/// Every reason to ask before running `recipe`; empty when it can just run.
pub fn cautions(recipe: &Recipe) -> Vec<String> {
    let mut reasons = Vec::new();
    if let Some(prompt) = recipe.confirm_prompt() {
        reasons.push(prompt);
    }
    if recipe.needs_sudo() {
        reasons.push("uses sudo: you will be asked for your password".to_string());
    }
    for (pattern, reason) in CAUTION {
        let matched = match pattern.strip_suffix('*') {
            Some(prefix) => recipe.name.starts_with(prefix),
            None => recipe.name == *pattern,
        };
        if matched {
            reasons.push(reason.to_string());
        }
    }
    reasons
}

/// Turns what was typed into the prompt into just's positional arguments,
/// or explains what is missing.
///
/// - A required `NAME` must not be blank.
/// - `+NAME` needs at least one word and `*NAME` takes any number. Both are
///   split on whitespace, as a shell would split them.
/// - Blank values at the end are left off, so just fills in its own
///   defaults. A blank before a filled-in value is passed as an empty string,
///   because a position cannot be skipped.
pub fn arguments(parameters: &[Parameter], values: &[String]) -> Result<Vec<String>, String> {
    let filled = values
        .iter()
        .rposition(|value| !value.trim().is_empty())
        .map_or(0, |last| last + 1);
    let mut args = Vec::new();
    for (index, (parameter, value)) in parameters.iter().zip(values).enumerate() {
        let value = value.trim();
        match parameter.kind {
            ParameterKind::Singular if value.is_empty() && parameter.default.is_none() => {
                return Err(format!("{} is required", parameter.name));
            }
            ParameterKind::Singular if index < filled => args.push(value.to_string()),
            ParameterKind::Singular => {}
            ParameterKind::Plus if value.is_empty() => {
                return Err(format!("{} needs at least one value", parameter.name));
            }
            ParameterKind::Plus | ParameterKind::Star => {
                args.extend(value.split_whitespace().map(str::to_string));
            }
        }
    }
    Ok(args)
}

/// The `just` invocation for `run`. Each argument is a separate argv entry,
/// so a value with spaces reaches just intact; what the recipe then does with
/// it depends on how its body uses `{{…}}`.
pub fn command(justfile: &Path, run: &Run) -> Command {
    let mut command = justfile::just_command(justfile);
    if run.yes {
        command.arg("--yes");
    }
    command.arg(&run.recipe).args(&run.args);
    command
}

/// Runs `run` in the real terminal, waits for it, and takes the screen back.
///
/// This is ratatui's "spawn vim" recipe, applied to the terminal we already
/// have. Calling `ratatui::restore` and then `ratatui::init` would also get
/// the terminal back, but `init` builds a second `Terminal` and chains
/// another panic hook each time, and the terminal that `ratatui::run` handed
/// us cannot be swapped for a new one anyway.
pub fn run_in_terminal(
    terminal: &mut DefaultTerminal,
    justfile: &Path,
    run: &Run,
) -> io::Result<ExitStatus> {
    // Hand the terminal over: leave the alternate screen so the output lands
    // in the normal scrollback, and leave raw mode so that line editing,
    // password prompts and Ctrl+C work as they do in a shell.
    stdout().execute(LeaveAlternateScreen)?;
    disable_raw_mode()?;
    // Drawing hides the cursor, and a password prompt without one looks hung.
    terminal.show_cursor()?;

    println!("$ {run}");
    // `status` shares our stdin, stdout and stderr with just, and waits.
    let status = command(justfile, run).status();

    // Going straight back to the alternate screen would hide the output
    // before anyone had read it.
    match &status {
        Ok(status) => println!("\n[just-panel] {status}"),
        Err(error) => println!("\n[just-panel] could not run just: {error}"),
    }
    print!("Press Enter to return to just-panel ");
    stdout().flush()?;
    io::stdin().read_line(&mut String::new())?;

    stdout().execute(EnterAlternateScreen)?;
    enable_raw_mode()?;
    // The screen no longer shows what ratatui last drew, so make the next
    // draw repaint all of it.
    terminal.clear()?;
    // Throw away keys that arrived before the run but were not handled yet,
    // such as the second press of a double-tapped Enter. Back in the list
    // they would act at once, and could start the same recipe again.
    while event::poll(Duration::ZERO)? {
        event::read()?;
    }
    status
}

/// Keeps Ctrl+C for the recipe rather than the panel.
///
/// In the TUI, raw mode turns Ctrl+C into an ordinary key press. While a
/// recipe runs, though, the terminal is back in its normal mode, where Ctrl+C
/// sends SIGINT to every process in the terminal's foreground process group:
/// the recipe, just, and just-panel as well. Left alone, that would kill the
/// panel along with the recipe.
///
/// A handler that does nothing fixes that. It must be a handler, not SIG_IGN:
/// an ignored signal stays ignored in every program we start, so Ctrl+C could
/// stop working in recipes (just happens to install its own handler, but the
/// panel should not rely on that), whereas `exec` resets handled signals to
/// their defaults.
///
/// signal-hook is already built into the panel, because crossterm uses it to
/// notice window resizes, so this costs no extra crate. Its handler sets a
/// flag, which nothing needs to read: having a handler at all is the point.
pub fn survive_ctrl_c() -> io::Result<()> {
    signal_hook::flag::register(SIGINT, Arc::new(AtomicBool::new(false)))?;
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    const DUMP: &str = include_str!("../tests/fixtures/dump.json");

    fn recipe(name: &str) -> Recipe {
        let recipes = justfile::parse(DUMP).unwrap();
        recipes.into_iter().find(|r| r.name == name).unwrap()
    }

    fn values(values: &[&str]) -> Vec<String> {
        values.iter().map(|value| value.to_string()).collect()
    }

    #[test]
    fn arguments_follow_the_parameters() {
        let fuzz = recipe("fuzz").parameters;
        assert_eq!(
            arguments(&fuzz, &values(&["demo", "5"])).unwrap(),
            ["demo", "5"]
        );
        assert_eq!(
            arguments(&fuzz, &values(&[" demo ", ""])).unwrap(),
            ["demo"]
        );
        assert_eq!(
            arguments(&fuzz, &values(&["", "5"])).unwrap_err(),
            "TARGET is required"
        );

        let rebuild = recipe("rebuild").parameters;
        assert_eq!(
            arguments(&rebuild, &values(&["--boot  --fast"])).unwrap(),
            ["--boot", "--fast"]
        );
        assert!(arguments(&rebuild, &values(&[""])).unwrap().is_empty());
    }

    #[test]
    fn a_blank_default_before_a_filled_in_value_keeps_its_place() {
        let optional = |name: &str| Parameter {
            name: name.to_string(),
            kind: ParameterKind::Singular,
            default: Some("x".into()),
        };
        let parameters = [optional("A"), optional("B")];
        assert_eq!(
            arguments(&parameters, &values(&["", "b"])).unwrap(),
            ["", "b"]
        );
        assert!(arguments(&parameters, &values(&["", ""]))
            .unwrap()
            .is_empty());
    }

    #[test]
    fn plus_parameters_need_a_value() {
        let files = [Parameter {
            name: "FILES".to_string(),
            kind: ParameterKind::Plus,
            default: None,
        }];
        assert_eq!(
            arguments(&files, &values(&[" "])).unwrap_err(),
            "FILES needs at least one value"
        );
        assert_eq!(arguments(&files, &values(&["a b"])).unwrap(), ["a", "b"]);
    }

    #[test]
    fn cautions_say_why_a_recipe_needs_a_second_look() {
        assert!(cautions(&recipe("check")).is_empty());
        assert_eq!(
            cautions(&recipe("rebuild")),
            ["uses sudo: you will be asked for your password"]
        );
        assert_eq!(
            cautions(&recipe("update")),
            ["Update every flake input? (demo: nothing changes)"]
        );
        assert_eq!(cautions(&recipe("lock")), ["locks the screen"]);
        assert_eq!(
            cautions(&recipe("rekey-secrets")),
            ["re-encrypts every secret"]
        );
        assert_eq!(
            cautions(&recipe("clean-cache")),
            ["deletes build output or old generations"]
        );
    }

    /// Checks the command without running it: `get_args` only reads it back.
    #[test]
    fn yes_goes_before_the_recipe_and_its_arguments_after() {
        let run = Run {
            recipe: "rebuild".to_string(),
            args: values(&["--boot"]),
            yes: true,
        };
        let command = command(Path::new("/demo/justfile"), &run);
        assert_eq!(command.get_program(), "just");
        let args: Vec<_> = command.get_args().collect();
        assert_eq!(
            args,
            [
                "--justfile",
                "/demo/justfile",
                "--working-directory",
                "/demo",
                "--yes",
                "rebuild",
                "--boot"
            ]
        );
    }
}
