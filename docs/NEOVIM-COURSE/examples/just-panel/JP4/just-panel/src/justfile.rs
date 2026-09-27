//! The justfile model: recipes and their parameters, loaded from `just --dump`.
//!
//! `just --dump --dump-format json` describes a justfile in far more detail
//! than the panel needs, and its shape grows between just releases: 1.58 (on
//! NixOS) adds parameter fields that 1.46 (on Ubuntu) does not have. So these
//! types pick out only the fields the panel uses. Serde skips every other
//! field, and the ones whose shape varies (defaults, attributes, recipe
//! bodies) stay a `serde_json::Value` and are read with care.

use std::collections::BTreeMap;
use std::fmt;
use std::path::Path;
use std::process::Command;

use anyhow::{bail, Context, Result};
use serde::Deserialize;
use serde_json::Value;

/// The parts of a dump the panel reads.
#[derive(Deserialize)]
struct Dump {
    /// Keyed by name, so alphabetical: source order is not in the dump.
    recipes: BTreeMap<String, Recipe>,
}

/// One recipe, as `just --dump --dump-format json` describes it.
#[derive(Debug, Deserialize)]
pub struct Recipe {
    pub name: String,
    /// The comment line directly above the recipe. Only the last line of a
    /// longer comment block makes it into the dump.
    pub doc: Option<String>,
    pub parameters: Vec<Parameter>,
    /// Recipes that just runs before this one.
    pub dependencies: Vec<Dependency>,
    /// Named `_like-this` or marked `[private]`: `just --list` hides it, and
    /// so does the panel.
    pub private: bool,
    /// `"private"` for a bare attribute, `{"group": "rust"}` for one with a
    /// value.
    pub attributes: Vec<Value>,
    /// One array per line, holding text and `{{…}}` interpolations.
    pub body: Value,
}

/// One parameter of a recipe, e.g. `TIME="300"` in `fuzz TARGET TIME="300"`.
#[derive(Debug, Deserialize)]
pub struct Parameter {
    pub name: String,
    pub kind: ParameterKind,
    /// `None` when the parameter is required. A string literal is a JSON
    /// string; anything else (a variable, a backtick) is an expression that
    /// only just can evaluate.
    pub default: Option<Value>,
}

/// How many values a parameter takes on the command line.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum ParameterKind {
    /// `NAME`: exactly one.
    Singular,
    /// `+NAME`: one or more.
    Plus,
    /// `*NAME`: any number, including none.
    Star,
}

/// A recipe that has to run before another one.
#[derive(Debug, Deserialize)]
pub struct Dependency {
    pub recipe: String,
}

impl Recipe {
    /// The recipe as `just --list` shows it, e.g. `fuzz TARGET TIME="300"`.
    pub fn signature(&self) -> String {
        let mut words = vec![self.name.clone()];
        words.extend(self.parameters.iter().map(Parameter::to_string));
        words.join(" ")
    }

    /// The body as text, one string per line, with `{{NAME}}` standing in for
    /// an interpolated variable and `{{…}}` for anything more involved. Good
    /// for reading, not for running.
    pub fn body_lines(&self) -> Vec<String> {
        let Some(lines) = self.body.as_array() else {
            return Vec::new();
        };
        lines
            .iter()
            .map(|line| {
                line.as_array()
                    .into_iter()
                    .flatten()
                    .map(fragment)
                    .collect()
            })
            .collect()
    }

    /// Whether the body runs `sudo`, which stops to ask for a password.
    ///
    /// This is a plain word search, so it cannot tell a real `sudo` from one
    /// inside an `echo`. That is deliberate: the course's demo justfile only
    /// echoes its "sudo" commands, and still gets the confirmation dialog.
    pub fn needs_sudo(&self) -> bool {
        self.body_lines().iter().any(|line| {
            line.split(|c: char| !(c.is_alphanumeric() || c == '-' || c == '_'))
                .any(|word| word == "sudo")
        })
    }

    /// The `[group('…')]` the recipe belongs to, if any.
    pub fn group(&self) -> Option<&str> {
        self.attribute("group").and_then(Value::as_str)
    }

    /// The question just asks before running a `[confirm]` recipe, or `None`
    /// when the recipe has no such attribute.
    pub fn confirm_prompt(&self) -> Option<String> {
        let prompt = self.attribute("confirm")?;
        Some(match prompt.as_str() {
            Some(prompt) => prompt.to_string(),
            // A bare `[confirm]` is `null`, and just asks this instead.
            None => format!("Run recipe `{}`?", self.name),
        })
    }

    /// The value of an attribute such as `[group('rust')]`. Bare attributes
    /// like `[private]` are plain strings in the dump, so they never match.
    fn attribute(&self, name: &str) -> Option<&Value> {
        self.attributes
            .iter()
            .find_map(|attribute| attribute.get(name))
    }
}

impl Parameter {
    /// `+NAME` and `*NAME` take any number of words; `NAME` takes one.
    pub fn is_variadic(&self) -> bool {
        self.kind != ParameterKind::Singular
    }

    /// The default when it is a plain string, the only kind of default the
    /// panel can show as a value.
    pub fn literal_default(&self) -> Option<&str> {
        self.default.as_ref().and_then(Value::as_str)
    }
}

/// Writes the parameter the way `just --list` does: `NAME`, `+NAME`, `*NAME`
/// or `NAME="default"`.
impl fmt::Display for Parameter {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self.kind {
            ParameterKind::Singular => {}
            ParameterKind::Plus => f.write_str("+")?,
            ParameterKind::Star => f.write_str("*")?,
        }
        f.write_str(&self.name)?;
        if let Some(default) = &self.default {
            match default.as_str() {
                Some(literal) => write!(f, "={literal:?}")?,
                // An expression: just evaluates it when the recipe runs.
                None => f.write_str("=…")?,
            }
        }
        Ok(())
    }
}

/// One piece of a body line: plain text, or an interpolation, which the dump
/// writes as an array holding one expression.
fn fragment(piece: &Value) -> String {
    if let Some(text) = piece.as_str() {
        return text.to_string();
    }
    let kind = piece.pointer("/0/0").and_then(Value::as_str);
    let name = piece.pointer("/0/1").and_then(Value::as_str);
    match (kind, name) {
        (Some("variable"), Some(name)) => ["{{", name, "}}"].concat(),
        _ => "{{…}}".to_string(),
    }
}

/// Parses the output of `just --dump --dump-format json`: every recipe,
/// private ones included, in alphabetical order.
pub fn parse(json: &str) -> Result<Vec<Recipe>> {
    let dump: Dump = serde_json::from_str(json).context("unexpected `just --dump` output")?;
    Ok(dump.recipes.into_values().collect())
}

/// Asks `just` itself to describe `justfile`.
///
/// Letting just read the file, rather than parsing it here, means the panel
/// sees exactly the recipes, parameters and defaults that just will run.
pub fn load(justfile: &Path) -> Result<Vec<Recipe>> {
    let output = just_command(justfile)
        .args(["--dump", "--dump-format", "json"])
        .output()
        .context("could not run `just`: is it installed?")?;
    if !output.status.success() {
        bail!(
            "`just --dump` failed: {}",
            String::from_utf8_lossy(&output.stderr).trim()
        );
    }
    parse(&String::from_utf8_lossy(&output.stdout))
}

/// A `just` command aimed at `justfile`, running in the justfile's directory.
///
/// Both flags matter. On laptop-intel, zsh exports `JUST_JUSTFILE` and
/// `JUST_WORKING_DIRECTORY` for the nix-config repo, and an inherited
/// `JUST_WORKING_DIRECTORY` beats the justfile's own directory unless
/// `--working-directory` is passed as well.
///
/// `justfile` should be absolute (`main` makes it so): the parent of a
/// bare `justfile` is an empty path, and just rejects an empty
/// `--working-directory`.
pub fn just_command(justfile: &Path) -> Command {
    let mut command = Command::new("just");
    command
        .arg("--justfile")
        .arg(justfile)
        .arg("--working-directory")
        .arg(justfile.parent().unwrap_or(Path::new("/")));
    command
}

#[cfg(test)]
mod tests {
    use super::*;

    /// `just --dump` of the course's demo justfile, made with just 1.46. It is
    /// compiled in, so the tests never run `just` or read files at run time.
    const DUMP: &str = include_str!("../tests/fixtures/dump.json");

    fn recipe(name: &str) -> Recipe {
        parse(DUMP)
            .unwrap()
            .into_iter()
            .find(|recipe| recipe.name == name)
            .unwrap()
    }

    #[test]
    fn parses_every_recipe_in_alphabetical_order() {
        let names: Vec<String> = parse(DUMP).unwrap().into_iter().map(|r| r.name).collect();
        assert_eq!(names.len(), 15);
        assert_eq!(names.first().map(String::as_str), Some("_stamp"));
        assert!(names.is_sorted());
        assert!(recipe("_stamp").private);
        assert!(!recipe("check").private);
    }

    #[test]
    fn reads_parameters_and_their_defaults() {
        let fuzz = recipe("fuzz");
        let [target, time] = &fuzz.parameters[..] else {
            panic!("fuzz should have two parameters");
        };
        assert_eq!(target.kind, ParameterKind::Singular);
        assert_eq!(target.default, None);
        assert_eq!(time.literal_default(), Some("5"));
        assert!(recipe("rebuild").parameters[0].is_variadic());
    }

    #[test]
    fn shows_signatures_like_just_list() {
        assert_eq!(recipe("check").signature(), "check");
        assert_eq!(recipe("fuzz").signature(), r#"fuzz TARGET TIME="5""#);
        assert_eq!(recipe("rebuild").signature(), "rebuild *ARGS");
        assert_eq!(recipe("snapshot").signature(), r#"snapshot SUBVOL NAME="""#);
    }

    #[test]
    fn reads_dependencies_and_attributes() {
        let lint: Vec<String> = recipe("lint")
            .dependencies
            .into_iter()
            .map(|d| d.recipe)
            .collect();
        assert_eq!(lint, ["lint-rust", "lint-nix"]);
        assert_eq!(recipe("lint-rust").group(), Some("rust"));
        assert_eq!(
            recipe("update").confirm_prompt().as_deref(),
            Some("Update every flake input? (demo: nothing changes)")
        );
        assert_eq!(recipe("check").group(), None);
        assert_eq!(recipe("check").confirm_prompt(), None);
    }

    #[test]
    fn renders_the_body_with_interpolations() {
        assert_eq!(
            recipe("edit-secret").body_lines(),
            [r#"@echo "demo: would open secrets/{{SECRET}}.age in your editor""#]
        );
        assert_eq!(
            recipe("rebuild").body_lines().first().map(String::as_str),
            Some("#!/usr/bin/env bash")
        );
    }

    #[test]
    fn spots_sudo_as_a_whole_word() {
        assert!(recipe("rebuild").needs_sudo());
        assert!(recipe("snapshot").needs_sudo());
        assert!(!recipe("check").needs_sudo());

        let pseudo: Recipe = serde_json::from_str(
            r#"{"name": "tty", "doc": null, "parameters": [], "dependencies": [],
                "private": false, "attributes": [], "body": [["open a pseudo-terminal"]]}"#,
        )
        .unwrap();
        assert!(!pseudo.needs_sudo());
    }

    /// just 1.58 adds `flag`, `min`, `max` and `multiple` to parameters, lets
    /// `value` be an expression and adds a top-level `module_path`. None of it
    /// may break parsing.
    #[test]
    fn accepts_a_dump_from_a_newer_just() {
        let json = r#"{
            "module_path": "",
            "recipes": {
                "deploy": {
                    "name": "deploy", "namepath": "deploy", "doc": "Deploy a host",
                    "attributes": [{"confirm": null}, "no-cd"], "body": [], "dependencies": [],
                    "parameters": [{
                        "name": "HOST", "kind": "singular", "default": ["variable", "host"],
                        "export": false, "flag": false, "help": null, "long": null, "short": null,
                        "max": null, "min": null, "multiple": false, "pattern": null,
                        "value": ["variable", "host"]
                    }],
                    "priors": 0, "private": false, "quiet": false, "shebang": false
                }
            }
        }"#;
        let recipes = parse(json).unwrap();
        let deploy = &recipes[0];
        assert_eq!(deploy.signature(), "deploy HOST=…");
        assert_eq!(deploy.parameters[0].literal_default(), None);
        assert_eq!(
            deploy.confirm_prompt().as_deref(),
            Some("Run recipe `deploy`?")
        );
    }

    #[test]
    fn aims_just_at_the_justfile_and_its_directory() {
        let command = just_command(Path::new("/repo/justfile"));
        let args: Vec<_> = command.get_args().collect();
        assert_eq!(
            args,
            [
                "--justfile",
                "/repo/justfile",
                "--working-directory",
                "/repo"
            ]
        );
    }
}
