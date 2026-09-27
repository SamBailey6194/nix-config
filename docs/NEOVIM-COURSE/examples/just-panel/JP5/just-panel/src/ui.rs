//! Drawing the panel with ratatui.
//!
//! Everything here reads the `App` and draws it; the only thing drawing
//! changes is the list's scroll offset, which ratatui keeps in the
//! `ListState`. So a whole screen can be drawn into ratatui's in-memory
//! `TestBackend` and checked in a test (lesson 17).

use ratatui::layout::{Constraint, Layout, Rect};
use ratatui::style::{Style, Stylize};
use ratatui::text::Line;
use ratatui::widgets::{Block, List, ListItem, Paragraph, Wrap};
use ratatui::Frame;

use crate::app::{App, Entry};
use crate::justfile::{Parameter, ParameterKind};

/// Draws the whole screen: the recipes on the left, the selected recipe on
/// the right, and a line of key hints along the bottom.
pub fn render(frame: &mut Frame, app: &mut App) {
    let [main, status] =
        Layout::vertical([Constraint::Min(0), Constraint::Length(1)]).areas(frame.area());
    let [list, detail] =
        Layout::horizontal([Constraint::Percentage(35), Constraint::Min(0)]).areas(main);
    render_list(frame, list, app);
    render_detail(frame, detail, app.selected());
    render_status(frame, status);
}

fn render_list(frame: &mut Frame, area: Rect, app: &mut App) {
    let items: Vec<ListItem> = app
        .entries
        .iter()
        .map(|entry| ListItem::new(entry.recipe.name.as_str()))
        .collect();
    let list = List::new(items)
        .block(Block::bordered().title(" Recipes "))
        .highlight_style(Style::new().reversed())
        .highlight_symbol("> ");
    frame.render_stateful_widget(list, area, &mut app.list);
}

fn render_detail(frame: &mut Frame, area: Rect, entry: Option<&Entry>) {
    let block = Block::bordered().title(" Recipe ");
    let Some(Entry { section, recipe }) = entry else {
        frame.render_widget(Paragraph::new("No recipes").block(block), area);
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

fn render_status(frame: &mut Frame, area: Rect) {
    let hints = "j/k move · g/G first/last · q quit";
    frame.render_widget(Line::from(hints).dim(), area);
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
