#![cfg_attr(all(not(debug_assertions), target_os = "windows"), windows_subsystem = "windows")]

use serde::Serialize;
use tauri::{
    command, Builder, CustomMenuItem, Manager, SystemTray, SystemTrayEvent, SystemTrayMenu,
    SystemTrayMenuItem,
};

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
struct DashboardStats {
    downloaded: u32,
    uploaded: u32,
    sync_status: String,
    last_sync: Option<String>,
    upload_queue: u32,
    download_queue: u32,
}

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
struct ActionResponse {
    message: String,
}

#[command]
fn fetch_dashboard() -> DashboardStats {
    DashboardStats {
        downloaded: 18,
        uploaded: 9,
        sync_status: "Ready".into(),
        last_sync: Some("Today · 04:30".into()),
        upload_queue: 3,
        download_queue: 0,
    }
}

#[command]
fn sync_now() -> ActionResponse {
    ActionResponse {
        message: "Sync job scheduled".into(),
    }
}

#[command]
fn download_now() -> ActionResponse {
    ActionResponse {
        message: "Download task triggered".into(),
    }
}

#[command]
fn upload_now() -> ActionResponse {
    ActionResponse {
        message: "Upload scan started".into(),
    }
}

#[command]
fn validate_connection() -> ActionResponse {
    ActionResponse {
        message: "Connection validated".into(),
    }
}

#[command]
fn check_duplicates() -> ActionResponse {
    ActionResponse {
        message: "Duplicate scan started".into(),
    }
}

#[command]
fn reset_settings() -> ActionResponse {
    ActionResponse {
        message: "Settings reset".into(),
    }
}

fn show_window(app: &tauri::AppHandle, label: &str) {
    if let Some(window) = app.get_window(label) {
        let _ = window.show();
        let _ = window.set_focus();
    }
}

fn handle_tray_event(app: &tauri::AppHandle, event: SystemTrayEvent) {
    match event {
        SystemTrayEvent::MenuItemClick(item) => match item.id.as_str() {
            "open_main" => show_window(app, "main"),
            "open_mini" => show_window(app, "mini"),
            "sync_now" => {
                let _ = sync_now();
            }
            "quit" => {
                std::process::exit(0);
            }
            _ => {}
        },
        SystemTrayEvent::LeftClick { .. } | SystemTrayEvent::RightClick { .. } => {
            show_window(app, "mini")
        }
        _ => {}
    }
}

fn main() {
    let open_main = CustomMenuItem::new("open_main".to_string(), "Open ImmichSync");
    let open_mini = CustomMenuItem::new("open_mini".to_string(), "Show Mini App");
    let sync_now_item = CustomMenuItem::new("sync_now".to_string(), "Sync now");
    let quit = CustomMenuItem::new("quit".to_string(), "Quit ImmichSync");
    let tray_menu = SystemTrayMenu::new()
        .add_item(open_main)
        .add_native_item(tauri::SystemTrayMenuItem::Separator)
        .add_item(open_mini)
        .add_item(sync_now_item)
        .add_native_item(tauri::SystemTrayMenuItem::Separator)
        .add_item(quit);

    Builder::default()
        .system_tray(SystemTray::new().with_menu(tray_menu))
        .on_system_tray_event(|app, event| handle_tray_event(app, event))
        .invoke_handler(tauri::generate_handler![
            fetch_dashboard,
            sync_now,
            download_now,
            upload_now,
            validate_connection,
            check_duplicates,
            reset_settings
        ])
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
