//! Drawing the panel with ratatui.
//!
//! Everything here reads the `App` and draws it; the only thing drawing
//! changes is the list's scroll offset, which ratatui keeps in the
//! `ListState`. So a whole screen can be drawn into ratatui's in-memory
//! `TestBackend` and checked in a test (lesson 17).

use ratatui::layout::{Constraint, Layout, Rect};
use ratatui::style::{Style, Stylize};
use ratatui::text::Line;
use ratatui::widgets::{Block, Clear, List, ListItem, Paragraph, Wrap};
use ratatui::Frame;

use crate::app::{App, Confirm, Entry, Mode, Prompt, Row};
use crate::justfile::{Parameter, ParameterKind, Recipe};

/// Draws the whole screen: the recipes on the left, the selected recipe on
/// the right, a status line along the bottom, and any popup over the top.
pub fn render(frame: &mut Frame, app: &mut App) {
    let [main, status] =
        Layout::vertical([Constraint::Min(0), Constraint::Length(1)]).areas(frame.area());
    let [list, detail] =
        Layout::horizontal([Constraint::Percentage(35), Constraint::Min(0)]).areas(main);
    render_list(frame, list, app);
    render_detail(frame, detail, app.selected());
    render_status(frame, status, app);
    match &app.mode {
        Mode::Help => render_help(frame),
        Mode::Prompt(prompt) => render_prompt(frame, &app.entries[prompt.entry].recipe, prompt),
        Mode::Confirm(confirm) => render_confirm(frame, confirm),
        Mode::Normal | Mode::Filter => {}
    }
}

fn render_list(frame: &mut Frame, area: Rect, app: &mut App) {
    let items: Vec<ListItem> = app
        .rows
        .iter()
        .map(|row| match row {
            Row::Header(title) => ListItem::new(Line::from(title.as_str()).bold().cyan()),
            Row::Recipe(index) => ListItem::new(format!("  {}", app.entries[*index].recipe.name)),
        })
        .collect();
    let title = if app.filter.is_empty() {
        " Recipes ".to_string()
    } else {
        format!(" Recipes (filter: {}) ", app.filter)
    };
    let list = List::new(items)
        .block(Block::bordered().title(title))
        .highlight_style(Style::new().reversed())
        .highlight_symbol("> ")
        // Keep a row of context above and below the selection while
        // scrolling, so the header over a section's first recipe stays in view.
        .scroll_padding(1);
    frame.render_stateful_widget(list, area, &mut app.list);
}

fn render_detail(frame: &mut Frame, area: Rect, entry: Option<&Entry>) {
    let block = Block::bordered().title(" Recipe ");
    let Some(Entry { section, recipe }) = entry else {
        frame.render_widget(
            Paragraph::new("No recipe matches the filter").block(block),
            area,
        );
        return;
    };

    let mut lines = vec![
        Line::from(recipe.signature()).bold(),
        Line::from(recipe.doc.clone().unwrap_or_default()),
        Line::default(),
    ];
    if let Some(section) = section {
        lines.push(field("Section", section));
    }
    if let Some(group) = recipe.group() {
        lines.push(field("Group", group));
    }
    if !recipe.dependencies.is_empty() {
        let names: Vec<&str> = recipe
            .dependencies
            .iter()
            .map(|dependency| dependency.recipe.as_str())
            .collect();
        lines.push(field("Runs first", &names.join(", ")));
    }
    if let Some(prompt) = recipe.confirm_prompt() {
        lines.push(field("Confirm", &prompt));
    }
    if recipe.needs_sudo() {
        lines.push(Line::from("Uses sudo: expect a password prompt").yellow());
    }
    if !recipe.parameters.is_empty() {
        lines.push(Line::default());
        for parameter in &recipe.parameters {
            lines.push(field(&parameter.name, &describe(parameter)));
        }
    }
    lines.push(Line::default());
    for line in recipe.body_lines() {
        lines.push(line.dim().into());
    }

    let detail = Paragraph::new(lines)
        .block(block)
        .wrap(Wrap { trim: false });
    frame.render_widget(detail, area);
}

fn render_status(frame: &mut Frame, area: Rect, app: &App) {
    if app.mode == Mode::Filter {
        let line = Line::from(format!("/{}", app.filter));
        // A visible cursor after the text shows that typing goes here.
        frame.set_cursor_position((area.x + line.width() as u16, area.y));
        frame.render_widget(line, area);
        return;
    }
    let mut status = Vec::new();
    if let Some(last) = &app.last_run {
        let outcome = match last.code {
            Some(code) => format!("{}: exit {code}", last.recipe),
            None => format!("{}: killed by a signal", last.recipe),
        };
        status.push(if last.code == Some(0) {
            outcome.green()
        } else {
            outcome.red()
        });
        status.push("  ".into());
    }
    status.push("Enter run · / filter · ? help · q quit".dim());
    frame.render_widget(Line::from(status), area);
}

/// The keys, as the `?` popup lists them.
const KEYS: &[(&str, &str)] = &[
    ("j  Down", "next recipe"),
    ("k  Up", "previous recipe"),
    ("g  G", "first / last recipe"),
    ("Enter", "run the selected recipe"),
    ("/", "filter; Enter keeps it, Esc clears it"),
    ("Esc", "clear the filter, or quit"),
    ("?", "this help"),
    ("q  Ctrl+C", "quit"),
];

fn render_help(frame: &mut Frame) {
    let lines: Vec<Line> = KEYS.iter().map(|(keys, what)| field(keys, what)).collect();
    // As wide as the longest line, plus the border on each side.
    let width = lines.iter().map(Line::width).max().unwrap_or_default() + 2;
    let area = popup(frame.area(), width as u16, lines.len());
    let help = Paragraph::new(lines).block(
        Block::bordered()
            .title(" Keys ")
            .title_bottom(" any key closes "),
    );
    // Blank the cells underneath first, or the list shows through the gaps.
    frame.render_widget(Clear, area);
    frame.render_widget(help, area);
}

/// One field per parameter, each with a hint, and the cursor in the field
/// being typed into.
fn render_prompt(frame: &mut Frame, recipe: &Recipe, prompt: &Prompt) {
    let label_width = recipe.parameters.iter().map(|p| p.name.len()).max();
    let label_width = label_width.unwrap_or_default() + 2;
    // What fits of a value: the popup, less its border, the label, the
    // space after the label and a column for the cursor.
    let width = frame.area().width.min(64);
    let room = usize::from(width).saturating_sub(label_width + 4);
    let mut lines = vec![
        Line::from(recipe.doc.clone().unwrap_or_default()),
        Line::default(),
    ];
    let mut cursor = (0, 0);
    for (index, (parameter, value)) in recipe.parameters.iter().zip(&prompt.values).enumerate() {
        let label = format!("{:<label_width$}", parameter.name);
        let line = if index == prompt.focus {
            // Typing happens at the end, so that is the part to show.
            let value = tail(value, room);
            let line = Line::from(vec![label.reversed(), " ".into(), value.into()]);
            cursor = (line.width(), lines.len());
            line
        } else {
            Line::from(vec![label.bold(), " ".into(), value.clone().into()])
        };
        lines.push(line);
        let hint = format!("{:label_width$} {}", "", describe(parameter));
        lines.push(hint.dim().into());
    }
    lines.push(Line::default());
    lines.push(match &prompt.error {
        Some(error) => error.clone().red().into(),
        None => "Tab next field · Enter run · Esc cancel".dim().into(),
    });

    let area = popup(frame.area(), width, lines.len());
    let title = format!(" just {} ", recipe.name);
    frame.render_widget(Clear, area);
    frame.render_widget(
        Paragraph::new(lines).block(Block::bordered().title(title)),
        area,
    );
    // Inside the border: one column in, one row down.
    let (x, y) = cursor;
    frame.set_cursor_position((area.x + 1 + x as u16, area.y + 1 + y as u16));
}

/// The run that is waiting, why the panel is asking, and the keys to answer.
fn render_confirm(frame: &mut Frame, confirm: &Confirm) {
    let mut lines = vec![Line::from(confirm.run.to_string()).bold(), Line::default()];
    for reason in &confirm.reasons {
        lines.push(Line::from(format!("- {reason}")));
    }
    lines.push(Line::default());
    lines.push("y run · n or Esc cancel".dim().into());

    let area = popup(frame.area(), 64, lines.len());
    let block = Block::bordered()
        .title(" Run this? ")
        .border_style(Style::new().yellow());
    frame.render_widget(Clear, area);
    frame.render_widget(Paragraph::new(lines).block(block), area);
}

/// A centred area `width` columns wide and tall enough for `lines` lines
/// inside a border.
fn popup(area: Rect, width: u16, lines: usize) -> Rect {
    let height = Constraint::Length(lines as u16 + 2);
    area.centered(Constraint::Length(width), height)
}

/// The end of `text`: as much of it as fits in `room` columns.
fn tail(text: &str, room: usize) -> &str {
    let mut tail = text;
    while Line::from(tail).width() > room {
        let mut chars = tail.chars();
        chars.next();
        tail = chars.as_str();
    }
    tail
}

/// A `label  value` line, with the label in a column of its own.
fn field(label: &str, value: &str) -> Line<'static> {
    Line::from(vec![
        format!("{label:<12}").bold(),
        value.to_string().into(),
    ])
}

/// How to fill a parameter in, e.g. `default "300"` or `required`.
fn describe(parameter: &Parameter) -> String {
    let mut text = match (&parameter.default, parameter.literal_default()) {
        (Some(_), Some(literal)) => format!("default {literal:?}"),
        (Some(_), None) => "has a default".to_string(),
        (None, _) if parameter.kind == ParameterKind::Star => "optional".to_string(),
        (None, _) => "required".to_string(),
    };
    if parameter.is_variadic() {
        text.push_str(", words separated by spaces");
    }
    text
}

#[cfg(test)]
mod tests {
    use ratatui::backend::TestBackend;
    use ratatui::crossterm::event::KeyCode;
    use ratatui::style::Modifier;
    use ratatui::Terminal;

    use super::*;
    use crate::app::tests::{demo, press, type_keys};

    /// Draws `app` into an in-memory terminal: no TTY needed.
    fn draw(app: &mut App) -> Terminal<TestBackend> {
        let mut terminal = Terminal::new(TestBackend::new(80, 24)).unwrap();
        terminal.draw(|frame| render(frame, app)).unwrap();
        terminal
    }

    /// The screen as text, one quoted row per line. Colours and other
    /// styles are not included.
    fn screen(app: &mut App) -> String {
        draw(app).backend().to_string()
    }

    #[test]
    fn shows_sections_recipes_and_the_selected_recipe() {
        let screen = screen(&mut demo());
        assert!(screen.contains("Secrets Management"));
        assert!(screen.contains("> "), "the selection marker is drawn");
        assert!(screen.contains("Default recipe shows help"));
        assert!(screen.contains("Enter run"));
    }

    /// Text alone cannot show a highlight, so read the style of a cell.
    #[test]
    fn highlights_the_selected_row() {
        let mut app = demo();
        let terminal = draw(&mut app);
        let buffer = terminal.backend().buffer();
        // Row 1 is the first row inside the border, where `default` is.
        assert!(buffer[(1, 1)].modifier.contains(Modifier::REVERSED));
        assert!(!buffer[(1, 2)].modifier.contains(Modifier::REVERSED));
    }

    #[test]
    fn the_filter_narrows_the_list_and_shows_what_was_typed() {
        let mut app = demo();
        type_keys(&mut app, "/lint");
        let screen = screen(&mut app);
        assert!(screen.contains("/lint"));
        assert!(screen.contains("lint-rust"));
        assert!(!screen.contains("rebuild"));
    }

    #[test]
    fn help_lists_the_keys_over_the_list() {
        let mut app = demo();
        type_keys(&mut app, "?");
        let screen = screen(&mut app);
        assert!(screen.contains(" Keys "));
        assert!(screen.contains("run the selected recipe"));
        assert!(
            screen.contains("Enter keeps it, Esc clears it"),
            "the popup fits its longest line"
        );
    }

    #[test]
    fn the_prompt_shows_each_parameter_with_a_hint() {
        let mut app = demo();
        type_keys(&mut app, "G");
        press(&mut app, KeyCode::Enter);
        let screen = screen(&mut app);
        assert!(screen.contains(" just snapshot "));
        assert!(screen.contains("SUBVOL"));
        assert!(screen.contains(r#"default """#));
    }

    /// Typing happens at the end of a value, so a value too long for the
    /// prompt shows its end, with the cursor after it.
    #[test]
    fn a_long_value_shows_its_end_and_the_cursor() {
        let mut app = demo();
        type_keys(&mut app, "G");
        press(&mut app, KeyCode::Enter);
        type_keys(&mut app, &"x".repeat(100));
        type_keys(&mut app, "END");
        let mut terminal = draw(&mut app);
        let cursor = terminal.get_cursor_position().unwrap();
        let buffer = terminal.backend().buffer();
        assert_eq!(buffer[(cursor.x - 1, cursor.y)].symbol(), "D");
        // The prompt is 64 columns wide and centred in 80, so its right
        // border is in column 71.
        assert!(cursor.x < 71, "the cursor stays inside the prompt");
    }

    /// The whole first screen, compared with the committed file in
    /// `src/snapshots/`. After a deliberate change to the layout, review the
    /// new picture with `cargo insta review` (or rerun with
    /// `INSTA_UPDATE=always`) and commit the updated `.snap` file.
    #[test]
    fn main_screen() {
        insta::assert_snapshot!(draw(&mut demo()).backend());
    }
}
