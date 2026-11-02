use ghost_popup::ui::app::FocusApp;
use ghost_protocol::{Intent, Level};

#[test]
fn test_focus_enter_accept_first() {
    let mut app = FocusApp::new(vec!["a".into(), "b".into(), "c".into()]);
    let result = app.apply_key_sequence("enter").expect("should not be empty");
    assert_eq!(result, Some("a".into()));
}

#[test]
fn test_focus_enter_cycle_down_once() {
    let mut app = FocusApp::new(vec!["a".into(), "b".into(), "c".into()]);
    let result = app.apply_key_sequence("down,enter").expect("should not be empty");
    assert_eq!(result, Some("b".into()));
}

#[test]
fn test_focus_enter_cycle_down_twice() {
    let mut app = FocusApp::new(vec!["a".into(), "b".into(), "c".into()]);
    let result = app.apply_key_sequence("down,down,enter").expect("should not be empty");
    assert_eq!(result, Some("c".into()));
}

#[test]
fn test_focus_enter_wrap_around() {
    let mut app = FocusApp::new(vec!["a".into(), "b".into(), "c".into()]);
    let result = app.apply_key_sequence("up,enter").expect("should not be empty");
    assert_eq!(result, Some("c".into()));
}

#[test]
fn test_focus_enter_cancel() {
    let mut app = FocusApp::new(vec!["a".into(), "b".into(), "c".into()]);
    let result = app.apply_key_sequence("esc").expect("should not be empty");
    assert_eq!(result, None);
}

#[test]
fn test_focus_enter_empty_items() {
    let mut app = FocusApp::new(vec![]);
    let result = app.apply_key_sequence("enter");
    assert_eq!(result, None);
}

#[test]
fn test_focus_enter_single_item() {
    let mut app = FocusApp::new(vec!["a".into()]);
    let result = app.apply_key_sequence("down,enter").expect("should not be empty");
    assert_eq!(result, Some("a".into()));
}

#[test]
fn test_intent_serialization_focus_enter() {
    let intent = Intent::new(
        "f1",
        "ghost.popup.focus_enter",
        Level::Ephemeral,
        serde_json::json!({
            "items": ["git status", "git diff"],
            "test_keys": "down,enter"
        }),
    );
    let serialized = intent.to_ndjson_line().unwrap();
    let deserialized = Intent::from_ndjson_line(&serialized).unwrap();
    assert_eq!(deserialized.name, "ghost.popup.focus_enter");
    assert_eq!(
        deserialized.metadata["items"][0],
        serde_json::json!("git status")
    );
}
