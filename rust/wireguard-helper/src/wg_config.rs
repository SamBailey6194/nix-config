use crate::mullvad_api::Relay;
use anyhow::Result;

/// Generate WireGuard config for multi-hop chain
pub fn generate_config(private_key: &str, hops: &[Relay]) -> Result<String> {
    if hops.is_empty() {
        anyhow::bail!("Cannot generate config with zero hops");
    }

    // For multi-hop, we need to chain the servers
    // Simple approach: Use the last hop as the main peer
    // (Full multi-hop chaining may require multiple interfaces - simplified for MVP)

    let exit_relay = hops.last().unwrap();

    let config = format!(
        r#"[Interface]
PrivateKey = {}
Address = 10.64.0.1/32
DNS = 10.64.0.1

[Peer]
PublicKey = {}
AllowedIPs = 0.0.0.0/0, ::/0
Endpoint = {}:{}
PersistentKeepalive = 25
"#,
        private_key, exit_relay.pubkey, exit_relay.ipv4_addr_in, exit_relay.multihop_port
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
