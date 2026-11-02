use crossterm::{
    cursor::{Hide, Show},
    event::{self, Event, KeyCode, KeyEvent, KeyModifiers},
    execute,
    terminal::{disable_raw_mode, enable_raw_mode, EnterAlternateScreen, LeaveAlternateScreen},
};
use std::io::{self, stdout, Stdout};
use std::panic;
use std::sync::atomic::{AtomicBool, Ordering};

static TERMINAL_RAW: AtomicBool = AtomicBool::new(false);

pub struct TerminalGuard {
    _stdout: Stdout,
}

impl TerminalGuard {
    pub fn new() -> io::Result<Self> {
        let mut out = stdout();
        enable_raw_mode()?;
        TERMINAL_RAW.store(true, Ordering::SeqCst);

        // Global panic hook to guarantee terminal restoration on panic
        let default_panic = panic::take_hook();
        panic::set_hook(Box::new(move |panic_info| {
            let _ = disable_raw_mode();
            let mut out = io::stdout();
            let _ = execute!(out, Show, LeaveAlternateScreen);
            TERMINAL_RAW.store(false, Ordering::SeqCst);
            default_panic(panic_info);
        }));

        if let Err(e) = execute!(out, EnterAlternateScreen, Hide) {
            let _ = disable_raw_mode();
            TERMINAL_RAW.store(false, Ordering::SeqCst);
            return Err(e);
        }

        Ok(Self { _stdout: out })
    }
}

impl Drop for TerminalGuard {
    fn drop(&mut self) {
        let _ = execute!(self._stdout, Show, LeaveAlternateScreen);
        let _ = disable_raw_mode();
        TERMINAL_RAW.store(false, Ordering::SeqCst);
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Action {
    Next,
    Prev,
    Accept,
    Cancel,
}

pub fn read_action() -> io::Result<Option<Action>> {
    if event::poll(std::time::Duration::from_millis(50))? {
        if let Event::Key(KeyEvent {
            code, modifiers, ..
        }) = event::read()?
        {
            if modifiers.contains(KeyModifiers::CONTROL) && code == KeyCode::Char('c') {
                return Ok(Some(Action::Cancel));
            }
            return match code {
                KeyCode::Down | KeyCode::Tab | KeyCode::Char('j') => Ok(Some(Action::Next)),
                KeyCode::Up | KeyCode::BackTab | KeyCode::Char('k') => Ok(Some(Action::Prev)),
                KeyCode::Enter => Ok(Some(Action::Accept)),
                KeyCode::Esc | KeyCode::Char('q') => Ok(Some(Action::Cancel)),
                _ => Ok(None),
            };
        }
    }
    Ok(None)
}
