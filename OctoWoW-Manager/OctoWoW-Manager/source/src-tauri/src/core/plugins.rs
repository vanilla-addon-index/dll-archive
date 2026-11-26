//! Catalog of the DLL plugins shown on the Client Tweaks tab, plus custom DLLs
//! and "Latest (Upstream)" downloads. Installing happens in `apply`.

use super::util::get_bytes;
use serde::Serialize;
use std::io::Read;
use std::path::Path;

#[derive(Clone, Copy, Serialize)]
#[serde(rename_all = "camelCase")]
pub enum PluginGroup {
    Core,
    Optional,
}

#[derive(Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct PluginInfo {
    pub file: &'static str,
    pub group: PluginGroup,
    pub description: &'static str,
    pub default_enabled: bool,
    /// GitHub, OctoGit, or Codeberg repository, or direct HTTPS DLL URL.
    pub source: Option<&'static str>,
    /// Addon folder that ships alongside the DLL.
    pub companion_addon: Option<&'static str>,
}

const WEIRDUTILS_REPO: &str = "codeberg:MarcelineVQ/WeirdUtils";
const WEIRDUTILS_VERSION: &str = "v0.7.0";

const fn core(file: &'static str, description: &'static str) -> PluginInfo {
    PluginInfo {
        file,
        group: PluginGroup::Core,
        description,
        default_enabled: true,
        source: None,
        companion_addon: None,
    }
}

const fn optional(file: &'static str, description: &'static str) -> PluginInfo {
    PluginInfo {
        file,
        group: PluginGroup::Optional,
        description,
        default_enabled: false,
        source: Some(WEIRDUTILS_REPO),
        companion_addon: None,
    }
}

pub fn catalog() -> Vec<PluginInfo> {
    vec![
        PluginInfo {
            source: Some("brues-code/ClassicAPI"),
            ..core("ClassicAPI.dll", "Backports a massive part of the modern WoW API (550+ functions, Lua 5.1 syntax).")
        },
        PluginInfo {
            // "Latest" comes from brues-code's mirror; "Recommended" is the bundled copy.
            source: Some("brues-code/nampower"),
            companion_addon: Some("nampowersettings"),
            ..core("nampower.dll","Reduces spell input latency and enables spell queueing. Recommended bundles the brues-code build at 99d8d36.")
        },
        PluginInfo {
            source: Some("octogit:Hapto/DucielPerf"),
            ..core("ducielperf.dll", "Improves client performance and adds diagnostics, world markers, and an Interact key. Configure it in game with /dperf.")
        },
        PluginInfo {
            source: Some("https://raw.githubusercontent.com/RetroCro/TurtleWoW-Mods/refs/heads/main/Archive/DLL%20BACKUP/no1600x1200.dll"),
            ..core("no1600x1200.dll", "Removes the hardcoded 1600x1200 resolution limit.")
        },
        PluginInfo {
            source: Some("https://raw.githubusercontent.com/RetroCro/TurtleWoW-Mods/refs/heads/main/Archive/DLL%20BACKUP/perf_boost.dll"),
            companion_addon: Some("perfboostsettings"),
            ..core("perf_boost.dll", "Provides dynamic render distance controls (culling).")
        },
        PluginInfo {
            source: Some("balakethelock/SuperWoW"),
            companion_addon: Some("SuperAPI"),
            ..core("SuperWoWhook.dll", "Injects a massively expanded Lua API. Increases macro limit.")
        },
        PluginInfo {
            source: Some("brues-code/UnitXP_SP3"),
            companion_addon: Some("UnitXP_SP3_Addon"),
            ..core("UnitXP_SP3.dll", "Engine-level optimizations replacing legacy assembly.")
        },
        PluginInfo {
            source: Some("isfir/VanillaHelpers"),
            ..core("VanillaHelpers.dll", "Expands engine limits. Raises the client memory allocator from 2GB to 4GB.")
        },
        optional("bigcursor.dll", "Upscales the hardware cursor for improved visibility on modern resolutions."),
        optional("customassets.dll", "Enables loading loose game asset files from the Data/ directory."),
        optional("logsessions.dll", "Organizes combat and chat logs into clean, per-character, per-day files automatically."),
        optional("minimapicons.dll", "Adds TBC/WotLK-style minimap tracking icons for NPCs and objects."),
        optional("pngscreenshots.dll", "Saves screenshots as compressed PNG files to completely eliminate frame drops."),
        PluginInfo { source: Some("brues-code/AuctionQueryThrottle"), ..optional("AuctionQueryThrottle.dll", "Makes auction-house searches fast") },
        PluginInfo { source: Some("xnobus/lexara112"), ..optional("Lexara112.dll", "HD font renderer") },
        PluginInfo { source: Some("fmustafayaman/OctoLogin"), ..optional("OctoLogin.dll", "Keeps your login working while OctoWoW moves its servers around") },
    ]
}

pub fn is_replaced_plugin(file: &str) -> bool {
    [
        "weirdperformance.dll",
        "transmogfix.dll",
        "worldmarkers.dll",
        "interact.dll",
    ]
    .iter()
    .any(|name| file.eq_ignore_ascii_case(name))
}

pub fn is_catalog_plugin(file: &str) -> bool {
    catalog().iter().any(|p| p.file.eq_ignore_ascii_case(file))
}

async fn release_for(repo: &str) -> Result<serde_json::Value, String> {
    if let Some(repo) = repo.strip_prefix("codeberg:") {
        let bytes = get_bytes(&format!(
            "https://codeberg.org/api/v1/repos/{repo}/releases/tags/{WEIRDUTILS_VERSION}"
        ))
        .await?;
        return serde_json::from_slice(&bytes).map_err(|e| e.to_string());
    }
    if let Some(repo) = repo.strip_prefix("octogit:") {
        let bytes = get_bytes(&format!(
            "https://octowow.st/git/api/v1/repos/{repo}/releases/latest"
        ))
        .await?;
        return serde_json::from_slice(&bytes).map_err(|e| e.to_string());
    }
    let bytes = get_bytes(&format!(
        "https://api.github.com/repos/{repo}/releases/latest"
    ))
    .await?;
    serde_json::from_slice(&bytes).map_err(|e| e.to_string())
}
const RETROCRO_VERSION: &str = "Version from RetroCro";

fn release_version(release: &serde_json::Value, file: &str) -> Option<String> {
    if file.eq_ignore_ascii_case("SuperWoWhook.dll") {
        if let Some(version) = release["name"]
            .as_str()
            .and_then(|name| name.strip_prefix("SuperWoW "))
        {
            return Some(version.trim().to_string());
        }
    }
    release["tag_name"].as_str().map(str::to_string)
}

async fn tag_for(repo: &str, file: &str) -> Result<String, String> {
    if repo == WEIRDUTILS_REPO {
        return Ok(WEIRDUTILS_VERSION.into());
    }
    if repo.starts_with("https://") {
        return Ok(RETROCRO_VERSION.into());
    }
    release_version(&release_for(repo).await?, file).ok_or("Missing release tag".into())
}
pub async fn latest_tags() -> std::collections::HashMap<String, String> {
    let jobs: Vec<_> = catalog()
        .into_iter()
        .filter_map(|p| {
            p.source
                .map(|repo| (p.file, tokio::spawn(tag_for(repo, p.file))))
        })
        .collect();
    let mut out = std::collections::HashMap::new();
    for (file, job) in jobs {
        if let Ok(Ok(tag)) = job.await {
            out.insert(file.to_string(), tag);
        }
    }
    out
}

/// Downloads the newest GitHub release's copy of `file`: a `.dll` asset, or the
/// matching file inside a `.zip` asset (v2.6 only handled bare DLLs).
/// Returns `(bytes, tag)`.
pub async fn download_latest(repo: &str, file: &str) -> Result<(Vec<u8>, String), String> {
    if repo.starts_with("https://") {
        let bytes = get_bytes(repo).await?;
        validate_dll(&bytes)?;
        return Ok((bytes, RETROCRO_VERSION.into()));
    }
    let release = release_for(repo).await?;
    let tag = release_version(&release, file).unwrap_or_else(|| "Unknown version".into());
    let assets = release["assets"].as_array().cloned().unwrap_or_default();
    let named = |pred: &dyn Fn(&str) -> bool| {
        assets
            .iter()
            .find(|a| a["name"].as_str().is_some_and(pred))
            .and_then(|a| a["browser_download_url"].as_str())
            .map(str::to_string)
    };
    let lower = file.to_ascii_lowercase();
    if let Some(url) = named(&|n| n.eq_ignore_ascii_case(file)) {
        let bytes = get_bytes(&url).await?;
        validate_dll(&bytes)?;
        return Ok((bytes, tag));
    }
    if let Some(url) = named(&|n| n.to_ascii_lowercase().ends_with(".zip")) {
        let bytes = get_bytes(&url).await?;
        let mut zip =
            zip::ZipArchive::new(std::io::Cursor::new(bytes)).map_err(|e| e.to_string())?;
        for i in 0..zip.len() {
            let mut entry = zip.by_index(i).map_err(|e| e.to_string())?;
            let name = entry
                .name()
                .map_err(|e| e.to_string())?
                .rsplit(['/', '\\'])
                .next()
                .unwrap_or("")
                .to_ascii_lowercase();
            if name == lower {
                let mut out = Vec::new();
                entry.read_to_end(&mut out).map_err(|e| e.to_string())?;
                validate_dll(&out)?;
                return Ok((out, tag));
            }
        }
        return Err(format!("{file} not found in the {tag} release zip"));
    }
    Err(format!("the {tag} release has no {file}"))
}

/// Copies a custom DLL into the game folder. Returns its file name.
pub fn add_custom(wow_dir: &Path, src: &Path) -> Result<String, String> {
    let name = src
        .file_name()
        .map(|n| n.to_string_lossy().into_owned())
        .ok_or("Not a file")?;
    if !name.to_ascii_lowercase().ends_with(".dll") {
        return Err(format!("{name} is not a .dll"));
    }
    if is_replaced_plugin(&name) {
        return Err(format!("{name} is replaced by DucielPerf."));
    }
    if is_catalog_plugin(&name) {
        return Err(format!(
            "{name} is already managed by the manager; toggle it above instead."
        ));
    }
    if name.eq_ignore_ascii_case("d3d9.dll") {
        return Err("d3d9.dll is managed by the DXVK setting.".into());
    }
    let dest = wow_dir.join(&name);
    let same = std::fs::canonicalize(src)
        .ok()
        .zip(std::fs::canonicalize(&dest).ok())
        .is_some_and(|(a, b)| a == b);
    if !same {
        std::fs::copy(src, &dest)
            .map_err(|e| format!("Couldn't copy {name} into your game folder: {e}"))?;
    }
    Ok(name)
}

pub fn remove_custom(wow_dir: &Path, file: &str) -> Result<(), String> {
    if file.contains(['/', '\\', ':']) || is_catalog_plugin(file) {
        return Err(format!("Refusing to delete {file}"));
    }
    match std::fs::remove_file(wow_dir.join(file)) {
        Ok(()) => Ok(()),
        Err(e) if e.kind() == std::io::ErrorKind::NotFound => Ok(()),
        Err(e) => Err(format!(
            "Couldn't delete {file} (is the game running?): {e}"
        )),
    }
}

#[cfg(test)]
mod tests {
    /// "Latest (GitHub)" for UnitXP comes from brues-code's fork and must be a 32-bit DLL.
    #[tokio::test]
    #[ignore]
    async fn live_unitxp_latest() {
        let (dll, tag) = super::download_latest("brues-code/UnitXP_SP3", "UnitXP_SP3.dll")
            .await
            .unwrap();
        let pe = u32::from_le_bytes(dll[0x3c..0x40].try_into().unwrap()) as usize;
        assert_eq!(
            &dll[pe + 4..pe + 6],
            &0x14cu16.to_le_bytes(),
            "32-bit, like WoW"
        );
        println!("UnitXP_SP3.dll {tag}: {} bytes", dll.len());
    }
}

/// Detect the hook independently of staged plugin settings.
pub fn has_superwow(dir: &Path) -> bool {
    std::fs::read_dir(dir)
        .into_iter()
        .flatten()
        .flatten()
        .any(|e| {
            e.file_name()
                .to_string_lossy()
                .eq_ignore_ascii_case("SuperWoWhook.dll")
                && e.path().is_file()
        })
}

fn validate_dll(bytes: &[u8]) -> Result<(), String> {
    if bytes.len() < 0x40 || bytes.get(..2) != Some(&b"MZ"[..]) {
        return Err("Downloaded file is not a Windows DLL".into());
    }
    let pe = u32::from_le_bytes(bytes[0x3c..0x40].try_into().unwrap()) as usize;
    if bytes.get(pe..pe.saturating_add(4)) != Some(&b"PE\0\0"[..]) {
        return Err("Downloaded DLL has no valid PE header".into());
    }
    let header = bytes
        .get(pe..pe.saturating_add(24))
        .ok_or("Truncated DLL header")?;
    let flags = u16::from_le_bytes([header[22], header[23]]);
    if header[4..6] != [0x4c, 0x01] || flags & 0x2000 == 0 {
        return Err("Downloaded file is not a 32-bit x86 DLL".into());
    }
    Ok(())
}
