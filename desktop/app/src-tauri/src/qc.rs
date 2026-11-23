//! Quality check figures: the QC images (<ID>-QC-<n>.png) the batch process writes in
//! <project>/BatchOut/<batch>. The page shows them through Tauri's asset protocol, whose
//! scope starts empty: each listed batch folder is allowed on request (only that folder).
//!
//! SPDX-License-Identifier: GPL-3.0-or-later

use std::path::PathBuf;
use tauri::{AppHandle, Manager};

/// a single path component: no separators, no "." / ".."
fn plain(name: &str) -> bool {
    !name.is_empty() && name != "." && name != ".." && !name.contains(['/', '\\', ':'])
}

/// number in "<ID>-QC-<n>.png" for sorting (1, 2, ..., 10)
fn page_number(file: &str, prefix: &str) -> u32 {
    file[prefix.len()..]
        .chars()
        .take_while(|c| c.is_ascii_digit())
        .collect::<String>()
        .parse()
        .unwrap_or(u32::MAX)
}

/// The QC figures of one subject in one batch, in page order (empty if none).
#[tauri::command]
pub fn qc_images(app: AppHandle, project_dir: String, batch: String, subject: String) -> Result<Vec<String>, String> {
    if !plain(&batch) || !plain(&subject) {
        return Err("invalid batch or subject name".into());
    }
    let dir = PathBuf::from(&project_dir).join("BatchOut").join(&batch);
    if !dir.is_dir() {
        return Ok(vec![]);
    }
    let prefix = format!("{subject}-QC-");
    let mut files: Vec<(u32, String)> = std::fs::read_dir(&dir)
        .map_err(|e| e.to_string())?
        .filter_map(|e| e.ok())
        .filter_map(|e| {
            let name = e.file_name().to_string_lossy().to_string();
            (name.starts_with(&prefix) && name.to_lowercase().ends_with(".png"))
                .then(|| (page_number(&name, &prefix), e.path().to_string_lossy().to_string()))
        })
        .collect();
    files.sort();
    if !files.is_empty() {
        app.asset_protocol_scope().allow_directory(&dir, false).map_err(|e| e.to_string())?;
    }
    Ok(files.into_iter().map(|(_, p)| p).collect())
}
