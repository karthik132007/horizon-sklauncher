//! A complete local JSON import and Java launch, with a tiny executable standing in for Java.
//! No network, Microsoft credentials, or real player folders are used.
#![cfg(unix)]
use std::{
    fs,
    os::unix::fs::PermissionsExt,
    path::{Path, PathBuf},
    process::Command,
};

fn command(root: &Path, args: &[&str]) -> Command {
    let mut cmd = Command::new(env!("CARGO_BIN_EXE_horizon-launcher"));
    cmd.args(args)
        .current_dir(root)
        .env("HORIZON_HOME", root.join("game"))
        .env("HORIZON_LAUNCHER_HOME", root.join("launcher"))
        .env("HORIZON_SKLAUNCHER_DIR", root.join("source"))
        .env("XDG_DATA_HOME", root.join("data"))
        .env("XDG_CONFIG_HOME", root.join("config"))
        .env("HORIZON_LAUNCHER_NO_SELF_UPDATE", "1")
        .env("HORIZON_NO_AUDIO", "1")
        .env("HORIZON_NO_KEYCHAIN", "1")
        .env("HORIZON_TELEMETRY_URL", "off");
    cmd
}
fn write(path: PathBuf, text: &str) {
    fs::create_dir_all(path.parent().unwrap()).unwrap();
    fs::write(path, text).unwrap();
}
#[test]
fn import_and_play_preserve_source_files_and_offline_identity() {
    let root = std::env::temp_dir().join(format!("sklauncher-e2e-{}", std::process::id()));
    let _ = fs::remove_dir_all(&root);
    fs::create_dir_all(&root).unwrap();
    let source = root.join("source");
    let game = source.join("instances/fabric");
    let accounts =
        r#"{"accounts":[{"type":"offline","username":"pizza","accessToken":"never-copy"}]}"#;
    write(source.join("accounts.json"), accounts);
    let metadata = serde_json::json!({"instances":[{"name":"Fabric","versionId":"local-fabric","directory":game}]}).to_string();
    write(source.join("instances.json"), &metadata);
    write(game.join("options.txt"), "original options");
    write(game.join("accounts.json"), "must not be copied");
    write(
        source.join("versions/local-fabric/local-fabric.json"),
        r#"{
        "id":"local-fabric","inheritsFrom":"test","mainClass":"example.Main",
        "libraries":[],"arguments":{"game":["--username","${auth_player_name}","--userType","${user_type}","--accessToken","${auth_access_token}","--uuid","${auth_uuid}"]}}
    "#,
    );
    write(
        source.join("versions/test/test.json"),
        r#"{"id":"test","libraries":[],"javaVersion":{"majorVersion":25,"component":"java-runtime-epsilon"}}"#,
    );
    write(source.join("versions/test/test.jar"), "fixture jar");
    let java = source.join("runtime/java-runtime-epsilon/linux/java-runtime-epsilon");
    write(java.join("release"), "JAVA_VERSION=\"25.0.1\"\n");
    write(
        java.join("bin/java"),
        "#!/bin/sh\nprintf '%s\\n' \"$@\" > launched-args.txt\n",
    );
    fs::set_permissions(java.join("bin/java"), fs::Permissions::from_mode(0o755)).unwrap();
    let out = command(&root, &["account", "import-sklauncher", "--json"])
        .output()
        .unwrap();
    assert!(
        out.status.success(),
        "{}",
        String::from_utf8_lossy(&out.stderr)
    );
    let imported = fs::read_to_string(root.join("launcher/accounts.json")).unwrap();
    assert!(imported.contains("pizza") && !imported.contains("never-copy"));
    let out = command(&root, &["play"]).output().unwrap();
    assert!(
        out.status.success(),
        "{}",
        String::from_utf8_lossy(&out.stderr)
    );
    let instance = fs::read_dir(root.join("game/instances"))
        .unwrap()
        .next()
        .unwrap()
        .unwrap()
        .path();
    let args = fs::read_to_string(instance.join("launched-args.txt")).unwrap();
    assert!(args.contains("--username\npizza\n"), "{args}");
    assert!(args.contains("--userType\nlegacy\n"), "{args}");
    assert!(args.contains("--accessToken\n\n"), "{args}");
    assert!(args.contains("dd725bd187ee336ca55315d76155f1b0"));
    assert!(!instance.join("accounts.json").exists());
    assert_eq!(
        fs::read_to_string(source.join("accounts.json")).unwrap(),
        accounts
    );
    assert_eq!(
        fs::read_to_string(source.join("instances.json")).unwrap(),
        metadata
    );
    assert_eq!(
        fs::read_to_string(game.join("options.txt")).unwrap(),
        "original options"
    );
    assert!(!game.join("launched-args.txt").exists());
    assert!(!source.join("natives").exists());
    let second = command(&root, &["account", "import-sklauncher", "--json"])
        .output()
        .unwrap();
    assert!(second.status.success());
    assert_eq!(
        serde_json::from_slice::<serde_json::Value>(&second.stdout).unwrap()["imported"],
        0
    );
    let _ = fs::remove_dir_all(root);
}
