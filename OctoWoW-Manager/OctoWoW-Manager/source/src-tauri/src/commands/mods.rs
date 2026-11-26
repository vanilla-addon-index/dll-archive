//! Game Mods (MPQ patches) and Client Tweaks (plugin catalog, custom DLLs).

use super::{blocking, changed, CmdResult};
use crate::core::{mpq, plugins};
use crate::state::AppState;
use std::path::PathBuf;
use tauri::{AppHandle, State};

#[tauri::command]
pub fn get_plugin_catalog() -> Vec<plugins::PluginInfo> {
    plugins::catalog()
}

/// Newest GitHub release tag per plugin file, for the version shown next to "Latest (GitHub)".
#[tauri::command]
pub async fn get_plugin_latest_versions() -> std::collections::HashMap<String, String> {
    plugins::latest_tags().await
}

#[tauri::command]
pub async fn scan_game_mods(state: State<'_, AppState>) -> CmdResult<Vec<mpq::MpqEntry>> {
    let dir = state.wow_dir()?;
    let meta = state.snapshot().game_mods_meta;
    blocking(move || mpq::scan(&dir, &meta).map_err(|e| format!("Couldn't read the Data folder: {e}"))).await
}

#[tauri::command]
pub fn mpq_set_enabled(app: AppHandle, state: State<AppState>, base_name: String, enabled: bool) -> CmdResult<()> {
    mpq::set_enabled(&state.wow_dir()?, &base_name, enabled)?;
    changed(&app, "gameMods");
    Ok(())
}

#[tauri::command]
pub fn mpq_delete(app: AppHandle, state: State<AppState>, file_name: String) -> CmdResult<()> {
    mpq::delete(&state.wow_dir()?, &file_name)?;
    changed(&app, "gameMods");
    Ok(())
}

/// Copies an .mpq into Data/. Returns the installed file name.
#[tauri::command]
pub async fn mpq_install(app: AppHandle, state: State<'_, AppState>, path: String) -> CmdResult<String> {
    let dir = state.wow_dir()?;
    let name = blocking(move || mpq::install(&dir, &PathBuf::from(path))).await?;
    changed(&app, "gameMods");
    Ok(name)
}

/// Copies a DLL into the game folder. Returns its file name.
#[tauri::command]
pub fn custom_dll_add(state: State<AppState>, path: String) -> CmdResult<String> {
    plugins::add_custom(&state.wow_dir()?, &PathBuf::from(path))
}

#[tauri::command]
pub fn custom_dll_remove(state: State<AppState>, file: String) -> CmdResult<()> {
    plugins::remove_custom(&state.wow_dir()?, &file)
}

#[tauri::command]
pub fn get_mod_catalog() -> Vec<crate::core::mod_catalog::ModInfo> { crate::core::mod_catalog::catalog() }
#[tauri::command]
pub async fn check_mod_updates(state: State<'_, AppState>, online: bool) -> CmdResult<Vec<crate::core::mod_catalog::ModStatus>> {
    let dir=state.wow_dir()?; Ok(crate::core::mod_catalog::check(&dir,online).await)
}
#[tauri::command]
pub fn catalog_mod_install(app: AppHandle,state: State<AppState>,id:String)->CmdResult<u64>{
    let dir=state.wow_dir()?;
    Ok(crate::jobs::spawn(&app.clone(),"Installing game mod",move |ctx| async move {
        if crate::core::platform::is_game_running(){return Err("Close WoW before installing mods".into());}
        crate::core::mod_catalog::install(&dir,&id).await?;
        ctx.changed("gameMods");ctx.changed("modInventory");Ok("Mod installed".into())
    }))
}
#[tauri::command]
pub async fn catalog_mod_toggle(app: AppHandle, state: State<'_, AppState>, id: String, enabled: bool) -> CmdResult<()> {
    let dir = state.wow_dir()?;
    blocking(move || {
        if crate::core::platform::is_game_running() {
            return Err("Close WoW before toggling mods".into());
        }
        crate::core::mod_catalog::toggle(&dir, &id, enabled)
    }).await?;
    changed(&app, "gameMods");
    Ok(())
}
#[tauri::command]
pub async fn get_plugin_inventory(state: State<'_, AppState>) -> CmdResult<crate::core::plugin_versions::Inventory> {
    let settings = state.snapshot();
    blocking(move || Ok(crate::core::plugin_versions::inspect(&settings))).await
}

#[tauri::command]
pub async fn check_plugin_updates(
    state: State<'_, AppState>,
    sources: std::collections::BTreeMap<String, crate::config::PluginSource>,
) -> CmdResult<crate::core::plugin_versions::UpstreamCheck> {
    let dir=state.wow_dir()?;
    let mut out = crate::core::plugin_versions::UpstreamCheck::default();
    for p in plugins::catalog(){
        let choice = sources.get(p.file).copied().unwrap_or_default();
        let Some(repo) = p.source else { continue };
        let Ok(local)=std::fs::read(dir.join(p.file))else{continue;};
        // The pinned nampower build is ahead of the GitHub release.
        if choice != crate::config::PluginSource::Latest && p.file == "nampower.dll" && crate::core::payload::bundled_dll(p.file) == Some(local.as_slice()) {
            continue;
        }
        match plugins::download_latest(repo,p.file).await {
            Ok((remote, tag)) => {
                if local == remote {
                    out.installed.insert(p.file.into(), tag);
                } else {
                    out.updates.insert(p.file.into(), tag);
                }
            },
            Err(e)=>{out.updates.insert(p.file.into(),format!("!{e}"));},
        }
    }Ok(out)
}
