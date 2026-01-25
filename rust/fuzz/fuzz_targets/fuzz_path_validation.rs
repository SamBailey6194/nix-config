#![no_main]

use libfuzzer_sys::fuzz_target;
use std::path::PathBuf;
use agenix_helper::validation::validate_path_in_directory;

fuzz_target!(|data: &[u8]| {
    if let Ok(s) = std::str::from_utf8(data) {
        // Split input into path and base directory
        let parts: Vec<&str> = s.split('|').collect();

        if parts.len() >= 2 {
            let path = PathBuf::from(parts[0]);
            let base_dir = PathBuf::from(parts[1]);

            // Test path validation for directory traversal
            // This should safely reject malicious paths
            let _ = validate_path_in_directory(&path, &base_dir);
        }
    }
});
