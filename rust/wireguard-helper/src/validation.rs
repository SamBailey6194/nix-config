use anyhow::Result;
use std::path::{Component, Path};

/// Validates a device name to prevent injection attacks
///
/// # Security
///
/// Only allows alphanumeric characters, hyphens, and underscores to prevent:
/// - Path traversal
/// - Shell injection
/// - Command injection
pub fn validate_device_name(device: &str) -> Result<String> {
    if device.is_empty() {
        anyhow::bail!("Device name cannot be empty");
    }

    // Only allow alphanumeric, hyphens, and underscores
    if !device
        .chars()
        .all(|c| c.is_alphanumeric() || c == '-' || c == '_')
    {
        anyhow::bail!(
            "Device name must contain only alphanumeric characters, hyphens, and underscores"
        );
    }

    // Reasonable length limit
    if device.len() > 64 {
        anyhow::bail!("Device name too long (max 64 characters)");
    }

    Ok(device.to_string())
}

/// Validates a country code
pub fn validate_country_code(code: &str) -> Result<String> {
    if code.len() != 2 {
        anyhow::bail!("Country code must be exactly 2 characters");
    }

    if !code.chars().all(|c| c.is_ascii_lowercase()) {
        anyhow::bail!("Country code must be lowercase ASCII letters");
    }

    Ok(code.to_string())
}

/// Validates a hop count
pub fn validate_hop_count(hops: usize) -> Result<usize> {
    if !(5..=10).contains(&hops) {
        anyhow::bail!("Hop count must be between 5 and 10");
    }
    Ok(hops)
}

/// Validates a WireGuard key format
pub fn validate_wg_key(key: &str) -> Result<()> {
    // WireGuard keys are base64-encoded 32-byte values (44 characters with padding)
    if key.len() != 44 {
        anyhow::bail!(
            "Invalid WireGuard key length (expected 44 characters, got {})",
            key.len()
        );
    }

    // Check for valid base64 characters
    if !key
        .chars()
        .all(|c| c.is_alphanumeric() || c == '+' || c == '/' || c == '=')
    {
        anyhow::bail!("Invalid WireGuard key: contains invalid base64 characters");
    }

    Ok(())
}

/// Validates a hostname format
pub fn validate_hostname(hostname: &str) -> Result<()> {
    if hostname.is_empty() {
        anyhow::bail!("Hostname cannot be empty");
    }

    // Allow alphanumeric, hyphens, and dots
    if !hostname
        .chars()
        .all(|c| c.is_alphanumeric() || c == '-' || c == '.')
    {
        anyhow::bail!("Invalid hostname: contains invalid characters");
    }

    // Check length
    if hostname.len() > 253 {
        anyhow::bail!("Hostname too long (max 253 characters)");
    }

    Ok(())
}

/// Validates an IPv4 address
pub fn validate_ipv4(ip: &str) -> Result<()> {
    use std::net::Ipv4Addr;
    ip.parse::<Ipv4Addr>()
        .map(|_| ())
        .map_err(|_| anyhow::anyhow!("Invalid IPv4 address: {}", ip))
}

/// Validates a port number
pub fn validate_port(port: u16) -> Result<()> {
    if port == 0 {
        anyhow::bail!("Port number cannot be 0");
    }
    Ok(())
}

/// Validates a path is a simple filename without directory components
pub fn validate_simple_filename(name: &str) -> Result<String> {
    if name.is_empty() {
        anyhow::bail!("Filename cannot be empty");
    }

    // Check for path separators
    if name.contains('/') || name.contains('\\') {
        anyhow::bail!("Filename cannot contain path separators");
    }

    // Ensure no path traversal components
    let path = Path::new(name);
    for component in path.components() {
        match component {
            Component::Normal(_) => continue,
            _ => anyhow::bail!("Invalid filename: contains path traversal components"),
        }
    }

    Ok(name.to_string())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_validate_device_name() {
        assert!(validate_device_name("laptop-intel").is_ok());
        assert!(validate_device_name("server_01").is_ok());
        assert!(validate_device_name("test123").is_ok());

        assert!(validate_device_name("server; rm -rf /").is_err());
        assert!(validate_device_name("../etc/passwd").is_err());
        assert!(validate_device_name("").is_err());
    }

    #[test]
    fn test_validate_wg_key() {
        // Valid key format (44 chars, base64)
        // Real WireGuard keys are 32 bytes base64-encoded with padding
        assert!(validate_wg_key("WJvRtX+jiRq/yvJKdYZKcMJl6gk0Gs4RN7WBFnoJnXs=").is_ok());
        assert!(validate_wg_key("AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=").is_ok());

        // Invalid length (too short)
        assert!(validate_wg_key("short").is_err());

        // Invalid length (too long - 45 chars)
        assert!(validate_wg_key("WJvRtX+jiRq/yvJKdYZKcMJl6gk0Gs4RN7WBFnoJnXs=X").is_err());

        // Invalid characters
        assert!(validate_wg_key("WJvRtX+jiRq/yvJKdYZKcMJl6gk0Gs4RN7WBFnoJnX@").is_err());
    }

    #[test]
    fn test_validate_ipv4() {
        assert!(validate_ipv4("192.168.1.1").is_ok());
        assert!(validate_ipv4("10.0.0.1").is_ok());

        assert!(validate_ipv4("999.999.999.999").is_err());
        assert!(validate_ipv4("not-an-ip").is_err());
    }

    #[test]
    fn test_validate_port() {
        assert!(validate_port(80).is_ok());
        assert!(validate_port(65535).is_ok());

        assert!(validate_port(0).is_err());
    }
}
