//! Curated visual/audio packages. Only known paths are installed; unknown files
//! are backed up and restored when a loose sound replacement is disabled.
use super::util::{get_bytes, http};
use serde::{Deserialize, Serialize};
use sha1::{Digest, Sha1};
use std::{collections::BTreeMap, io::Read, path::Path};

const MUTE_BILLY_ID: &str = "mute-billy";
const MUTE_BILLY_MPQ: &[u8] = include_bytes!("../../assets/mute-billy.mpq");

#[derive(Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct ModInfo {
    pub id: &'static str,
    pub title: &'static str,
    pub category: &'static str,
    pub description: &'static str,
    pub file: &'static str,
    #[serde(skip)]
    pub url: &'static str,
    #[serde(skip)]
    pub repo: &'static str,
    #[serde(skip)]
    pub branch: &'static str,
    #[serde(skip)]
    pub prefix: &'static str,
}
pub fn catalog() -> Vec<ModInfo> {
    vec![
    ModInfo { id:"patch-o", title:"OctoWoW Patch-O", category:"Visual", description:"Official OctoWoW Patch-O, checked against the latest client download.", file:"Data/patch-O.mpq", url:"https://dl.octowow.st/client/latest/Data/patch-O.mpq", repo:"", branch:"", prefix:"" },
    ModInfo { id:"darker-nights", title:"Darker Nights", category:"Visual", description:"Installs Project Reforged Patch-N for darker, more atmospheric nights. Installed file: Data/patch-N.mpq. Project Reforged recommends VanillaHelpers.", file:"Data/patch-N.mpq", url:"https://pub-0f05631d243e4046993fc02ca7be9542.r2.dev/patches/patch-N.mpq", repo:"", branch:"", prefix:"" },
    ModInfo { id:"night-sky", title:"Pretty Night Sky", category:"Visual", description:"Replaces the Vanilla night sky with a more detailed starry sky. Installed file: Data/patch-Z.mpq. The original hosted patch-9 name is deliberately changed so the official numeric patch-9.mpq is never overwritten.", file:"Data/patch-Z.mpq", url:"https://drive.usercontent.google.com/download?id=1qu99ZS-SQFfTtYodBmZWYiHmxL8QtUY4&export=download&confirm=t", repo:"", branch:"", prefix:"" },
    ModInfo { id:"epoch-water", title:"Epoch Water", category:"Visual", description:"Replaces Vanilla water textures with the Epoch Water visual pack. Installed file: Data/patch-W.mpq.", file:"Data/patch-W.mpq", url:"https://drive.usercontent.google.com/download?id=1xRx9OrznbgbE1uBae3H3OGke9UoXtzmU&export=download&confirm=t", repo:"", branch:"", prefix:"" },
    ModInfo { id:"fog-pushback", title:"Fog Pushback", category:"Visual", description:"Pushes environmental fog farther back for a clearer long-distance view. Installed file: Data/patch-Y.mpq. Works best together with an increased Farclip value.", file:"Data/patch-Y.mpq", url:"https://drive.usercontent.google.com/download?id=14aHvyfr_ACL-UURbNa_fXRPcfQZoIw8n&export=download&confirm=t", repo:"", branch:"", prefix:"" },
    ModInfo { id:"pink-herbs", title:"Pink Herbs", category:"Visual", description:"Turns most herb-node textures bright pink/purple to make gathering nodes easier to spot. Installed file: Data/patch-V.mpq. The patch-V name avoids conflicts with other visual packs that use patch-H.mpq.", file:"Data/patch-V.mpq", url:"", repo:"seacrabsam/patch-herb", branch:"main", prefix:"" },
    ModInfo { id:"no-error-sounds", title:"NoErrorSounds", category:"Audio", description:"Installs the complete NoErrorSounds pack: muted spell fizzle sounds plus its included muted interface sounds. Installed as loose WAV files under Sound/Spells/Fizzle and Sound/interface (no MPQ).", file:"", url:"", repo:"Macumbafeh/NoErrorSounds", branch:"main", prefix:"Sound" },
    ModInfo { id:"fish-ping", title:"FishPing", category:"Audio", description:"Replaces the fishing bite sound with a much more noticeable ping. Installed file: Sound/Spells/Tradeskills/FishBite.wav (no MPQ). Designed specifically for WoW Vanilla 1.12.1.", file:"", url:"", repo:"notsureawake/FishPing", branch:"master", prefix:"Sound" },
    ModInfo { id:"muted-demons", title:"Warlock Muted Demons", category:"Audio", description:"Mutes the repeated voice lines from Warlock demons using Vanilla-compatible loose sound replacements. Installed as loose WAV files under Data/Sound/Creature (no MPQ).", file:"", url:"", repo:"spzilyk/Warlock-Muted-Demons", branch:"main", prefix:"Data" },
    ModInfo { id:MUTE_BILLY_ID, title:"Mute Billy", category:"Audio", description:"Silenced the annoying duck quack loop.", file:"Data/patch-X.mpq", url:"", repo:"", branch:"", prefix:"" },
]
}
fn find(id: &str) -> Result<ModInfo, String> {
    catalog()
        .into_iter()
        .find(|m| m.id == id)
        .ok_or("Unknown mod".into())
}
fn digest(bytes: &[u8]) -> String {
    super::torrent::hex(&Sha1::digest(bytes))
}
#[derive(Default, Serialize, Deserialize)]
struct Receipt {
    revision: String,
    enabled: bool,
    files: BTreeMap<String, String>,
}
fn read_receipt(root: &Path, m: &ModInfo) -> Option<Receipt> {
    serde_json::from_slice(
        &std::fs::read(root.join(".octowow-mods").join(m.id).join("receipt.json")).ok()?,
    )
    .ok()
}
fn safe(m: &ModInfo, p: &str) -> bool {
    if p.contains(['\\', ':']) || p.split('/').any(|s| s.is_empty() || s == ".." || s == ".") {
        return false;
    }
    if !m.file.is_empty() {
        return p == m.file;
    }
    p.to_ascii_lowercase().ends_with(".wav")
        && if m.prefix == "Data" {
            p.starts_with("Data/Sound/Creature/")
        } else {
            p.starts_with("Sound/")
        }
}
fn secure(root: &Path, p: &str) -> Result<(), String> {
    let mut path = root.to_path_buf();
    for part in p.split('/') {
        path.push(part);
        if let Ok(meta) = std::fs::symlink_metadata(&path) {
            #[cfg(windows)]
            {
                use std::os::windows::fs::MetadataExt;
                if meta.file_attributes() & 0x400 != 0 {
                    return Err("Refusing a linked mod path".into());
                }
            }
            if meta.file_type().is_symlink() {
                return Err("Refusing a linked mod path".into());
            }
        }
    }
    Ok(())
}
async fn revision(m: &ModInfo) -> Result<String, String> {
    if !m.repo.is_empty() {
        let url = format!(
            "https://api.github.com/repos/{}/commits/{}",
            m.repo, m.branch
        );
        let v: serde_json::Value =
            serde_json::from_slice(&get_bytes(&url).await?).map_err(|e| e.to_string())?;
        return v["sha"]
            .as_str()
            .map(str::to_string)
            .ok_or("Missing upstream revision".into());
    }
    let res = http()
        .head(m.url)
        .send()
        .await
        .map_err(|e| e.to_string())?
        .error_for_status()
        .map_err(|e| e.to_string())?;
    let h = res.headers();
    let tag = h
        .get("etag")
        .or_else(|| h.get("last-modified"))
        .and_then(|v| v.to_str().ok())
        .unwrap_or("");
    if tag.is_empty() {
        return remote_hash(m.url).await.map(|hash| format!("sha1:{hash}"));
    }
    Ok(format!(
        "{}:{}",
        tag,
        h.get("content-length")
            .and_then(|v| v.to_str().ok())
            .unwrap_or("")
    ))
}
#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
pub struct ModStatus {
    pub id: String,
    pub installed: bool,
    pub enabled: bool,
    pub managed: bool,
    pub update_available: bool,
    pub detail: String,
}
async fn remote_hash(url: &str) -> Result<String, String> {
    let mut res = http()
        .get(url)
        .send()
        .await
        .map_err(|e| e.to_string())?
        .error_for_status()
        .map_err(|e| e.to_string())?;
    let mut hash = Sha1::new();
    let mut signature = Vec::with_capacity(4);
    while let Some(bytes) = res.chunk().await.map_err(|e| e.to_string())? {
        if signature.len() < 4 {
            let take = (4 - signature.len()).min(bytes.len());
            signature.extend_from_slice(&bytes[..take]);
            if signature.len() == 4 && signature.as_slice() != b"MPQ\x1a" {
                return Err("Source did not return an MPQ".into());
            }
        }
        hash.update(&bytes);
    }
    if signature.len() < 4 {
        return Err("Empty download".into());
    }
    Ok(super::torrent::hex(&hash.finalize()))
}
pub async fn check(root: &Path, online: bool) -> Vec<ModStatus> {
    let mut out = Vec::new();
    for m in catalog() {
        out.push(check_one(root, &m, online).await);
    }
    out
}
async fn check_one(root: &Path, m: &ModInfo, online: bool) -> ModStatus {
    let receipt = read_receipt(root, m);
    let present = m.id != MUTE_BILLY_ID
        && !m.file.is_empty()
        && (root.join(m.file).is_file() || root.join(format!("{}.disabled", m.file)).is_file());
    let enabled = receipt
        .as_ref()
        .map(|r| r.enabled)
        .unwrap_or_else(|| root.join(m.file).is_file());
    let mut s = ModStatus {
        id: m.id.into(),
        installed: receipt.is_some() || present,
        enabled,
        managed: receipt.is_some(),
        update_available: false,
        detail: String::new(),
    };
    if !online {
        return s;
    }
    if m.id == MUTE_BILLY_ID {
        if s.installed {
            let path = if enabled {
                root.join(m.file)
            } else {
                root.join(format!("{}.disabled", m.file))
            };
            match std::fs::read(path) {
                Ok(bytes) => {
                    s.update_available = bytes.as_slice() != MUTE_BILLY_MPQ;
                    s.detail = if s.update_available {
                        "Bundled patch differs; reinstall to repair"
                    } else {
                        "Up to date"
                    }
                    .into();
                }
                Err(e) if e.kind() == std::io::ErrorKind::NotFound => {
                    s.update_available = true;
                    s.detail = "Bundled patch missing; reinstall to repair".into();
                }
                Err(e) => s.detail = format!("Update check unavailable: {e}"),
            }
        } else {
            s.detail = "Available to install offline".into();
        }
        return s;
    }
    // Direct MPQs have no release version. Compare downloaded content with the
    // actual installed file, ignoring HTTP validators and legacy receipt revisions.
    if m.repo.is_empty() && !m.file.is_empty() {
        if !s.installed {
            s.detail = "Available to install".into();
            return s;
        }
        match remote_hash(m.url).await {
            Ok(remote) => {
                let path = if enabled {
                    root.join(m.file)
                } else {
                    root.join(format!("{}.disabled", m.file))
                };
                match std::fs::read(path) {
                    Ok(local) => {
                        s.update_available = digest(&local) != remote;
                        s.detail = if s.update_available {
                            "Update available (contents differ from upstream)"
                        } else {
                            "Up to date"
                        }
                        .into();
                    }
                    Err(e) if e.kind() == std::io::ErrorKind::NotFound => {
                        s.update_available = true;
                        s.detail = "Installed file missing; reinstall to repair".into();
                    }
                    Err(e) => {
                        s.detail =
                            format!("Update check unavailable: could not read installed file: {e}")
                    }
                }
            }
            Err(e) => s.detail = format!("Update check unavailable: {e}"),
        }
        return s;
    }
    match revision(m).await {
        Ok(latest) => {
            if let Some(r) = receipt {
                let changed = r.files.iter().any(|(p, h)| {
                    if !safe(m, p) {
                        return true;
                    }
                    let path = if r.enabled {
                        root.join(p)
                    } else {
                        root.join(format!("{p}.disabled"))
                    };
                    std::fs::read(path)
                        .map(|b| digest(&b) != *h)
                        .unwrap_or(true)
                });
                s.update_available = changed || r.revision != latest || r.revision.is_empty();
                s.detail = if s.update_available {
                    "Update available"
                } else {
                    "Up to date"
                }
                .into();
            } else if present {
                let url = format!(
                    "https://raw.githubusercontent.com/{}/{}/patch-H.mpq",
                    m.repo, latest
                );
                match remote_hash(&url).await {
                    Ok(remote) => {
                        let path = if enabled {
                            root.join(m.file)
                        } else {
                            root.join(format!("{}.disabled", m.file))
                        };
                        match std::fs::read(path) {
                            Ok(local) => {
                                s.update_available = digest(&local) != remote;
                                s.detail = if s.update_available {
                                    "Update available"
                                } else {
                                    "Up to date"
                                }
                                .into();
                            }
                            Err(e) => s.detail = e.to_string(),
                        }
                    }
                    Err(e) => s.detail = format!("Update check unavailable: {e}"),
                }
            } else {
                s.detail = "Available to install".into();
            }
        }
        Err(e) => s.detail = format!("Update check unavailable: {e}"),
    }
    s
}
/// All mutations are renames, rolled back in reverse order on failure.
fn moves(root: &Path, ops: &[(std::path::PathBuf, std::path::PathBuf)]) -> Result<(), String> {
    let mut done: Vec<&(std::path::PathBuf, std::path::PathBuf)> = Vec::new();
    for op in ops {
        for p in [&op.0, &op.1] {
            let rel = p
                .strip_prefix(root)
                .map_err(|_| "Mod path escaped game folder")?;
            secure(root, &rel.to_string_lossy().replace('\\', "/"))?;
        }
    }
    for op in ops {
        let result = (|| {
            if let Some(p) = op.1.parent() {
                std::fs::create_dir_all(p)?;
            }
            std::fs::rename(&op.0, &op.1)
        })();
        if let Err(e) = result {
            let mut rollback = Vec::new();
            for prev in done.into_iter().rev() {
                if let Err(err) = std::fs::rename(&prev.1, &prev.0) {
                    rollback.push(err.to_string());
                }
            }
            return Err(format!(
                "Couldn't change mod files: {e}. Rollback errors: {}",
                rollback.join("; ")
            ));
        }
        done.push(op);
    }
    Ok(())
}
pub async fn install(root: &Path, id: &str) -> Result<(), String> {
    let m = find(id)?;
    secure(root, ".octowow-mods")?;
    let previous = read_receipt(root, &m);
    let mut rev = if m.repo.is_empty() {
        String::new()
    } else {
        revision(&m).await.unwrap_or_default()
    };
    let mut files = BTreeMap::new();
    if m.id == MUTE_BILLY_ID {
        secure(root, "Data")?;
        if previous.is_none() {
            for entry in std::fs::read_dir(root.join("Data"))
                .map_err(|e| format!("Couldn't read the Data folder: {e}"))?
            {
                let name = entry.map_err(|e| e.to_string())?.file_name();
                if ["patch-X.mpq", "patch-X.mpq.disabled"]
                    .iter()
                    .any(|slot| name.to_string_lossy().eq_ignore_ascii_case(slot))
                {
                    return Err("Mute Billy needs the patch-X.mpq slot, which is already occupied. Move the existing patch to another free slot first.".into());
                }
            }
        }
        rev = format!("sha1:{}", digest(MUTE_BILLY_MPQ));
        files.insert(m.file.to_string(), MUTE_BILLY_MPQ.to_vec());
    } else if !m.file.is_empty() {
        let url = if m.repo.is_empty() {
            m.url.to_string()
        } else {
            format!(
                "https://raw.githubusercontent.com/{}/{}/patch-H.mpq",
                m.repo,
                if rev.is_empty() { m.branch } else { &rev }
            )
        };
        let data = get_bytes(&url).await?;
        if data.get(..4) != Some(&b"MPQ\x1a"[..]) {
            return Err("Download is not an MPQ archive; existing file kept".into());
        }
        if m.repo.is_empty() {
            rev = format!("sha1:{}", digest(&data));
        }
        files.insert(m.file.to_string(), data);
    } else {
        if rev.is_empty() {
            return Err("Couldn't determine sound pack revision".into());
        }
        let data = get_bytes(&format!("https://codeload.github.com/{}/zip/{rev}", m.repo)).await?;
        let mut zip =
            zip::ZipArchive::new(std::io::Cursor::new(data)).map_err(|e| e.to_string())?;
        for i in 0..zip.len() {
            let mut entry = zip.by_index(i).map_err(|e| e.to_string())?;
            if entry.is_dir() {
                continue;
            }
            let Some(path) = entry.enclosed_name() else {
                return Err("Unsafe archive path".into());
            };
            let name = path.to_string_lossy().replace('\\', "/");
            let Some((_, rel)) = name.split_once('/') else {
                continue;
            };
            if !rel.starts_with(&format!("{}/", m.prefix))
                || !rel.to_ascii_lowercase().ends_with(".wav")
            {
                continue;
            }
            if !safe(&m, rel) {
                return Err(format!("Unexpected sound path: {rel}"));
            }
            let mut bytes = Vec::new();
            entry.read_to_end(&mut bytes).map_err(|e| e.to_string())?;
            // Packs may use empty WAV files to mute sounds.
            if !bytes.is_empty() && bytes.get(..4) != Some(&b"RIFF"[..]) {
                return Err(format!("Invalid WAV: {rel}"));
            }
            files.insert(rel.to_string(), bytes);
        }
        if files.is_empty() {
            return Err("Sound pack contains no supported WAV files".into());
        }
    }
    let state = root.join(".octowow-mods").join(m.id);
    secure(root, &format!(".octowow-mods/{}", m.id))?;
    std::fs::create_dir_all(&state).map_err(|e| e.to_string())?;
    let stage = super::util::scratch_dir(&state, "install")?;
    let mut receipt = Receipt {
        revision: rev,
        enabled: previous.as_ref().map(|r| r.enabled).unwrap_or_else(|| {
            m.file.is_empty()
                || root.join(m.file).is_file()
                || !root.join(format!("{}.disabled", m.file)).is_file()
        }),
        files: BTreeMap::new(),
    };
    let mut ops = Vec::new();
    for (p, bytes) in &files {
        if !safe(&m, p) {
            return Err("Unsafe mod path".into());
        }
        secure(root, p)?;
        let target = if receipt.enabled {
            root.join(p)
        } else {
            root.join(format!("{p}.disabled"))
        };
        secure(root, &format!("{p}.disabled"))?;
        let tmp = stage.join("new").join(p);
        std::fs::create_dir_all(tmp.parent().unwrap()).map_err(|e| e.to_string())?;
        std::fs::write(&tmp, bytes).map_err(|e| e.to_string())?;
        let known = previous.as_ref().is_some_and(|r| r.files.contains_key(p));
        if target.exists() {
            let backup = if known {
                stage.join("old").join(p)
            } else {
                state.join("original").join(p)
            };
            if backup.exists() {
                return Err(format!("Backup already exists for {p}"));
            }
            ops.push((target.clone(), backup));
        }
        ops.push((tmp, target));
        receipt.files.insert(p.clone(), digest(bytes));
    }
    // Retire paths removed by upstream and restore the files they replaced.
    if let Some(old) = previous {
        for (p, h) in old.files {
            if receipt.files.contains_key(&p) {
                continue;
            }
            if !safe(&m, &p) {
                return Err("Unsafe old receipt path".into());
            }
            let active = if old.enabled {
                root.join(&p)
            } else {
                root.join(format!("{p}.disabled"))
            };
            let data = std::fs::read(&active).map_err(|e| e.to_string())?;
            if digest(&data) != h {
                return Err(format!("{p} was edited; refusing to retire it"));
            }
            ops.push((active, stage.join("retired").join(&p)));
            let original = state.join("original").join(&p);
            if old.enabled && original.exists() {
                ops.push((original, root.join(&p)));
            }
        }
    }
    let tmp_receipt = stage.join("receipt.json");
    std::fs::write(
        &tmp_receipt,
        serde_json::to_vec_pretty(&receipt).map_err(|e| e.to_string())?,
    )
    .map_err(|e| e.to_string())?;
    let dest = state.join("receipt.json");
    if dest.exists() {
        ops.push((dest.clone(), stage.join("old-receipt.json")));
    }
    ops.push((tmp_receipt, dest));
    moves(root, &ops)?;
    // Prior managed versions remain in the staging backup for recovery.
    Ok(())
}
pub fn toggle(root: &Path, id: &str, enabled: bool) -> Result<(), String> {
    let m = find(id)?;
    let mut r =
        read_receipt(root, &m).ok_or("Install through the catalog before toggling this mod")?;
    if r.enabled == enabled {
        return Ok(());
    }
    let state = root.join(".octowow-mods").join(m.id);
    secure(root, &format!(".octowow-mods/{}", m.id))?;
    let mut ops = Vec::new();
    for (p, hash) in &r.files {
        if !safe(&m, p) {
            return Err("Unsafe receipt path".into());
        }
        secure(root, p)?;
        secure(root, &format!("{p}.disabled"))?;
        let on = root.join(p);
        let off = root.join(format!("{p}.disabled"));
        let source = if enabled { &off } else { &on };
        let data = std::fs::read(source).map_err(|e| format!("{p}: {e}"))?;
        if digest(&data) != *hash {
            return Err(format!(
                "{p} was modified outside the Manager; left unchanged"
            ));
        }
        let original = state.join("original").join(p);
        if enabled {
            if on.exists() {
                if original.exists() {
                    return Err(format!("Conflicting backup for {p}"));
                }
                ops.push((on.clone(), original));
            }
            ops.push((off, on));
        } else {
            if off.exists() {
                return Err(format!("Disabled copy already exists for {p}"));
            }
            ops.push((on.clone(), off));
            if original.exists() {
                ops.push((original, on));
            }
        }
    }
    r.enabled = enabled;
    let stage = super::util::scratch_dir(&state, "toggle")?;
    let tmp = stage.join("receipt.json");
    std::fs::write(
        &tmp,
        serde_json::to_vec_pretty(&r).map_err(|e| e.to_string())?,
    )
    .map_err(|e| e.to_string())?;
    ops.push((state.join("receipt.json"), stage.join("old-receipt.json")));
    ops.push((tmp, state.join("receipt.json")));
    moves(root, &ops)
}

pub fn is_managed_mpq(root: &Path, name: &str) -> bool {
    catalog().iter().any(|m| {
        !m.file.is_empty()
            && m.file
                .rsplit('/')
                .next()
                .is_some_and(|f| f.eq_ignore_ascii_case(name))
            && read_receipt(root, m).is_some()
    })
}

#[cfg(test)]
mod tests {
    use super::*;

    #[tokio::test]
    async fn mute_billy_installs_and_toggles_offline_without_occupying_an_existing_slot() {
        let root = super::super::util::scratch_dir(&std::env::temp_dir(), "mute-billy").unwrap();
        std::fs::create_dir_all(root.join("Data")).unwrap();
        let m = find(MUTE_BILLY_ID).unwrap();
        let taken = root.join("Data/patch-x.mpq.disabled");
        std::fs::write(&taken, b"existing custom patch").unwrap();
        assert!(install(&root, m.id)
            .await
            .unwrap_err()
            .contains("already occupied"));
        assert_eq!(std::fs::read(&taken).unwrap(), b"existing custom patch");
        std::fs::remove_file(&taken).unwrap();

        install(&root, m.id).await.unwrap();
        assert_eq!(
            std::fs::read(root.join(m.file)).unwrap().as_slice(),
            MUTE_BILLY_MPQ
        );
        let installed = check_one(&root, &m, true).await;
        assert!(installed.managed && installed.enabled && !installed.update_available);

        toggle(&root, m.id, false).unwrap();
        assert!(!root.join(m.file).exists());
        let disabled = check_one(&root, &m, true).await;
        assert!(disabled.managed && !disabled.enabled && !disabled.update_available);
        toggle(&root, m.id, true).unwrap();
        assert_eq!(
            std::fs::read(root.join(m.file)).unwrap().as_slice(),
            MUTE_BILLY_MPQ
        );
        std::fs::remove_dir_all(root).unwrap();
    }
    #[tokio::test]
    async fn direct_mpq_checks_survive_restart_header_changes_and_network_errors() {
        use std::{
            io::{Read, Write},
            net::TcpListener,
        };
        let listener = TcpListener::bind("127.0.0.1:0").unwrap();
        let url = Box::leak(
            format!("http://{}/patch-O.mpq", listener.local_addr().unwrap()).into_boxed_str(),
        );
        let same = b"MPQ\x1aold1";
        let newer = b"MPQ\x1anew1";
        let mut replies = vec![
            (200, same.as_slice()),
            (200, same.as_slice()),
            (200, same.as_slice()),
            (200, newer.as_slice()),
            (503, b"offline".as_slice()),
            (200, b"<html>oops".as_slice()),
        ];
        #[cfg(windows)]
        replies.push((200, same.as_slice()));
        let server = std::thread::spawn(move || {
            for (i, (code, body)) in replies.into_iter().enumerate() {
                let (mut stream, _) = listener.accept().unwrap();
                let mut request = [0u8; 4096];
                stream.read(&mut request).unwrap();
                write!(stream,"HTTP/1.1 {code} test\r\nContent-Length: {}\r\nETag: changing-{i}\r\nConnection: close\r\n\r\n",body.len()).unwrap();
                stream.write_all(body).unwrap();
            }
        });
        let root =
            super::super::util::scratch_dir(&std::env::temp_dir(), "patch-o-regression").unwrap();
        std::fs::create_dir_all(root.join("Data")).unwrap();
        std::fs::write(root.join("Data/patch-O.mpq"), same).unwrap();
        let state = root.join(".octowow-mods/patch-o");
        std::fs::create_dir_all(&state).unwrap();
        let receipt = Receipt {
            revision: "legacy-etag:9357816".into(),
            enabled: true,
            files: BTreeMap::from([("Data/patch-O.mpq".into(), digest(same))]),
        };
        std::fs::write(
            state.join("receipt.json"),
            serde_json::to_vec(&receipt).unwrap(),
        )
        .unwrap();
        let mut m = find("patch-o").unwrap();
        m.url = url;
        for _ in 0..2 {
            let status = check_one(&root, &m, true).await;
            assert!(!status.update_available, "{}", status.detail);
            assert_eq!(status.detail, "Up to date");
        }
        toggle(&root, m.id, false).unwrap();
        let disabled = check_one(&root, &m, true).await;
        assert!(!disabled.enabled);
        assert!(!disabled.update_available, "{}", disabled.detail);
        let updated = check_one(&root, &m, true).await;
        assert!(updated.update_available);
        for _ in 0..2 {
            let unavailable = check_one(&root, &m, true).await;
            assert!(!unavailable.update_available);
            assert!(unavailable.detail.starts_with("Update check unavailable"));
        }
        assert_eq!(
            std::fs::read(root.join("Data/patch-O.mpq.disabled")).unwrap(),
            same
        );
        #[cfg(windows)]
        {
            use std::os::windows::fs::OpenOptionsExt;
            let locked = std::fs::OpenOptions::new()
                .read(true)
                .share_mode(0)
                .open(root.join("Data/patch-O.mpq.disabled"))
                .unwrap();
            let unavailable = check_one(&root, &m, true).await;
            assert!(!unavailable.update_available);
            assert!(unavailable.detail.starts_with("Update check unavailable"));
            drop(locked);
        }
        server.join().unwrap();
        std::fs::remove_dir_all(root).unwrap();
    }
    #[tokio::test]
    #[ignore]
    async fn live_patch_o_read_only() {
        let root = std::path::PathBuf::from(
            std::env::var("OCTOWOW_TEST_CLIENT").expect("set OCTOWOW_TEST_CLIENT"),
        );
        let result = check_one(&root, &find("patch-o").unwrap(), true).await;
        println!(
            "Patch-O: {} (update available: {})",
            result.detail, result.update_available
        );
        assert_eq!(result.detail, "Up to date");
        assert!(!result.update_available);
    }
    #[test]
    fn audio_toggle_preserves_original_and_rejects_edits() {
        let root = super::super::util::scratch_dir(&std::env::temp_dir(), "mod-test").unwrap();
        let m = find("fish-ping").unwrap();
        let p = "Sound/Spells/Tradeskills/FishBite.wav";
        let state = root.join(".octowow-mods/fish-ping");
        std::fs::create_dir_all(state.join("original/Sound/Spells/Tradeskills")).unwrap();
        std::fs::create_dir_all(root.join("Sound/Spells/Tradeskills")).unwrap();
        std::fs::write(state.join("original").join(p), b"original").unwrap();
        std::fs::write(root.join(p), b"replacement").unwrap();
        let r = Receipt {
            revision: "test".into(),
            enabled: true,
            files: BTreeMap::from([(p.into(), digest(b"replacement"))]),
        };
        std::fs::write(state.join("receipt.json"), serde_json::to_vec(&r).unwrap()).unwrap();
        toggle(&root, m.id, false).unwrap();
        assert_eq!(std::fs::read(root.join(p)).unwrap(), b"original");
        toggle(&root, m.id, true).unwrap();
        assert_eq!(std::fs::read(root.join(p)).unwrap(), b"replacement");
        std::fs::write(root.join(p), b"edited").unwrap();
        assert!(toggle(&root, m.id, false).is_err());
        assert!(!safe(&m, "Sound/../WoW.exe"));
        assert!(!safe(&m, "Data/patch-O.mpq"));
        std::fs::remove_dir_all(root).unwrap();
    }
    #[test]
    fn failed_transaction_rolls_back() {
        let root = super::super::util::scratch_dir(&std::env::temp_dir(), "rollback-test").unwrap();
        std::fs::write(root.join("a"), b"original").unwrap();
        let ops = vec![
            (root.join("a"), root.join("b")),
            (root.join("missing"), root.join("c")),
        ];
        assert!(moves(&root, &ops).is_err());
        assert_eq!(std::fs::read(root.join("a")).unwrap(), b"original");
        assert!(!root.join("b").exists());
        std::fs::remove_dir_all(root).unwrap();
    }
    #[tokio::test]
    #[ignore]
    async fn live_catalog_downloads_to_temp_only() {
        let root = super::super::util::scratch_dir(&std::env::temp_dir(), "live-mods").unwrap();
        std::fs::create_dir_all(root.join("Data")).unwrap();
        for m in catalog() {
            println!("Checking {}", m.title);
            match install(&root, m.id).await {
                Ok(()) => {
                    toggle(&root, m.id, false).unwrap();
                    toggle(&root, m.id, true).unwrap();
                    println!("OK {}", m.title);
                }
                Err(e) => panic!("{}: {} (temp output {})", m.title, e, root.display()),
            }
        }
        std::fs::remove_dir_all(root).unwrap();
    }
}
