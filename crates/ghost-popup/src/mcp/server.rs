//! MCP JSON-RPC 2.0 stdio server implementation.

use serde_json::{json, Value};
use std::env;
use std::io::{self, BufRead, Write};
use std::process::{Command, Stdio};

fn get_plugin_path() -> String {
    if let Ok(dir) = env::var("ZIRO_GHOST_HOME") {
        let p = format!("{}/ghost.plugin.zsh", dir);
        if std::path::Path::new(&p).exists() {
            return p;
        }
    }
    if let Ok(home) = env::var("HOME") {
        let p = format!("{}/Projects/ziro-ghost/ghost.plugin.zsh", home);
        if std::path::Path::new(&p).exists() {
            return p;
        }
        let vendor = format!("{}/.local/share/ziro/vendor/Pakrohk/ziro-ghost/ghost.plugin.zsh", home);
        if std::path::Path::new(&vendor).exists() {
            return vendor;
        }
    }
    "ghost.plugin.zsh".to_string()
}

fn execute_zsh_command(cmd: &str) -> String {
    let plugin = get_plugin_path();
    let full_script = format!(
        "source '{}' 2>/dev/null || true; {}",
        plugin.replace('\'', "'\\''"),
        cmd
    );

    let output = Command::new("zsh")
        .arg("-c")
        .arg(&full_script)
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .output();

    match output {
        Ok(out) => {
            let stdout = String::from_utf8_lossy(&out.stdout).trim().to_string();
            if !stdout.is_empty() {
                stdout
            } else {
                String::from_utf8_lossy(&out.stderr).trim().to_string()
            }
        }
        Err(e) => format!("execution error: {}", e),
    }
}

fn call_tool(name: &str, arguments: &Value) -> Value {
    match name {
        "ghost.health" => {
            let res = execute_zsh_command("ghost health --json");
            json!({
                "content": [
                    {
                        "type": "text",
                        "text": res
                    }
                ]
            })
        }
        "ghost.stats" => {
            let res = execute_zsh_command("ghost stats --json 2>/dev/null || ghost stats");
            json!({
                "content": [
                    {
                        "type": "text",
                        "text": res
                    }
                ]
            })
        }
        "ghost.suggest" => {
            let query = arguments.get("query").and_then(|v| v.as_str()).unwrap_or("");
            let safe_query = query.replace('\'', "'\\''");
            let cmd = format!("ghost suggest '{}'", safe_query);
            let res = execute_zsh_command(&cmd);
            json!({
                "content": [
                    {
                        "type": "text",
                        "text": res
                    }
                ]
            })
        }
        _ => json!({
            "isError": true,
            "content": [
                {
                    "type": "text",
                    "text": format!("unknown tool: {}", name)
                }
            ]
        }),
    }
}

pub fn run_mcp_server() -> io::Result<()> {
    let stdin = io::stdin();
    let stdout = io::stdout();
    let mut out_handle = stdout.lock();

    for line_res in stdin.lock().lines() {
        let line = match line_res {
            Ok(l) => l,
            Err(_) => break,
        };
        let trimmed = line.trim();
        if trimmed.is_empty() {
            continue;
        }

        let parsed: Value = match serde_json::from_str(trimmed) {
            Ok(v) => v,
            Err(e) => {
                let err_resp = json!({
                    "jsonrpc": "2.0",
                    "id": Value::Null,
                    "error": {
                        "code": -32700,
                        "message": format!("Parse error: {}", e)
                    }
                });
                let _ = writeln!(out_handle, "{}", err_resp);
                let _ = out_handle.flush();
                continue;
            }
        };

        let id = parsed.get("id").cloned().unwrap_or(Value::Null);
        let method = parsed.get("method").and_then(|m| m.as_str()).unwrap_or("");

        let response = match method {
            "initialize" => {
                json!({
                    "jsonrpc": "2.0",
                    "id": id,
                    "result": {
                        "protocolVersion": "2024-11-05",
                        "capabilities": {
                            "tools": {}
                        },
                        "serverInfo": {
                            "name": "ghost",
                            "version": env!("CARGO_PKG_VERSION")
                        }
                    }
                })
            }
            "notifications/initialized" => {
                continue;
            }
            "ping" => {
                json!({
                    "jsonrpc": "2.0",
                    "id": id,
                    "result": {}
                })
            }
            "tools/list" => {
                json!({
                    "jsonrpc": "2.0",
                    "id": id,
                    "result": {
                        "tools": [
                            {
                                "name": "ghost.suggest",
                                "description": "Get autosuggest for a query",
                                "inputSchema": {
                                    "type": "object",
                                    "properties": {
                                        "query": {
                                            "type": "string",
                                            "description": "User input command line prefix"
                                        }
                                    },
                                    "required": ["query"]
                                }
                            },
                            {
                                "name": "ghost.health",
                                "description": "Get plugin health status",
                                "inputSchema": {
                                    "type": "object",
                                    "properties": {}
                                }
                            },
                            {
                                "name": "ghost.stats",
                                "description": "Get aggregated metrics",
                                "inputSchema": {
                                    "type": "object",
                                    "properties": {
                                        "since": {
                                            "type": "string",
                                            "description": "Optional ISO timestamp or relative window"
                                        }
                                    }
                                }
                            }
                        ]
                    }
                })
            }
            "tools/call" => {
                let params = parsed.get("params").cloned().unwrap_or(json!({}));
                let tool_name = params.get("name").and_then(|v| v.as_str()).unwrap_or("");
                let args = params.get("arguments").cloned().unwrap_or(json!({}));
                let tool_result = call_tool(tool_name, &args);
                json!({
                    "jsonrpc": "2.0",
                    "id": id,
                    "result": tool_result
                })
            }
            "shutdown" => {
                let shutdown_resp = json!({
                    "jsonrpc": "2.0",
                    "id": id,
                    "result": Value::Null
                });
                let _ = writeln!(out_handle, "{}", shutdown_resp);
                let _ = out_handle.flush();
                break;
            }
            _ => {
                json!({
                    "jsonrpc": "2.0",
                    "id": id,
                    "error": {
                        "code": -32601,
                        "message": format!("Method not found: {}", method)
                    }
                })
            }
        };

        let _ = writeln!(out_handle, "{}", response);
        let _ = out_handle.flush();
    }

    Ok(())
}
