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

    // agenix resolves BOTH its rules file (defaults to ./secrets.nix) and the
    // secret's attribute key relative to the current working directory. Run it
    // from inside secrets/ and pass the bare filename so it reads
    // secrets/secrets.nix (not a non-existent root-level secrets.nix) and the
    // lookup matches the relative keys declared there.
    std::env::set_current_dir(&secrets_dir).with_context(|| {
        format!(
            "Failed to enter secrets directory: {}",
            secrets_dir.display()
        )
    })?;
    crate::run_agenix(&["-e", &secret_name])?;

    crate::print_success("Secret edited successfully");

    Ok(())
}
