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

// Until lesson 14 wires these modules into `main`, nothing calls the code
// they contain, so every type and function would be reported as unused.
// Silence that one lint for the whole crate for now: JP5 deletes this line,
// and from then on the compiler checks again that everything is used.
#![allow(dead_code)]

mod app;
mod justfile;
mod runner;
mod sections;
mod ui;

fn main() {
    println!("Hello, world!");
}
