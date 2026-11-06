//! Read-only import of SKlauncher 4's local JSON metadata. Unknown fields (including secrets)
//! are discarded by typed deserialization. Legacy binary accounts are deliberately unsupported.
//! Shared versions/libraries/assets are read in place; writable game data is copied into Horizon.
use crate::{account, backend, instances, other_launchers};
use serde::{Deserialize, Serialize};
use std::{
    fs,
    path::{Path, PathBuf},
};

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct Installation {
    pub minecraft_dir: PathBuf,
    pub version_id: String,
    pub source_game_dir: PathBuf,
}

#[derive(Debug, Deserialize)]
struct Account {
    #[serde(rename = "type")]
    kind: String,
    username: String,
}
#[derive(Default, Deserialize)]
struct Accounts {
    accounts: Vec<Account>,
}
#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Profile {
    pub name: String,
    pub version_id: String,
    pub directory: PathBuf,
}
#[derive(Deserialize)]
struct Profiles {
    instances: Vec<Profile>,
}

/// Java's name-based, version-3 UUID. Never use an authenticated UUID for an offline identity.
pub fn offline_uuid(name: &str) -> String {
    format!("{:032x}", horizon_protocol::crypto::offline_uuid(name))
}

/// Deserialize only non-secret fields. Do not include the input or parser diagnostics in errors.
pub fn offline_names(text: &str) -> Result<Vec<String>, String> {
    let data: Accounts = serde_json::from_str(text).map_err(|_| {
        "Unsupported SKlauncher accounts format. Create a local profile manually.".to_string()
    })?;
    let mut names: Vec<String> = Vec::new();
    for a in data.accounts {
        if a.kind == "offline"
            && account::valid_offline_name(&a.username)
            && !names.iter().any(|n| n.eq_ignore_ascii_case(&a.username))
        {
            names.push(a.username);
        }
    }
    Ok(names)
}

pub fn profiles(text: &str) -> Result<Vec<Profile>, String> {
    let data: Profiles = serde_json::from_str(text).map_err(|_| {
        "Unsupported SKlauncher instances format. Create an instance manually.".to_string()
    })?;
    Ok(data
        .instances
        .into_iter()
        .filter(|p| {
            !p.name.trim().is_empty()
                && p.directory.is_absolute()
                && crate::mojang::relative(&p.version_id).is_ok()
        })
        .collect())
}

/// Current Linux JSON layout, with an explicit override for relocated installations.
pub fn roots() -> Vec<PathBuf> {
    if let Some(root) = std::env::var_os("HORIZON_SKLAUNCHER_DIR") {
        return vec![root.into()];
    }
    let Some(home) = dirs::home_dir() else {
        return Vec::new();
    };
    vec![home.join(".sklauncher"), home.join(".minecraft")]
}

fn names_at(root: &Path) -> Result<Vec<String>, String> {
    let path = root.join("accounts.json");
    if !path.is_file() {
        return Ok(Vec::new());
    }
    let text = fs::read_to_string(&path)
        .map_err(|_| "Could not read SKlauncher account metadata.".to_string())?;
    offline_names(&text)
}

fn keep_names(accounts: &mut account::Accounts, names: &[String]) {
    for name in names {
        if !accounts
            .offline
            .iter()
            .any(|n| n.eq_ignore_ascii_case(name))
        {
            accounts.offline.push(name.clone());
        }
    }
    // Default only once. Explicit subsequent profile switches are preserved.
    if accounts.selected().is_none() && accounts.offline_selected.is_none() {
        accounts.offline_selected = names.first().cloned();
    }
}

/// First GUI startup discovers local names, without touching SKlauncher or choosing over an
/// existing account. A marker prevents resurrecting a profile the player explicitly forgot.
pub fn auto_import_accounts() -> Result<(), String> {
    let marker = backend::data_dir().join("sklauncher-discovered");
    if marker.is_file() {
        return Ok(());
    }
    let mut accounts = account::Accounts::load();
    for root in roots() {
        keep_names(&mut accounts, &names_at(&root)?);
    }
    accounts.save()?;
    fs::write(marker, "1\n").map_err(|e| format!("Could not save profile discovery: {e}"))
}

fn version_file(root: &Path, id: &str) -> Result<PathBuf, String> {
    crate::mojang::relative(id)?;
    Ok(root.join("versions").join(id).join(format!("{id}.json")))
}

fn installed_id(root: &Path, id: &str) -> Option<String> {
    if version_file(root, id).ok()?.is_file() {
        return Some(id.into());
    }
    // Dynamic built-in profiles are resolved only from the launcher's cached manifest.
    let manifest: serde_json::Value =
        serde_json::from_str(&fs::read_to_string(root.join("version_manifest_v2.json")).ok()?)
            .ok()?;
    let key = match id {
        "latest-release" => "release",
        "latest-snapshot" => "snapshot",
        _ => return None,
    };
    let id = manifest["latest"][key].as_str()?;
    version_file(root, id).ok()?.is_file().then(|| id.into())
}

/// Import every locally installed instance. Libraries, assets and version jars stay in place.
/// Copies only allowlisted game content, never account files or launcher/browser state.
pub fn import_all() -> Result<usize, String> {
    let mut imported_names = Vec::new();
    let mut count = 0;
    let mut first = None;
    let mut found_names = false;
    for root in roots() {
        let names = names_at(&root)?;
        found_names |= !names.is_empty();
        imported_names.extend(names);
        let path = root.join("instances.json");
        if !path.is_file() {
            continue;
        }
        let text = fs::read_to_string(&path)
            .map_err(|_| "Could not read SKlauncher instance metadata.".to_string())?;
        for p in profiles(&text)? {
            let Some(id) = installed_id(&root, &p.version_id) else {
                continue;
            };
            if !p.directory.is_dir() {
                continue;
            }
            let installation = Installation {
                minecraft_dir: root.clone(),
                version_id: id.clone(),
                source_game_dir: p.directory.clone(),
            };
            if let Some(existing) = instances::list().into_iter().find(|i| {
                i.java.as_ref().and_then(|j| j.local_install.as_ref()) == Some(&installation)
            }) {
                first.get_or_insert(existing.id);
                continue;
            }
            let version = crate::java_launch::read(&version_file(&root, &id)?)?;
            let base = version["inheritsFrom"].as_str().unwrap_or(&id);
            let loader = version["libraries"]
                .as_array()
                .into_iter()
                .flatten()
                .find_map(|lib| {
                    let name = lib["name"].as_str()?;
                    for (prefix, kind) in [
                        ("net.fabricmc:fabric-loader:", crate::loaders::Kind::Fabric),
                        ("org.quiltmc:quilt-loader:", crate::loaders::Kind::Quilt),
                        ("net.minecraftforge:forge:", crate::loaders::Kind::Forge),
                        ("net.neoforged:neoforge:", crate::loaders::Kind::NeoForge),
                    ] {
                        if let Some(version) = name.strip_prefix(prefix) {
                            return Some(crate::loaders::Loader {
                                kind,
                                version: version.into(),
                            });
                        }
                    }
                    None
                });
            // Resolve before creating an instance, so unsupported/broken profiles leave no stub.
            let resolved = crate::java_launch::resolve(version.clone(), &root)?;
            let need = crate::java::Need::of(&resolved);
            let runtime = crate::java::mojang_runtimes(&root.join("runtime"))
                .into_iter()
                .find(|r| r.major == need.major);
            let instance = instances::create_java(&format!("SKlauncher · {}", p.name), base)?;
            let found = other_launchers::Found {
                launcher: "SKlauncher",
                name: p.name,
                minecraft: Some(base.into()),
                loader: None,
                game: p.directory,
                shared: true,
            };
            if let Err(e) = other_launchers::copy_game(&found, &instance.home) {
                let _ = instances::delete(&instance.id);
                return Err(format!("Could not copy SKlauncher game content: {e}"));
            }
            instances::edit(&instance.id, |meta| {
                let game = meta.java.as_mut().expect("new Java instance");
                game.local_install = Some(installation);
                game.loader = loader;
                game.home = runtime.map(|r| r.home);
            })?;
            first.get_or_insert(instance.id);
            count += 1;
        }
    }
    if !found_names && count == 0 {
        return Err("No supported SKlauncher local profiles found. Add a local offline name manually, or set HORIZON_SKLAUNCHER_DIR to the folder holding accounts.json and instances.json.".into());
    }
    let mut accounts = account::Accounts::load();
    keep_names(&mut accounts, &imported_names);
    accounts.save()?;
    if instances::selected().id == instances::DEFAULT {
        if let Some(first) = first {
            instances::select(&first)?;
        }
    }
    Ok(count)
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn imports_only_valid_offline_metadata() {
        let input = r#"{"accounts":[{"type":"offline","username":"pizza","uuid":"dd725bd1-87ee-336c-a553-15d76155f1b0","accessToken":"ignored"},{"type":"microsoft","username":"Online","refreshToken":"ignored"},{"type":"offline","username":"PIZZA"},{"type":"offline","username":"bad name"}]}"#;
        assert_eq!(offline_names(input).unwrap(), ["pizza"]);
        assert!(!offline_names("{malformed secret")
            .unwrap_err()
            .contains("secret"));
        assert!(offline_names(r#"{"users":[]}"#).is_err());
    }
    #[test]
    fn uuids_match_java_and_keep_name_case() {
        assert_eq!(offline_uuid("pizza"), "dd725bd187ee336ca55315d76155f1b0");
        assert_eq!(offline_uuid("Notch"), "b50ad385829d3141a2167e7d7539ba7f");
        assert_ne!(offline_uuid("pizza"), offline_uuid("Pizza"));
    }
    #[test]
    fn profiles_reject_relative_directories_and_traversal() {
        let data = r#"{"instances":[{"name":"Fabric","versionId":"fabric-loader-0.19.5-26.3","directory":"/tmp/game"},{"name":"unsafe","versionId":"../../escape","directory":"/tmp/game"},{"name":"relative","versionId":"26.3","directory":"game"}]}"#;
        let found = profiles(data).unwrap();
        assert_eq!(found.len(), 1);
        assert_eq!(found[0].version_id, "fabric-loader-0.19.5-26.3");
        assert!(profiles(r#"{"profiles":{}}"#).is_err());
    }
    #[test]
    fn discovery_preserves_explicit_profile_selection() {
        let mut accounts = account::Accounts::default();
        keep_names(&mut accounts, &["pizza".into()]);
        assert_eq!(accounts.player(), account::Player::Offline("pizza".into()));
        accounts.offline_selected = Some("Other".into());
        keep_names(&mut accounts, &["pizza".into()]);
        assert_eq!(accounts.player(), account::Player::Offline("Other".into()));
        assert_eq!(accounts.offline, ["pizza"]);
    }
}
