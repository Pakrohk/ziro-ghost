use super::app::FocusApp;
use ratatui::{
    layout::{Constraint, Direction, Layout, Rect},
    style::{Color, Modifier, Style},
    text::{Line, Span},
    widgets::{Block, BorderType, Borders, Clear, List, ListItem, Paragraph},
    Frame,
};

fn centered_rect(percent_x: u16, height: u16, r: Rect) -> Rect {
    let popup_layout = Layout::default()
        .direction(Direction::Vertical)
        .constraints([
            Constraint::Length(r.height.saturating_sub(height) / 2),
            Constraint::Length(height),
            Constraint::Min(0),
        ])
        .split(r);

    Layout::default()
        .direction(Direction::Horizontal)
        .constraints([
            Constraint::Percentage((100 - percent_x) / 2),
            Constraint::Percentage(percent_x),
            Constraint::Percentage((100 - percent_x) / 2),
        ])
        .split(popup_layout[1])[1]
}

pub fn draw(f: &mut Frame, app: &FocusApp) {
    let item_count = app.items.len().min(12) as u16;
    let height = (item_count + 4).max(6).min(f.area().height.saturating_sub(2));
    let area = centered_rect(65, height, f.area());

    // Clear background behind popup
    f.render_widget(Clear, area);

    let chunks = Layout::default()
        .direction(Direction::Vertical)
        .constraints([Constraint::Min(item_count.max(1)), Constraint::Length(1)])
        .margin(1)
        .split(area);

    let block = Block::default()
        .title(Line::from(vec![
            Span::styled(" ghost ", Style::default().fg(Color::Cyan).add_modifier(Modifier::BOLD)),
            Span::styled("focus ", Style::default().fg(Color::White)),
        ]))
        .borders(Borders::ALL)
        .border_type(BorderType::Rounded)
        .border_style(Style::default().fg(Color::Rgb(137, 180, 250))); // Catppuccin blue

    f.render_widget(block, area);

    let list_items: Vec<ListItem> = app
        .items
        .iter()
        .enumerate()
        .map(|(i, item)| {
            if i == app.selected {
                ListItem::new(Line::from(vec![
                    Span::styled(" ▶ ", Style::default().fg(Color::Cyan).add_modifier(Modifier::BOLD)),
                    Span::styled(item, Style::default().fg(Color::White).add_modifier(Modifier::BOLD)),
                ]))
                .style(Style::default().bg(Color::Rgb(49, 50, 68))) // Catppuccin surface
            } else {
                ListItem::new(Line::from(vec![
                    Span::raw("   "),
                    Span::styled(item, Style::default().fg(Color::Rgb(205, 214, 244))),
                ]))
            }
        })
        .collect();

    let list = List::new(list_items);
    f.render_widget(list, chunks[0]);

    let footer = Paragraph::new(Line::from(vec![
        Span::styled("Tab/↓", Style::default().fg(Color::DarkGray).add_modifier(Modifier::BOLD)),
        Span::styled(" cycle · ", Style::default().fg(Color::DarkGray)),
        Span::styled("Enter", Style::default().fg(Color::DarkGray).add_modifier(Modifier::BOLD)),
        Span::styled(" accept · ", Style::default().fg(Color::DarkGray)),
        Span::styled("Esc", Style::default().fg(Color::DarkGray).add_modifier(Modifier::BOLD)),
        Span::styled(" cancel", Style::default().fg(Color::DarkGray)),
    ]));
    f.render_widget(footer, chunks[1]);
}
