use anyhow::Result;
use std::path::Path;

pub fn run(repo_root: &Path) -> Result<()> {
    let secrets_dir = repo_root.join("secrets");

    crate::print_info("Rekeying all secrets...");
    crate::print_warning("This will re-encrypt all secrets with the current public keys in secrets.nix");

    // Run agenix -r (rekey all secrets)
    std::env::set_current_dir(&secrets_dir)?;
    crate::run_agenix(&["-r"])?;

    crate::print_success("All secrets rekeyed successfully");

    Ok(())
}
