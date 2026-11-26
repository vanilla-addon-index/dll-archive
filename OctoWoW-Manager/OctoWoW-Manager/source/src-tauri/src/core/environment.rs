//! Optional Config.wtf and WDB cache management.
use crate::config::Tweaks;
use std::path::Path;

pub fn configure(root: &Path, tweaks: &Tweaks) -> Result<(), String> {
    if tweaks.unlimited_script_memory {
        let dir = root.join("WTF");
        std::fs::create_dir_all(&dir).map_err(|e| e.to_string())?;
        let path = dir.join("Config.wtf");
        let existing = match std::fs::read_to_string(&path) {
            Ok(s) => s,
            Err(e) if e.kind() == std::io::ErrorKind::NotFound => String::new(),
            Err(e) => return Err(format!("Couldn't read Config.wtf: {e}")),
        };
        let mut updated = String::new();
        for line in existing.lines() {
            let words: Vec<_> = line.split_whitespace().collect();
            if words.len() >= 2
                && words[0].eq_ignore_ascii_case("SET")
                && words[1].eq_ignore_ascii_case("scriptMemory")
            {
                continue;
            }
            updated.push_str(line);
            updated.push('\n');
        }
        updated.push_str("SET scriptMemory \"0\"\n");
        let tmp = dir.join("Config.wtf.octowow-tmp");
        std::fs::write(&tmp, updated).map_err(|e| e.to_string())?;
        std::fs::rename(tmp, path).map_err(|e| format!("Couldn't replace Config.wtf: {e}"))?;
    }
    let wdb = root.join("WDB");
    let marker = root.join(".octowow-wdb-blocker");
    if !tweaks.clear_wdb && !marker.is_file() {
        return Ok(());
    }
    let meta = std::fs::symlink_metadata(&wdb).ok();
    if let Some(m) = &meta {
        if m.file_type().is_symlink() || is_reparse(m) {
            return Err("WDB is a link; manage it manually before changing the WDB option.".into());
        }
    }
    if tweaks.clear_wdb {
        if let Some(m) = meta {
            if m.is_dir() {
                // Preserve the former cache for recovery; WoW no longer reads it.
                let backup = super::util::scratch_dir(root, "wdb-backup")?;
                std::fs::rename(&wdb, backup.join("WDB")).map_err(|e| e.to_string())?;
            } else if !m.is_file() || m.len() != 0 {
                return Err(
                    "A non-empty or special WDB file exists; it was left unchanged.".into(),
                );
            }
        }
        if !wdb.exists() {
            std::fs::write(&wdb, []).map_err(|e| e.to_string())?;
        }
        std::fs::write(marker, b"empty WDB blocker").map_err(|e| e.to_string())?;
    } else if marker.is_file() {
        if meta.is_some_and(|m| m.is_file() && m.len() == 0) {
            std::fs::remove_file(wdb).map_err(|e| e.to_string())?;
        }
        std::fs::remove_file(marker).map_err(|e| e.to_string())?;
    }
    Ok(())
}
#[cfg(windows)]
fn is_reparse(meta: &std::fs::Metadata) -> bool {
    use std::os::windows::fs::MetadataExt;
    meta.file_attributes() & 0x400 != 0
}
#[cfg(not(windows))]
fn is_reparse(_: &std::fs::Metadata) -> bool {
    false
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn config_and_wdb_ownership() {
        let root =
            super::super::util::scratch_dir(&std::env::temp_dir(), "environment-test").unwrap();
        std::fs::create_dir_all(root.join("WTF")).unwrap();
        std::fs::write(
            root.join("WTF/Config.wtf"),
            "SET gxResolution \"1920x1080\"\nSET scriptMemory \"48000\"\n",
        )
        .unwrap();
        std::fs::create_dir(root.join("WDB")).unwrap();
        std::fs::write(root.join("WDB/cache.wdb"), b"cache").unwrap();
        let mut t = Tweaks::default();
        t.clear_wdb = true;
        t.unlimited_script_memory = true;
        configure(&root, &t).unwrap();
        assert!(root.join("WDB").is_file());
        let config = std::fs::read_to_string(root.join("WTF/Config.wtf")).unwrap();
        assert!(config.contains("SET gxResolution \"1920x1080\""));
        assert!(config.contains("SET scriptMemory \"0\""));
        t.clear_wdb = false;
        t.unlimited_script_memory = false;
        configure(&root, &t).unwrap();
        assert!(!root.join("WDB").exists());
        std::fs::write(root.join("WDB"), b"foreign").unwrap();
        configure(&root, &t).unwrap();
        assert_eq!(std::fs::read(root.join("WDB")).unwrap(), b"foreign");
        t.clear_wdb = true;
        assert!(configure(&root, &t).is_err());
        std::fs::remove_dir_all(root).unwrap();
    }
}
