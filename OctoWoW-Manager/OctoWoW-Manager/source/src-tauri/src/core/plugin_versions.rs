use crate::config::Settings;
use serde::{Deserialize, Serialize};
use sha1::{Digest, Sha1};
use std::{collections::BTreeMap, path::Path};

#[derive(Default, Serialize)]
pub struct Inventory {
    pub bundled: BTreeMap<String, Option<String>>,
    pub installed: BTreeMap<String, Option<String>>,
}

#[derive(Default, Serialize)]
pub struct UpstreamCheck {
    pub installed: BTreeMap<String, String>,
    pub updates: BTreeMap<String, String>,
}

#[derive(Serialize, Deserialize)]
struct Receipt {
    hash: String,
    version: String,
}

fn hash(bytes: &[u8]) -> String {
    super::torrent::hex(&Sha1::digest(bytes))
}

fn receipt_path(root: &Path, file: &str) -> std::path::PathBuf {
    root.join(".octowow-mods")
        .join("dll-versions")
        .join(format!("{file}.json"))
}

pub fn record(root: &Path, file: &str, bytes: &[u8], version: &str) -> std::io::Result<()> {
    let path = receipt_path(root, file);
    std::fs::create_dir_all(path.parent().unwrap())?;
    let tmp = path.with_extension("tmp");
    std::fs::write(
        &tmp,
        serde_json::to_vec(&Receipt {
            hash: hash(bytes),
            version: version.into(),
        })?,
    )?;
    std::fs::rename(tmp, path)
}

// Read the fixed version resource used by Windows DLLs on any Manager platform.
fn file_version(bytes: &[u8]) -> Option<String> {
    const KEY: &[u8] = b"V\0S\0_\0V\0E\0R\0S\0I\0O\0N\0_\0I\0N\0F\0O\0\0\0";
    fn word(bytes: &[u8], offset: usize) -> Option<u32> {
        Some(u32::from_le_bytes(
            bytes.get(offset..offset + 4)?.try_into().ok()?,
        ))
    }
    for (offset, key) in bytes.windows(KEY.len()).enumerate() {
        if key != KEY || offset < 6 || bytes[offset - 4..offset] != [52, 0, 0, 0] {
            continue;
        }
        let fixed = (offset + KEY.len() + 3) & !3;
        if word(bytes, fixed) != Some(0xfeef04bd) {
            continue;
        }
        let major_minor = word(bytes, fixed + 8)?;
        let patch_build = word(bytes, fixed + 12)?;
        if major_minor == 0 && patch_build == 0 {
            continue;
        }
        let mut version = format!(
            "{}.{}.{}",
            major_minor >> 16,
            major_minor & 0xffff,
            patch_build >> 16
        );
        if patch_build & 0xffff != 0 {
            version.push_str(&format!(".{}", patch_build & 0xffff));
        }
        return Some(version);
    }
    None
}

pub fn inspect(settings: &Settings) -> Inventory {
    let provenance: BTreeMap<String, String> =
        serde_json::from_str(include_str!("../../bundled-plugin-versions.json"))
            .expect("bundled plugin version manifest");
    let mut result = Inventory::default();
    let root = Path::new(&settings.wow_dir);
    let catalog = super::plugins::catalog();
    for name in catalog
        .iter()
        .map(|p| p.file)
        .chain(settings.custom_plugins.keys().map(String::as_str))
    {
        if name.contains(['/', '\\', ':']) || !name.to_ascii_lowercase().ends_with(".dll") {
            continue;
        }
        let bundle = super::payload::bundled_dll(name);
        let bundled_version = bundle.and_then(|bytes| {
            provenance
                .get(name)
                .cloned()
                .or_else(|| file_version(bytes))
        });
        if bundle.is_some() {
            result.bundled.insert(name.into(), bundled_version.clone());
        }
        if settings.wow_dir.is_empty() {
            continue;
        }
        let Ok(bytes) = std::fs::read(root.join(name)) else {
            continue;
        };
        let version = if bundle == Some(bytes.as_slice()) {
            bundled_version
        } else {
            let receipt = std::fs::read(receipt_path(root, name))
                .ok()
                .and_then(|data| serde_json::from_slice::<Receipt>(&data).ok());
            receipt
                .filter(|receipt| receipt.hash == hash(&bytes))
                .map(|receipt| receipt.version)
                .or_else(|| file_version(&bytes))
        };
        result.installed.insert(name.into(), version);
    }
    result
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn bundled_and_installed_versions_follow_the_bytes() {
        let root =
            crate::core::util::scratch_dir(&std::env::temp_dir(), "dll-version-test").unwrap();
        let settings = Settings {
            wow_dir: root.to_string_lossy().into_owned(),
            ..Settings::default()
        };
        let file = "nampower.dll";
        let bundled = crate::core::payload::bundled_dll(file).unwrap();
        assert_eq!(inspect(&settings).bundled[file].as_deref(), Some("4.6.1 99d8d36 brues-code fix"));
        assert!(!inspect(&settings).installed.contains_key(file));
        std::fs::write(root.join(file), bundled).unwrap();
        assert_eq!(inspect(&settings).installed[file].as_deref(), Some("4.6.1 99d8d36 brues-code fix"));

        let other = b"upstream build without version info";
        std::fs::write(root.join(file), other).unwrap();
        record(&root, file, other, "2.3").unwrap();
        assert_eq!(inspect(&settings).installed[file].as_deref(), Some("2.3"));

        std::fs::write(root.join(file), b"manual replacement").unwrap();
        assert_eq!(inspect(&settings).installed[file], None);
        std::fs::remove_dir_all(root).unwrap();
    }
}
