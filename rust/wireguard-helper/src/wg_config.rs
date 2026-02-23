use crate::mullvad_api::Relay;
use anyhow::Result;

/// Generate WireGuard config for Mullvad multi-hop (2-hop: entry → exit)
///
/// Mullvad multi-hop works by connecting to the ENTRY relay on the EXIT relay's
/// multihop_port. The entry relay then forwards traffic to the exit relay internally.
pub fn generate_config(
    private_key: &str,
    entry_relay: &Relay,
    exit_relay: &Relay,
    ipv4_address: &str,
    ipv6_address: &str,
) -> Result<String> {
    let config = format!(
        r#"[Interface]
PrivateKey = {private_key}
Address = {ipv4_address},{ipv6_address}
DNS = 10.64.0.1

[Peer]
PublicKey = {entry_pubkey}
AllowedIPs = 0.0.0.0/0, ::/0
Endpoint = {entry_ip}:{exit_multihop_port}
PersistentKeepalive = 25
"#,
        private_key = private_key,
        ipv4_address = ipv4_address,
        ipv6_address = ipv6_address,
        entry_pubkey = entry_relay.pubkey,
        entry_ip = entry_relay.ipv4_addr_in,
        exit_multihop_port = exit_relay.multihop_port,
    );

    Ok(config)
}

/// Generate WireGuard keypair
pub fn generate_keypair() -> Result<(String, String)> {
    use std::io::Write;
    use std::process::{Command, Stdio};

    // Generate private key
    let output = Command::new("wg").args(["genkey"]).output()?;

    let private_key = String::from_utf8(output.stdout)?.trim().to_string();

    // Generate public key from private key
    // Use stdin pipe instead of shell interpolation to prevent command injection
    let mut child = Command::new("wg")
        .arg("pubkey")
        .stdin(Stdio::piped())
        .stdout(Stdio::piped())
        .spawn()?;

    if let Some(mut stdin) = child.stdin.take() {
        stdin.write_all(private_key.as_bytes())?;
        stdin.write_all(b"\n")?;
    }

    let output = child.wait_with_output()?;
    let public_key = String::from_utf8(output.stdout)?.trim().to_string();

    Ok((private_key, public_key))
}
