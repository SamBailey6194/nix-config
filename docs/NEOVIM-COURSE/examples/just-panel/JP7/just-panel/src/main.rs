//! just-panel: a terminal control panel for a justfile.
//!
//! Lists the recipes of a justfile under the section banners of the file
//! itself, shows what the selected recipe does, and runs it in the real
//! terminal.
//!
//! MODULES
//!
//!   justfile   what a recipe is, and loading recipes with `just --dump`
//!   sections   which `# ====` banner each recipe sits under
//!   app        the panel's state, and what each key press does to it
//!   ui         drawing that state with ratatui
//!   runner     handing the terminal to a recipe and taking it back

mod app;
mod justfile;
mod runner;
mod sections;
mod ui;

use std::fs;
use std::io;
use std::path::{self, Path, PathBuf};

use anyhow::{Context, Result};
use clap::Parser;
use ratatui::crossterm::event::{self, Event, KeyEventKind};
use ratatui::DefaultTerminal;

use crate::app::{Action, App};

/// A terminal control panel for a justfile.
#[derive(Parser)]
#[command(version)]
struct Cli {
    /// The justfile to load. Its recipes run in its own directory.
    #[arg(short = 'f', long, env = "JUST_JUSTFILE", default_value = "justfile")]
    justfile: PathBuf,
}

fn main() -> Result<()> {
    let cli = Cli::parse();
    // An absolute path gives just a real directory to run recipes in: see
    // `justfile::just_command`. Not `fs::canonicalize`, which also resolves
    // symlinks: for a justfile that home-manager links in from the Nix
    // store, the recipes would then run inside the store, not where `just`
    // itself runs them.
    let justfile = path::absolute(&cli.justfile)?;
    let source = fs::read_to_string(&justfile)
        .with_context(|| format!("cannot read {}", justfile.display()))?;
    let recipes = justfile::load(&justfile)?;
    let mut app = App::new(recipes, sections::parse(&source));

    runner::survive_ctrl_c().context("cannot install the Ctrl+C handler")?;
    // `ratatui::run` switches the terminal to raw mode and the alternate
    // screen, installs a panic hook that switches it back, hands it to the
    // closure, and restores it however the closure ends.
    ratatui::run(|terminal| event_loop(terminal, &mut app, &justfile))?;
    Ok(())
}

/// Draw, wait for a key, update the state, repeat.
fn event_loop(terminal: &mut DefaultTerminal, app: &mut App, justfile: &Path) -> io::Result<()> {
    loop {
        terminal.draw(|frame| ui::render(frame, app))?;
        match event::read()? {
            // Presses only: a terminal that also reports key releases would
            // otherwise move the selection twice per keystroke.
            Event::Key(key) if key.kind == KeyEventKind::Press => match app.handle_key(key) {
                Some(Action::Quit) => return Ok(()),
                Some(Action::Run(run)) => {
                    let status = runner::run_in_terminal(terminal, justfile, &run)?;
                    app.finished(run.recipe, status);
                }
                None => {}
            },
            // Nothing to do for a resize: the next draw picks up the new size.
            _ => {}
        }
    }
}
