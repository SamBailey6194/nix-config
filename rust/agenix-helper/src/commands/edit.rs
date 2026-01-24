use anyhow::Result;
use std::path::Path;

pub fn run(repo_root: &Path, secret: &str) -> Result<()> {
    let secrets_dir = repo_root.join("secrets");

    // Ensure secret ends with .age
    let secret_name = if secret.ends_with(".age") {
        secret.to_string()
    } else {
        format!("{}.age", secret)
    };

    let secret_path = secrets_dir.join(&secret_name);

    crate::print_info(&format!("Editing secret: {}", secret_name));

    // Run agenix -e <secret>
    crate::run_agenix(&["-e", secret_path.to_str().unwrap()])?;

    crate::print_success("Secret edited successfully");

    Ok(())
}
