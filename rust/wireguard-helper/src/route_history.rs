use anyhow::{Context, Result};
use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use std::collections::HashSet;
use std::fs;
use std::path::Path;

const MAX_HISTORY_SIZE: usize = 10;

#[derive(Debug, Serialize, Deserialize)]
pub struct RouteEntry {
    pub servers: Vec<String>,
    pub exit_location: String,
    pub timestamp: DateTime<Utc>,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct RouteHistory {
    entries: Vec<RouteEntry>,
}

impl RouteHistory {
    pub fn new() -> Self {
        Self {
            entries: Vec::new(),
        }
    }

    /// Load route history from file
    pub fn load(path: &str) -> Result<Self> {
        let path = Path::new(path);

        if !path.exists() {
            return Ok(Self::new());
        }

        let contents = fs::read_to_string(path).context("Failed to read route history file")?;

        let history: RouteHistory =
            serde_json::from_str(&contents).context("Failed to parse route history")?;

        Ok(history)
    }

    /// Save route history to file
    pub fn save(&self, path: &str) -> Result<()> {
        let json =
            serde_json::to_string_pretty(self).context("Failed to serialize route history")?;

        // Ensure parent directory exists
        if let Some(parent) = Path::new(path).parent() {
            fs::create_dir_all(parent).context("Failed to create history directory")?;
        }

        fs::write(path, json).context("Failed to write route history file")?;

        Ok(())
    }

    /// Add new route to history
    pub fn add(&mut self, servers: Vec<String>, exit_location: String) {
        let entry = RouteEntry {
            servers,
            exit_location,
            timestamp: Utc::now(),
        };

        self.entries.insert(0, entry);

        // Keep only last N entries
        if self.entries.len() > MAX_HISTORY_SIZE {
            self.entries.truncate(MAX_HISTORY_SIZE);
        }
    }

    /// Get set of recently used servers (to avoid repetition)
    pub fn get_used_servers(&self) -> HashSet<String> {
        self.entries
            .iter()
            .flat_map(|e| e.servers.iter())
            .cloned()
            .collect()
    }

    /// Get last rotation info
    #[allow(dead_code)]
    pub fn last_rotation(&self) -> Option<&RouteEntry> {
        self.entries.first()
    }
}

impl Default for RouteHistory {
    fn default() -> Self {
        Self::new()
    }
}
