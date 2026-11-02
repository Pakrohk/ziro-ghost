//! Focus Mode interactive TUI binary & Intent Bus dispatcher for Ghost v2.0.0.

use ghost_protocol::{Intent, IntentResult};
use std::io::{self, BufRead, Write};

fn handle_intent(intent: Intent) -> Option<IntentResult> {
    if !intent.name.starts_with("ghost.popup.") {
        return Some(IntentResult::error(
            intent.id,
            format!("unsubscribed intent namespace: {}", intent.name),
        ));
    }

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
        "ghost.popup.shutdown" | "ghost.popup.exit" => Some(IntentResult::ok(
            intent.id,
            Some(serde_json::json!({
                "shutdown": true
            })),
        )),
        other => Some(IntentResult::error(
            intent.id,
            format!("action not implemented in M1: {}", other),
        )),
    }
}

fn main() -> io::Result<()> {
    let stdin = io::stdin();
    let stdout = io::stdout();
    let mut out_handle = stdout.lock();

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
                if let Some(res) = handle_intent(intent) {
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
