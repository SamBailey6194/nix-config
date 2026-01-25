#![no_main]

use libfuzzer_sys::fuzz_target;

fuzz_target!(|data: &[u8]| {
    if let Ok(s) = std::str::from_utf8(data) {
        // Test WireGuard key validation (base64 format)
        let _ = wireguard_helper::validation::validate_wg_key(s);

        // Test hostname validation
        let _ = wireguard_helper::validation::validate_hostname(s);

        // Test IPv4 validation
        let _ = wireguard_helper::validation::validate_ipv4(s);

        // Test country code validation
        let _ = wireguard_helper::validation::validate_country_code(s);

        // Test simple filename validation
        let _ = wireguard_helper::validation::validate_simple_filename(s);
    }
});
