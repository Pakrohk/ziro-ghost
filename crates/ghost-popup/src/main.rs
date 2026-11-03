//! Focus Mode interactive TUI binary & Intent Bus dispatcher for Ghost v2.0.0.

pub mod mcp;
pub mod ui;

use ghost_protocol::{Intent, IntentResult};
use std::env;
use std::fs::File;
use std::io::{self, BufRead, BufReader, Write};
use std::path::PathBuf;
use std::time::SystemTime;
use ui::app::FocusApp;
use ui::events::{read_action, Action, TerminalGuard};

struct HistoryStore {
    path: PathBuf,
    last_mtime: Option<SystemTime>,
    lines: Vec<String>,
}

impl HistoryStore {
    fn new() -> Self {
        let path = if let Ok(custom) = env::var("GHOST_CACHE_FILE") {
            PathBuf::from(custom)
        } else if let Ok(home) = env::var("HOME") {
            let ziro_cache = PathBuf::from(&home).join(".cache/ziro/ghost/history-cache");
            if ziro_cache.exists() {
                ziro_cache
            } else {
                PathBuf::from(&home).join(".zsh_history")
            }
        } else {
            PathBuf::from("/tmp/history-cache")
        };

        Self {
            path,
            last_mtime: None,
            lines: Vec::new(),
        }
    }

    fn refresh(&mut self) {
        if let Ok(meta) = self.path.metadata() {
            if let Ok(mtime) = meta.modified() {
                if self.last_mtime == Some(mtime) && !self.lines.is_empty() {
                    return;
                }
                self.last_mtime = Some(mtime);
            }
        } else {
            return;
        }

        if let Ok(file) = File::open(&self.path) {
            let reader = BufReader::new(file);
            let mut new_lines = Vec::with_capacity(1024);
            for line_res in reader.lines() {
                if let Ok(l) = line_res {
                    let trimmed = l.trim();
                    if trimmed.is_empty() || trimmed.starts_with('#') {
                        continue;
                    }
                    // Handle zsh extended_history format: : 1234567890:0;command
                    let cmd = if trimmed.starts_with(':') {
                        if let Some(idx) = trimmed.find(';') {
                            trimmed[idx + 1..].trim()
                        } else {
                            trimmed
                        }
                    } else {
                        trimmed
                    };
                    if !cmd.is_empty() && !new_lines.iter().any(|existing| existing == cmd) {
                        new_lines.push(cmd.to_string());
                    }
                }
            }
            self.lines = new_lines;
        }
    }

    fn find_match(&mut self, query: &str) -> Option<String> {
        if query.is_empty() {
            return None;
        }
        self.refresh();

        // Search in reverse for most recent match
        for line in self.lines.iter().rev() {
            if line.starts_with(query) && line != query {
                return Some(line.clone());
            }
        }
        None
    }
}

fn run_interactive_focus(items: Vec<String>) -> io::Result<Option<String>> {
    let guard = TerminalGuard::new()?;
    let mut terminal = ratatui::init();
    let mut app = FocusApp::new(items);

    let result = loop {
        terminal.draw(|f| ui::render::draw(f, &app))?;
        if let Some(action) = read_action()? {
            match action {
                Action::Next => app.next(),
                Action::Prev => app.prev(),
                Action::Accept => break app.current().map(|s| s.to_string()),
                Action::Cancel => break None,
            }
        }
    };

    drop(guard);
    ratatui::restore();
    Ok(result)
}

fn handle_focus_enter(intent: &Intent, cli_test_keys: Option<&str>) -> IntentResult {
    let raw_items = intent.metadata.get("items").and_then(|v| v.as_array());
    let items: Vec<String> = match raw_items {
        Some(arr) => arr
            .iter()
            .filter_map(|v| v.as_str().map(|s| s.to_string()))
            .collect(),
        None => Vec::new(),
    };

    if items.is_empty() {
        return IntentResult::error(&intent.id, "no items");
    }

    let test_keys = cli_test_keys.or_else(|| {
        intent
            .metadata
            .get("test_keys")
            .and_then(|v| v.as_str())
    });

    if let Some(keys) = test_keys {
        let mut app = FocusApp::new(items);
        match app.apply_key_sequence(keys) {
            Some(Some(selected)) => {
                IntentResult::ok(&intent.id, Some(serde_json::json!({ "selected": selected })))
            }
            Some(None) => {
                IntentResult::ok(&intent.id, Some(serde_json::json!({ "cancelled": true })))
            }
            None => IntentResult::error(&intent.id, "no items"),
        }
    } else {
        match run_interactive_focus(items) {
            Ok(Some(selected)) => {
                IntentResult::ok(&intent.id, Some(serde_json::json!({ "selected": selected })))
            }
            Ok(None) => {
                IntentResult::ok(&intent.id, Some(serde_json::json!({ "cancelled": true })))
            }
            Err(e) => IntentResult::error(&intent.id, format!("interactive UI failed: {}", e)),
        }
    }
}

fn handle_intent(
    intent: Intent,
    history: &mut HistoryStore,
    cli_test_keys: Option<&str>,
) -> Option<IntentResult> {
    if intent.name.starts_with("ghost.popup.") {
        match intent.name.as_str() {
            "ghost.popup.ping" => Some(IntentResult::ok(
                intent.id,
                Some(serde_json::json!({
                    "pong": true,
                    "version": env!("CARGO_PKG_VERSION")
                })),
            )),
            "ghost.popup.status" => Some(IntentResult::ok(
                intent.id,
                Some(serde_json::json!({
                    "service": "ghost-popup",
                    "status": "ready",
                    "version": env!("CARGO_PKG_VERSION")
                })),
            )),
            "ghost.popup.focus_enter" => Some(handle_focus_enter(&intent, cli_test_keys)),
            "ghost.popup.shutdown" | "ghost.popup.exit" => Some(IntentResult::ok(
                intent.id,
                Some(serde_json::json!({
                    "shutdown": true
                })),
            )),
            other => Some(IntentResult::error(
                intent.id,
                format!("action not implemented in M1/M2/M3: {}", other),
            )),
        }
    } else if intent.name == "ghost.suggest.query" {
        let query = intent
            .metadata
            .get("query")
            .and_then(|v| v.as_str())
            .unwrap_or("");

        let matched = history.find_match(query);
        let suggestions = if let Some(ref m) = matched {
            vec![serde_json::json!(m)]
        } else {
            vec![]
        };

        Some(IntentResult::ok(
            intent.id,
            Some(serde_json::json!({
                "query": query,
                "suggestion": matched,
                "suggestions": suggestions
            })),
        ))
    } else {
        Some(IntentResult::error(
            intent.id,
            format!("unsubscribed intent namespace: {}", intent.name),
        ))
    }
}

fn main() -> io::Result<()> {
    let args: Vec<String> = env::args().collect();
    if args.len() > 1 && args[1] == "mcp" {
        return mcp::run_mcp_server();
    }

    if args.len() > 1 && (args[1] == "--version" || args[1] == "-V") {
        println!("ghost-popup {}", env!("CARGO_PKG_VERSION"));
        return Ok(());
    }

    // Detect --test-keys=<sequence>
    let cli_test_keys: Option<String> = args.iter().find_map(|arg| {
        arg.strip_prefix("--test-keys=").map(|s| s.to_string())
    });

    let stdin = io::stdin();
    let stdout = io::stdout();
    let mut out_handle = stdout.lock();
    let mut history = HistoryStore::new();

    for line_result in stdin.lock().lines() {
        let line = match line_result {
            Ok(l) => l,
            Err(e) => {
                eprintln!("ghost-popup: stdin read error: {}", e);
                break;
            }
        };

        let trimmed = line.trim();
        if trimmed.is_empty() {
            continue;
        }

        let is_shutdown = match Intent::from_ndjson_line(trimmed) {
            Ok(intent) => {
                let name = intent.name.clone();
                if let Some(res) = handle_intent(intent, &mut history, cli_test_keys.as_deref()) {
                    if let Ok(serialized) = res.to_ndjson_line() {
                        let _ = writeln!(out_handle, "{}", serialized);
                        let _ = out_handle.flush();
                    }
                }
                name == "ghost.popup.shutdown" || name == "ghost.popup.exit"
            }
            Err(err) => {
                let err_res = IntentResult::error("unknown", format!("malformed NDJSON intent: {}", err));
                if let Ok(serialized) = err_res.to_ndjson_line() {
                    let _ = writeln!(out_handle, "{}", serialized);
                    let _ = out_handle.flush();
                }
                false
            }
        };

        if is_shutdown {
            break;
        }
    }

    Ok(())
}
