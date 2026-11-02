#[derive(Debug, Clone)]
pub struct FocusApp {
    pub items: Vec<String>,
    pub selected: usize,
    pub query: String,
}

impl FocusApp {
    pub fn new(items: Vec<String>) -> Self {
        Self {
            items,
            selected: 0,
            query: String::new(),
        }
    }

    pub fn next(&mut self) {
        if !self.items.is_empty() {
            self.selected = (self.selected + 1) % self.items.len();
        }
    }

    pub fn prev(&mut self) {
        if !self.items.is_empty() {
            if self.selected == 0 {
                self.selected = self.items.len() - 1;
            } else {
                self.selected -= 1;
            }
        }
    }

    pub fn current(&self) -> Option<&str> {
        self.items.get(self.selected).map(|s| s.as_str())
    }

    /// Simulate key sequence for hermetic CI testing without a TTY.
    /// Keys format: "down,down,enter" or "tab,tab,esc".
    /// Returns:
    /// - `Some(Some(text))` on accept
    /// - `Some(None)` on cancel / Esc
    /// - `None` if items list is empty
    pub fn apply_key_sequence(&mut self, keys: &str) -> Option<Option<String>> {
        if self.items.is_empty() {
            return None;
        }

        for token in keys.split(',') {
            let key = token.trim().to_lowercase();
            match key.as_str() {
                "down" | "tab" | "j" => self.next(),
                "up" | "backtab" | "k" => self.prev(),
                "enter" | "accept" => return Some(self.current().map(|s| s.to_string())),
                "esc" | "escape" | "cancel" => return Some(None),
                _ => {}
            }
        }

        // If sequence ended without explicit Enter or Esc, accept current selection
        Some(self.current().map(|s| s.to_string()))
    }
}
