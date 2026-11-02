//! Strongly-typed Intent and IntentResult NDJSON envelopes for Ghost v2.0.0 (EVOID IOP).

use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum Level {
    Ephemeral,
    Standard,
    Critical,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct Intent {
    pub id: String,
    pub name: String,
    pub level: Level,
    pub metadata: serde_json::Value,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum Status {
    Ok,
    Error,
    Timeout,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct IntentResult {
    pub id: String,
    pub status: Status,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub value: Option<serde_json::Value>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub error: Option<String>,
}

impl Intent {
    pub fn new(
        id: impl Into<String>,
        name: impl Into<String>,
        level: Level,
        metadata: serde_json::Value,
    ) -> Self {
        Self {
            id: id.into(),
            name: name.into(),
            level,
            metadata,
        }
    }

    pub fn from_ndjson_line(line: &str) -> Result<Self, serde_json::Error> {
        serde_json::from_str(line.trim())
    }

    pub fn to_ndjson_line(&self) -> Result<String, serde_json::Error> {
        serde_json::to_string(self)
    }
}

impl IntentResult {
    pub fn ok(id: impl Into<String>, value: Option<serde_json::Value>) -> Self {
        Self {
            id: id.into(),
            status: Status::Ok,
            value,
            error: None,
        }
    }

    pub fn error(id: impl Into<String>, err: impl Into<String>) -> Self {
        Self {
            id: id.into(),
            status: Status::Error,
            value: None,
            error: Some(err.into()),
        }
    }

    pub fn timeout(id: impl Into<String>, msg: Option<impl Into<String>>) -> Self {
        Self {
            id: id.into(),
            status: Status::Timeout,
            value: None,
            error: msg.map(|m| m.into()),
        }
    }

    pub fn from_ndjson_line(line: &str) -> Result<Self, serde_json::Error> {
        serde_json::from_str(line.trim())
    }

    pub fn to_ndjson_line(&self) -> Result<String, serde_json::Error> {
        serde_json::to_string(self)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_intent_ndjson_roundtrip() {
        let json = r#"{"id":"1","name":"ghost.popup.ping","level":"ephemeral","metadata":{}}"#;
        let intent = Intent::from_ndjson_line(json).expect("deserialize failed");
        assert_eq!(intent.id, "1");
        assert_eq!(intent.name, "ghost.popup.ping");
        assert_eq!(intent.level, Level::Ephemeral);
        assert_eq!(intent.metadata, serde_json::json!({}));

        let serialized = intent.to_ndjson_line().expect("serialize failed");
        assert_eq!(serialized, json);
    }

    #[test]
    fn test_intent_levels_serialization() {
        for (level, expected_str) in [
            (Level::Ephemeral, "ephemeral"),
            (Level::Standard, "standard"),
            (Level::Critical, "critical"),
        ] {
            let intent = Intent::new("test", "ghost.test", level, serde_json::json!({"k": 1}));
            let serialized = intent.to_ndjson_line().unwrap();
            assert!(serialized.contains(&format!("\"level\":\"{}\"", expected_str)));
        }
    }

    #[test]
    fn test_intent_result_ok_and_error() {
        let res_ok = IntentResult::ok("req-1", Some(serde_json::json!({"pong": true})));
        let line_ok = res_ok.to_ndjson_line().unwrap();
        assert!(line_ok.contains(r#""status":"ok""#));
        assert!(line_ok.contains(r#""pong":true"#));

        let res_err = IntentResult::error("req-2", "Intent handler failed");
        let line_err = res_err.to_ndjson_line().unwrap();
        assert!(line_err.contains(r#""status":"error""#));
        assert!(line_err.contains(r#""error":"Intent handler failed""#));
    }
}
