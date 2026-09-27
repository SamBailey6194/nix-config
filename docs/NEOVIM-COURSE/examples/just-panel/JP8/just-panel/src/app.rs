//! The panel's state, and what each key press does to it.
//!
//! Nothing in here draws or touches the terminal: `handle_key` only changes
//! the state and tells the event loop what to do next. That keeps every key
//! testable without a terminal (lesson 17).

use std::collections::BTreeMap;
use std::fmt;
use std::process::ExitStatus;

use ratatui::crossterm::event::{KeyCode, KeyEvent, KeyModifiers};
use ratatui::widgets::ListState;

use crate::justfile::Recipe;
use crate::runner;
use crate::sections::Section;

/// A recipe, and the banner it sits under in the justfile.
#[derive(Debug)]
pub struct Entry {
    pub section: Option<String>,
    pub recipe: Recipe,
}

impl Entry {
    /// Whether the name or description contains `filter`, which must already
    /// be lower case.
    fn matches(&self, filter: &str) -> bool {
        let doc = self.recipe.doc.as_deref().unwrap_or_default();
        self.recipe.name.to_lowercase().contains(filter) || doc.to_lowercase().contains(filter)
    }
}

/// One line of the recipe list.
#[derive(Debug, PartialEq, Eq)]
pub enum Row {
    /// A section's title. The selection never rests on one.
    Header(String),
    /// A recipe, as an index into `App::entries`.
    Recipe(usize),
}

/// What the keys do at the moment.
#[derive(Debug, Default, PartialEq, Eq)]
pub enum Mode {
    /// Moving around the list.
    #[default]
    Normal,
    /// Typing a filter after `/`.
    Filter,
    /// The `?` popup is open.
    Help,
    /// Asking for the parameters of the recipe about to run.
    Prompt(Prompt),
    /// Waiting for `y` before running something that deserves a second look.
    Confirm(Confirm),
}

/// The parameter prompt: one text field per parameter of `entries[entry]`.
#[derive(Debug, PartialEq, Eq)]
pub struct Prompt {
    pub entry: usize,
    pub values: Vec<String>,
    /// The field that typing goes into.
    pub focus: usize,
    /// Why the last Enter did not run the recipe.
    pub error: Option<String>,
}

/// A run waiting for confirmation, and the reasons for asking.
#[derive(Debug, PartialEq, Eq)]
pub struct Confirm {
    pub run: Run,
    pub reasons: Vec<String>,
}

/// A recipe for the event loop to run.
#[derive(Debug, PartialEq, Eq)]
pub struct Run {
    pub recipe: String,
    pub args: Vec<String>,
    /// Pass `--yes`: the panel has already asked the recipe's `[confirm]`
    /// question, so just should not ask it a second time.
    pub yes: bool,
}

/// Writes the run the way you would type it, e.g. `just rebuild --boot`.
impl fmt::Display for Run {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "just {}", self.recipe)?;
        for arg in &self.args {
            write!(f, " {arg}")?;
        }
        Ok(())
    }
}

/// How the last run ended, for the status line.
#[derive(Debug, PartialEq, Eq)]
pub struct LastRun {
    pub recipe: String,
    /// `None` when just was killed by a signal instead of exiting.
    pub code: Option<i32>,
}

/// What the event loop should do after a key press.
#[derive(Debug, PartialEq, Eq)]
pub enum Action {
    Quit,
    /// Step aside and run a recipe in the real terminal.
    Run(Run),
}

/// Everything the panel knows and shows.
pub struct App {
    /// Every public recipe, in source order.
    pub entries: Vec<Entry>,
    /// The list as shown: recipes that match the filter, under their
    /// section headers.
    pub rows: Vec<Row>,
    /// The selected row, and how far the list has scrolled. ratatui updates
    /// the scroll offset while drawing, so this has to outlive a frame.
    pub list: ListState,
    pub mode: Mode,
    /// Text that a recipe's name or description must contain, in any case.
    pub filter: String,
    pub last_run: Option<LastRun>,
}

impl App {
    /// Puts the recipes from `just --dump` into the order and sections of the
    /// justfile's source, leaving out private ones as `just --list` does.
    pub fn new(recipes: Vec<Recipe>, sections: Vec<Section>) -> Self {
        let mut by_name: BTreeMap<String, Recipe> = recipes
            .into_iter()
            .filter(|recipe| !recipe.private)
            .map(|recipe| (recipe.name.clone(), recipe))
            .collect();
        let mut entries = Vec::new();
        for section in sections {
            for name in section.recipes {
                if let Some(recipe) = by_name.remove(&name) {
                    let section = section.title.clone();
                    entries.push(Entry { section, recipe });
                }
            }
        }
        // Anything the banner parser missed (a recipe from an `import`, say)
        // still belongs in the panel, so list it last rather than drop it.
        entries.extend(by_name.into_values().map(|recipe| Entry {
            section: Some("Other".to_string()),
            recipe,
        }));

        let mut app = Self {
            entries,
            rows: Vec::new(),
            list: ListState::default(),
            mode: Mode::Normal,
            filter: String::new(),
            last_run: None,
        };
        app.refresh();
        app
    }

    /// The selected recipe; `None` when no recipe matches the filter.
    pub fn selected(&self) -> Option<&Entry> {
        self.selected_index().map(|index| &self.entries[index])
    }

    /// Records how a run ended, for the status line.
    pub fn finished(&mut self, recipe: String, status: ExitStatus) {
        let code = status.code();
        self.last_run = Some(LastRun { recipe, code });
    }

    /// Updates the state for one key press.
    pub fn handle_key(&mut self, key: KeyEvent) -> Option<Action> {
        // In raw mode Ctrl+C arrives as an ordinary key press rather than as
        // a signal, so quitting on it is up to us.
        if key.modifiers.contains(KeyModifiers::CONTROL) && key.code == KeyCode::Char('c') {
            return Some(Action::Quit);
        }
        // Other keys count only without Ctrl or Alt: crossterm reports
        // Ctrl+Q as a `q` with the CONTROL modifier, and Ctrl+Q is not `q`.
        let ctrl_or_alt = KeyModifiers::CONTROL | KeyModifiers::ALT;
        if key.modifiers.intersects(ctrl_or_alt) {
            return None;
        }
        match self.mode {
            Mode::Normal => return self.normal_key(key),
            Mode::Filter => self.filter_key(key),
            // Any key closes the help.
            Mode::Help => self.mode = Mode::Normal,
            Mode::Prompt(_) => return self.prompt_key(key),
            Mode::Confirm(_) => return self.confirm_key(key),
        }
        None
    }

    fn normal_key(&mut self, key: KeyEvent) -> Option<Action> {
        match key.code {
            KeyCode::Char('q') => return Some(Action::Quit),
            // Esc backs out of a kept filter before it quits.
            KeyCode::Esc if !self.filter.is_empty() => {
                self.filter.clear();
                self.refresh();
            }
            KeyCode::Esc => return Some(Action::Quit),
            KeyCode::Char('j') | KeyCode::Down => self.select_next(),
            KeyCode::Char('k') | KeyCode::Up => self.select_previous(),
            KeyCode::Char('g') => self.select_first(),
            KeyCode::Char('G') => self.select_last(),
            KeyCode::Enter => return self.begin(),
            KeyCode::Char('/') => self.mode = Mode::Filter,
            KeyCode::Char('?') => self.mode = Mode::Help,
            _ => {}
        }
        None
    }

    fn filter_key(&mut self, key: KeyEvent) {
        match key.code {
            // Enter keeps the filter and goes back to moving around.
            KeyCode::Enter => self.mode = Mode::Normal,
            KeyCode::Esc => {
                self.mode = Mode::Normal;
                self.filter.clear();
                self.refresh();
            }
            KeyCode::Backspace => {
                self.filter.pop();
                self.refresh();
            }
            KeyCode::Char(c) => {
                self.filter.push(c);
                self.refresh();
            }
            _ => {}
        }
    }

    fn prompt_key(&mut self, key: KeyEvent) -> Option<Action> {
        let Mode::Prompt(prompt) = &mut self.mode else {
            return None;
        };
        let fields = prompt.values.len();
        match key.code {
            KeyCode::Esc => self.mode = Mode::Normal,
            KeyCode::Tab | KeyCode::Down => prompt.focus = (prompt.focus + 1) % fields,
            KeyCode::BackTab | KeyCode::Up => prompt.focus = (prompt.focus + fields - 1) % fields,
            KeyCode::Backspace => {
                prompt.values[prompt.focus].pop();
            }
            KeyCode::Char(c) => prompt.values[prompt.focus].push(c),
            KeyCode::Enter => {
                let parameters = &self.entries[prompt.entry].recipe.parameters;
                match runner::arguments(parameters, &prompt.values) {
                    Ok(args) => {
                        let entry = prompt.entry;
                        return self.start(entry, args);
                    }
                    Err(error) => prompt.error = Some(error),
                }
            }
            _ => {}
        }
        None
    }

    fn confirm_key(&mut self, key: KeyEvent) -> Option<Action> {
        match key.code {
            // Not Enter: Enter opened this dialog, and pressing it twice
            // must not be enough to run a sudo recipe by accident.
            KeyCode::Char('y') => {
                if let Mode::Confirm(confirm) = std::mem::take(&mut self.mode) {
                    return Some(Action::Run(confirm.run));
                }
            }
            KeyCode::Char('n') | KeyCode::Esc => self.mode = Mode::Normal,
            _ => {}
        }
        None
    }

    /// Enter on a recipe: ask for its parameters first if it has any.
    fn begin(&mut self) -> Option<Action> {
        let index = self.selected_index()?;
        let parameters = &self.entries[index].recipe.parameters;
        if parameters.is_empty() {
            return self.start(index, Vec::new());
        }
        // Plain-string defaults start out typed in, so what you see is what
        // runs. Clear a trailing one to leave it to just.
        let values = parameters
            .iter()
            .map(|parameter| parameter.literal_default().unwrap_or_default().to_string())
            .collect();
        self.mode = Mode::Prompt(Prompt {
            entry: index,
            values,
            focus: 0,
            error: None,
        });
        None
    }

    /// Runs `entries[index]` with `args`, unless `runner::cautions` finds a
    /// reason to ask first.
    fn start(&mut self, index: usize, args: Vec<String>) -> Option<Action> {
        let recipe = &self.entries[index].recipe;
        let reasons = runner::cautions(recipe);
        let run = Run {
            recipe: recipe.name.clone(),
            args,
            yes: recipe.confirm_prompt().is_some(),
        };
        if reasons.is_empty() {
            // Close the prompt, if it is open, so the panel comes back to
            // the list after the run.
            self.mode = Mode::Normal;
            return Some(Action::Run(run));
        }
        self.mode = Mode::Confirm(Confirm { run, reasons });
        None
    }

    /// Rebuilds the rows from the filter: matching recipes in source order,
    /// with each section's title above its first match. The selection stays
    /// on the same recipe if it still matches, and moves to the first match
    /// if not.
    fn refresh(&mut self) {
        let selected = self.selected_index();
        let filter = self.filter.to_lowercase();
        self.rows.clear();
        let mut section = None;
        for (index, entry) in self.entries.iter().enumerate() {
            if !entry.matches(&filter) {
                continue;
            }
            if entry.section.as_deref() != section {
                section = entry.section.as_deref();
                if let Some(title) = section {
                    self.rows.push(Row::Header(title.to_string()));
                }
            }
            self.rows.push(Row::Recipe(index));
        }

        let row =
            selected.and_then(|index| self.rows.iter().position(|row| *row == Row::Recipe(index)));
        match row {
            Some(row) => self.list.select(Some(row)),
            None => self.select_first(),
        }
    }

    /// The index into `entries` of the selected recipe.
    fn selected_index(&self) -> Option<usize> {
        match self.list.selected().and_then(|row| self.rows.get(row)) {
            Some(Row::Recipe(index)) => Some(*index),
            _ => None,
        }
    }

    /// The rows the selection may rest on: recipes, never headers.
    ///
    /// Moving is done by hand rather than with `ListState::select_next` and
    /// friends: those do not know how long the list is until it is drawn, so
    /// until then `selected()` could point past the last recipe.
    fn selectable(&self) -> impl DoubleEndedIterator<Item = usize> + '_ {
        self.rows
            .iter()
            .enumerate()
            .filter_map(|(row, kind)| matches!(kind, Row::Recipe(_)).then_some(row))
    }

    fn select_first(&mut self) {
        let first = self.selectable().next();
        self.list.select(first);
    }

    fn select_last(&mut self) {
        let last = self.selectable().next_back();
        self.list.select(last);
    }

    fn select_next(&mut self) {
        let current = self.list.selected();
        let next = self.selectable().find(|&row| Some(row) > current);
        self.list.select(next.or(current));
    }

    fn select_previous(&mut self) {
        let current = self.list.selected();
        let previous = self.selectable().rev().find(|&row| Some(row) < current);
        self.list.select(previous.or(current));
    }
}

#[cfg(test)]
pub mod tests {
    use std::os::unix::process::ExitStatusExt;

    use super::*;

    /// The panel for the course's demo justfile, built from the compiled-in
    /// fixtures: no `just`, no terminal, no files read at run time.
    pub fn demo() -> App {
        let recipes = crate::justfile::parse(include_str!("../tests/fixtures/dump.json"));
        let sections = crate::sections::parse(include_str!("../tests/fixtures/justfile"));
        App::new(recipes.unwrap(), sections)
    }

    pub fn press(app: &mut App, code: KeyCode) -> Option<Action> {
        app.handle_key(KeyEvent::new(code, KeyModifiers::NONE))
    }

    /// Presses each character of `keys` in turn, returning the last action.
    pub fn type_keys(app: &mut App, keys: &str) -> Option<Action> {
        let mut action = None;
        for c in keys.chars() {
            action = press(app, KeyCode::Char(c));
        }
        action
    }

    fn selected(app: &App) -> &str {
        &app.selected().unwrap().recipe.name
    }

    fn visible(app: &App) -> Vec<String> {
        app.rows
            .iter()
            .map(|row| match row {
                Row::Header(title) => format!("# {title}"),
                Row::Recipe(index) => app.entries[*index].recipe.name.clone(),
            })
            .collect()
    }

    #[test]
    fn lists_public_recipes_in_source_order_under_headers() {
        let app = demo();
        let rows = visible(&app);
        assert_eq!(
            rows[..4],
            [
                "default",
                "# Secrets Management",
                "edit-secret",
                "rekey-secrets"
            ]
        );
        assert!(
            !rows.contains(&"_stamp".to_string()),
            "private recipes are hidden"
        );
        assert_eq!(selected(&app), "default");
    }

    #[test]
    fn moving_skips_headers_and_stops_at_the_ends() {
        let mut app = demo();
        type_keys(&mut app, "j");
        assert_eq!(selected(&app), "edit-secret");
        type_keys(&mut app, "kk");
        assert_eq!(selected(&app), "default");
        type_keys(&mut app, "G");
        assert_eq!(selected(&app), "snapshot");
        press(&mut app, KeyCode::Down);
        assert_eq!(selected(&app), "snapshot");
        type_keys(&mut app, "g");
        assert_eq!(selected(&app), "default");
    }

    #[test]
    fn filter_keeps_matching_recipes_under_their_headers() {
        let mut app = demo();
        type_keys(&mut app, "/LINT");
        assert_eq!(app.mode, Mode::Filter);
        assert_eq!(
            visible(&app),
            ["# Development", "lint", "lint-rust", "lint-nix"]
        );
        assert_eq!(selected(&app), "lint");

        press(&mut app, KeyCode::Enter);
        assert_eq!(app.mode, Mode::Normal);
        assert_eq!(app.filter, "LINT", "Enter keeps the filter");
        type_keys(&mut app, "j");

        assert_eq!(
            press(&mut app, KeyCode::Esc),
            None,
            "Esc clears before it quits"
        );
        assert!(app.filter.is_empty());
        assert_eq!(
            selected(&app),
            "lint-rust",
            "the selection survives clearing"
        );
        assert_eq!(press(&mut app, KeyCode::Esc), Some(Action::Quit));
    }

    #[test]
    fn a_filter_can_match_the_description() {
        let mut app = demo();
        type_keys(&mut app, "/screen");
        assert_eq!(visible(&app), ["# Session Control", "lock"]);
        type_keys(&mut app, "zzz");
        assert!(app.rows.is_empty());
        assert!(app.selected().is_none());
        press(&mut app, KeyCode::Esc);
        assert_eq!(app.mode, Mode::Normal);
        assert_eq!(selected(&app), "default");
    }

    #[test]
    fn help_closes_on_any_key_and_quitting_works_everywhere() {
        let mut app = demo();
        type_keys(&mut app, "?");
        assert_eq!(app.mode, Mode::Help);
        assert_eq!(type_keys(&mut app, "q"), None, "q only closes the help");
        assert_eq!(app.mode, Mode::Normal);

        type_keys(&mut app, "/li");
        let ctrl_c = KeyEvent::new(KeyCode::Char('c'), KeyModifiers::CONTROL);
        assert_eq!(app.handle_key(ctrl_c), Some(Action::Quit));
        assert_eq!(type_keys(&mut demo(), "q"), Some(Action::Quit));
    }

    #[test]
    fn keys_with_ctrl_or_alt_are_not_plain_keys() {
        let mut app = demo();
        type_keys(&mut app, "/lint");
        let ctrl_u = KeyEvent::new(KeyCode::Char('u'), KeyModifiers::CONTROL);
        assert_eq!(app.handle_key(ctrl_u), None);
        assert_eq!(app.filter, "lint", "Ctrl+U types nothing");

        press(&mut app, KeyCode::Enter);
        let ctrl_q = KeyEvent::new(KeyCode::Char('q'), KeyModifiers::CONTROL);
        assert_eq!(app.handle_key(ctrl_q), None, "Ctrl+Q does not quit");
        let alt_j = KeyEvent::new(KeyCode::Char('j'), KeyModifiers::ALT);
        app.handle_key(alt_j);
        assert_eq!(selected(&app), "lint", "Alt+J does not move");
    }

    #[test]
    fn enter_runs_a_recipe_without_parameters_at_once() {
        let mut app = demo();
        type_keys(&mut app, "/check");
        press(&mut app, KeyCode::Enter);
        let run = press(&mut app, KeyCode::Enter);
        let expected = Run {
            recipe: "check".to_string(),
            args: Vec::new(),
            yes: false,
        };
        assert_eq!(run, Some(Action::Run(expected)));
    }

    #[test]
    fn the_prompt_starts_with_defaults_and_runs_what_was_typed() {
        let mut app = demo();
        type_keys(&mut app, "/fuzz");
        press(&mut app, KeyCode::Enter);
        press(&mut app, KeyCode::Enter);
        let Mode::Prompt(prompt) = &app.mode else {
            panic!("expected the prompt, got {:?}", app.mode);
        };
        assert_eq!(prompt.values, ["", "5"]);

        type_keys(&mut app, "demo");
        let Some(Action::Run(run)) = press(&mut app, KeyCode::Enter) else {
            panic!("expected a run");
        };
        assert_eq!(run.to_string(), "just fuzz demo 5");
        assert_eq!(app.mode, Mode::Normal, "the prompt closes");
    }

    #[test]
    fn a_blank_required_parameter_keeps_the_prompt_open() {
        let mut app = demo();
        type_keys(&mut app, "/edit");
        press(&mut app, KeyCode::Enter);
        press(&mut app, KeyCode::Enter);
        assert_eq!(press(&mut app, KeyCode::Enter), None);
        let Mode::Prompt(prompt) = &app.mode else {
            panic!("expected the prompt, got {:?}", app.mode);
        };
        assert_eq!(prompt.error.as_deref(), Some("SECRET is required"));
    }

    #[test]
    fn sudo_recipes_wait_for_y() {
        let mut app = demo();
        type_keys(&mut app, "/rebuild");
        press(&mut app, KeyCode::Enter);
        press(&mut app, KeyCode::Enter);
        type_keys(&mut app, "--boot");
        assert_eq!(press(&mut app, KeyCode::Enter), None);
        let Mode::Confirm(confirm) = &app.mode else {
            panic!("expected a confirmation, got {:?}", app.mode);
        };
        assert_eq!(confirm.run.to_string(), "just rebuild --boot");
        assert!(confirm.reasons[0].starts_with("uses sudo"));

        assert_eq!(press(&mut app, KeyCode::Enter), None, "Enter is not yes");
        assert_eq!(type_keys(&mut app, "n"), None);
        assert_eq!(app.mode, Mode::Normal);
    }

    #[test]
    fn a_confirm_attribute_is_asked_once_then_passed_on_as_yes() {
        let mut app = demo();
        type_keys(&mut app, "/update");
        press(&mut app, KeyCode::Enter);
        press(&mut app, KeyCode::Enter);
        let Some(Action::Run(run)) = type_keys(&mut app, "y") else {
            panic!("expected a run after y");
        };
        assert!(run.yes);
        assert_eq!(app.mode, Mode::Normal);
    }

    #[test]
    fn finished_records_the_exit_code() {
        let mut app = demo();
        // A raw wait status holds the exit code in its second byte.
        app.finished("fuzz".to_string(), ExitStatus::from_raw(130 << 8));
        let expected = LastRun {
            recipe: "fuzz".to_string(),
            code: Some(130),
        };
        assert_eq!(app.last_run, Some(expected));
    }
}
