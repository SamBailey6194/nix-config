//! Section banners: which `# ====` heading each recipe sits under in the source.
//!
//! To just, the banners in a justfile are ordinary comments: they are not in
//! `just --dump`, which also lists recipes alphabetically. The file itself is
//! the only record of how its recipes are grouped and ordered, so this module
//! reads the source text. On the repo's justfile these rules put all 131
//! recipes in the same order as `just --summary --unsorted`.
//!
//! BANNERS
//!
//!   # ==========              a section: a title line between two `=`
//!   # Secrets Management      rulers
//!   # ==========
//!
//!   # Restic Backup           a sub-section: a title line directly above a
//!   # ----------              `-` ruler, inside the section above it

/// A run of recipes under one heading, in source order.
#[derive(Debug, PartialEq, Eq)]
pub struct Section {
    /// `None` for recipes above the first banner. A sub-section is titled
    /// "Section / Sub-section".
    pub title: Option<String>,
    pub recipes: Vec<String>,
}

/// Splits a justfile's source into its sections. Sections without recipes
/// (such as a banner that only holds sub-sections) are left out.
pub fn parse(source: &str) -> Vec<Section> {
    let lines: Vec<&str> = source.lines().collect();
    let mut sections = Vec::new();
    let mut current = Section {
        title: None,
        recipes: Vec::new(),
    };
    // The title of the `=` banner above, which names its sub-sections.
    let mut banner_title = None;

    for (index, line) in lines.iter().enumerate() {
        let title = if let Some(title) = banner(&lines[index..]) {
            banner_title = Some(title);
            Some(title.to_string())
        } else {
            sub_banner(&lines[index..]).map(|title| match banner_title {
                Some(parent) => format!("{parent} / {title}"),
                None => title.to_string(),
            })
        };

        if let Some(title) = title {
            let next = Section {
                title: Some(title),
                recipes: Vec::new(),
            };
            sections.push(std::mem::replace(&mut current, next));
        } else if let Some(name) = recipe_name(line) {
            current.recipes.push(name.to_string());
        }
    }
    sections.push(current);
    sections.retain(|section| !section.recipes.is_empty());
    sections
}

/// The title of a `# ====` / `# Title` / `# ====` banner starting at the
/// first of `lines`.
fn banner<'a>(lines: &[&'a str]) -> Option<&'a str> {
    match lines {
        [open, text, close, ..] if is_ruler(open, '=') && is_ruler(close, '=') => title(text),
        _ => None,
    }
}

/// The title of a `# Title` / `# ----` sub-section banner starting at the
/// first of `lines`.
fn sub_banner<'a>(lines: &[&'a str]) -> Option<&'a str> {
    match lines {
        [text, rule, ..] if is_ruler(rule, '-') => title(text),
        _ => None,
    }
}

/// The text of a comment that starts in the first column.
fn comment(line: &str) -> Option<&str> {
    line.strip_prefix('#').map(str::trim)
}

/// A comment made of one repeated character, like `# ======`.
fn is_ruler(line: &str, ruler: char) -> bool {
    comment(line).is_some_and(|text| text.len() >= 3 && text.chars().all(|c| c == ruler))
}

/// A comment with words in it: not a ruler, and not an empty `#`.
fn title(line: &str) -> Option<&str> {
    comment(line).filter(|text| text.chars().any(char::is_alphanumeric))
}

/// The name of the recipe that `line` starts, if it is a recipe header such
/// as `fuzz TARGET TIME="300":` or `@quiet:`.
///
/// A header starts in the first column, and its first word, the name, comes
/// before a `:`. Indented lines belong to a recipe body, and a `:=` marks an
/// assignment, an `alias` or a `set` line instead.
fn recipe_name(line: &str) -> Option<&str> {
    if line.starts_with(char::is_whitespace) || line.contains(":=") {
        return None;
    }
    let (header, _) = line.split_once(':')?;
    let name = header.trim_start_matches('@').split_whitespace().next()?;
    name.chars()
        .all(|c| c.is_alphanumeric() || c == '_' || c == '-')
        .then_some(name)
}

#[cfg(test)]
mod tests {
    use super::*;

    /// The course's demo justfile, compiled in like the dump.
    const JUSTFILE: &str = include_str!("../tests/fixtures/justfile");
    const DUMP: &str = include_str!("../tests/fixtures/dump.json");

    fn names(sections: Vec<Section>) -> Vec<String> {
        sections.into_iter().flat_map(|s| s.recipes).collect()
    }

    #[test]
    fn groups_recipes_under_their_banners() {
        let sections = parse(JUSTFILE);
        let titles: Vec<Option<&str>> = sections.iter().map(|s| s.title.as_deref()).collect();
        assert_eq!(
            titles,
            [
                None,
                Some("Secrets Management"),
                Some("NixOS System Management"),
                Some("Development"),
                Some("Cleanup"),
                Some("Session Control"),
                Some("Storage Management / Backups"),
                Some("Storage Management / Snapshots"),
            ]
        );
        assert_eq!(sections[1].recipes, ["edit-secret", "rekey-secrets"]);
        assert_eq!(sections[6].recipes, ["backup-status", "_stamp"]);
    }

    /// The same order as `just --summary --unsorted`, plus the private
    /// `_stamp`, which `--summary` leaves out.
    #[test]
    fn keeps_source_order() {
        assert_eq!(
            names(parse(JUSTFILE)),
            [
                "default",
                "edit-secret",
                "rekey-secrets",
                "rebuild",
                "check",
                "update",
                "fuzz",
                "lint",
                "lint-rust",
                "lint-nix",
                "clean-cache",
                "lock",
                "backup-status",
                "_stamp",
                "snapshot",
            ]
        );
    }

    /// The parser and just agree on which recipes exist.
    #[test]
    fn finds_every_recipe_that_just_knows_about() {
        let mut parsed = names(parse(JUSTFILE));
        parsed.sort();
        let dumped: Vec<String> = crate::justfile::parse(DUMP)
            .unwrap()
            .into_iter()
            .map(|recipe| recipe.name)
            .collect();
        assert_eq!(parsed, dumped);
    }

    #[test]
    fn skips_lines_that_are_not_recipe_headers() {
        let source = r#"
export NAME := "value"
alias b := build
set shell := ["bash", "-c"]
# Note: comments can contain colons
[group('demo')]
build:
    echo "indented: part of the body"
@quiet URL="https://example.org":
"#;
        assert_eq!(names(parse(source)), ["build", "quiet"]);
    }
}
