// SPDX-License-Identifier: GPL-3.0-or-later

mod engine;
mod mail;
mod qc;

use engine::Engine;
use tauri::{Manager, RunEvent};

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    let app = tauri::Builder::default()
        .plugin(tauri_plugin_dialog::init())
        .plugin(tauri_plugin_opener::init())
        .manage(Engine::default())
        .invoke_handler(tauri::generate_handler![
            engine::engine_start,
            engine::engine_stop,
            engine::engine_status,
            engine::engine_request,
            engine::engine_info,
            qc::qc_images,
            mail::mail_with_attachment,
        ])
        .setup(|app| {
            // title bar: "Actipass <version>" (release builds carry e.g. 2026.11.3-alpha)
            if let Some(w) = app.get_webview_window("main") {
                let dev = if cfg!(debug_assertions) { " (development build)" } else { "" };
                let _ = w.set_title(&format!("Actipass {}{dev}", app.package_info().version));
            }
            Ok(())
        })
        .build(tauri::generate_context!())
        .expect("error while building tauri application");

    app.run(|handle, event| {
        if let RunEvent::Exit = event {
            // ask the engine to stop and end a MATLAB started by the app
            let engine = handle.state::<Engine>().inner().clone();
            let handle = handle.clone();
            tauri::async_runtime::block_on(async move { engine.stop(&handle).await });
        }
    });
}
