#![no_main]

use libfuzzer_sys::fuzz_target;
use wireguard_helper::mullvad_api::Relay;

fuzz_target!(|data: &[u8]| {
    if let Ok(s) = std::str::from_utf8(data) {
        // Split input into private key and relay data
        let parts: Vec<&str> = s.split('|').collect();

        if parts.len() >= 6 {
            let private_key = parts[0];

            // Create a test relay from fuzzed data
            let relay = Relay {
                hostname: parts[1].to_string(),
                ipv4_addr_in: parts[2].to_string(),
                ipv6_addr_in: parts[3].to_string(),
                public_key: parts[4].to_string(),
                multihop_port: parts[5].parse().unwrap_or(51820),
                country_code: parts.get(6).unwrap_or(&"se").to_string(),
                city_name: parts.get(7).unwrap_or(&"stockholm").to_string(),
                active: true,
            };

            // Test config generation with fuzzed data
            let _ = wireguard_helper::wg_config::generate_config(
                private_key,
                &[relay]
            );
        }
    }
});
