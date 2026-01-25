#![no_main]

use libfuzzer_sys::fuzz_target;

fuzz_target!(|data: &[u8]| {
    if let Ok(s) = std::str::from_utf8(data) {
        // Test secret name validation for path traversal
        let _ = agenix_helper::validation::validate_secret_name(s);

        // Test general name validation
        let _ = agenix_helper::validation::validate_name(s, "device");
        let _ = agenix_helper::validation::validate_name(s, "server");
    }
});
