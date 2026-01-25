#![no_main]

use libfuzzer_sys::fuzz_target;
use serde_json;

fuzz_target!(|data: &[u8]| {
    // Test JSON parsing of Mullvad API responses
    // This fuzzes the deserialization logic for potential panics
    if let Ok(s) = std::str::from_utf8(data) {
        let _: Result<wireguard_helper::mullvad_api::RelayList, _> =
            serde_json::from_str(s);
    }

    // Also test raw bytes
    let _: Result<wireguard_helper::mullvad_api::RelayList, _> =
        serde_json::from_slice(data);
});
