use anyhow::{Context, Result};
use std::path::Path;

pub fn run(repo_root: &Path, secret: &str) -> Result<()> {
    // Validate secret name to prevent path traversal
    let secret_name = crate::validation::validate_secret_name(secret)?;

    let secrets_dir = repo_root.join("secrets");
    let secret_path = secrets_dir.join(&secret_name);

    // Verify the canonicalized path is still within secrets_dir
    if secret_path.exists() {
        crate::validation::validate_path_in_directory(&secret_path, &secrets_dir)?;
    }

    crate::print_info(&format!("Editing secret: {}", secret_name));

    // Run agenix -e <secret>
    let secret_path_str = secret_path
        .to_str()
        .context("Secret path contains invalid UTF-8")?;
    crate::run_agenix(&["-e", secret_path_str])?;

    crate::print_success("Secret edited successfully");

    Ok(())
}
