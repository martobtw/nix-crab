{
  pkgs,
  lib,
  config,
  ...
}: let
  # ASSella (niwia/ASSella) — fork of Enter The Wired's ACCELA with QoL fixes.
  # Releases are clean version tags (no floating "latest"), the binary is a
  # single self-contained AppImage that lives in the release assets; the logo
  # lives only on the beta branch, so the raw fetch is pinned to the branch
  # commit it matches (v2.7.0beta-era tree: beta@1b63ebec, 2026-10-15).
  # ASSella runs the same ACCELA UI, so the seed conf + accelab plumbing keep
  # the earlier names; only the binaries behind this derivation changed.
  version = "2.7.0beta";
  betaCommit = "1b63ebec7790d3681d7e4bfa94a13e268a87f320";

  appimage = pkgs.fetchurl {
    url = "https://github.com/niwia/ASSella/releases/download/v${version}/ASSella.AppImage";
    hash = "sha256-TQ6Pcf+nxQZpyBNdftOy0FRqDyWX+6L07bomC1eART8=";
  };
  logo = pkgs.fetchurl {
    url = "https://raw.githubusercontent.com/niwia/ASSella/${betaCommit}/assela_logo.png";
    hash = "sha256-AZzoYhP5Q49FG8hfSvPvHEFBs+8QDWzXIMXKmMbijbs=";
  };

  # appimage-run also supplies the FHS loader the bundled PyQt6 needs. zstd
  # is not in that rootfs and the bundled PyQt6 links it, so without the
  # override it dies on `import PyQt6.QtGui` -- eval and build pass either
  # way, only launching catches it (same ponytail as the ACCELA bundle).
  appimageRun = pkgs.appimage-run.override {
    extraPkgs = p: [p.zstd];
  };

  launcher = pkgs.writeShellScriptBin "accela" ''
    exec ${appimageRun}/bin/appimage-run ${appimage} "$@"
  '';

  desktopItem = pkgs.makeDesktopItem {
    name = "assella";
    desktopName = "ASSella";
    comment = "ＧｏＤ_Ｉｓ_ｉＮ_ｔＨｅ_ＷｉＲｅＤ (ACCELA fork)";
    exec = "${launcher}/bin/accela %u";
    icon = "assella";
    categories = ["Utility"];
    # Declared, not registered as default: that would mean owning
    # ~/.config/mimeapps.list via xdg.mimeApps and every other default with it.
    mimeTypes = ["x-scheme-handler/accela"];
    startupNotify = false;
  };

  # The [General] keys enter-the-wired's own `accela` script forces -- what makes
  # ACCELA defer to SLSsteam instead of managing games itself.
  seedConf = pkgs.writeText "ACCELA.conf" ''
    [General]
    auto_skip_single_choice=true
    library_mode=true
    max_downloads=16
    sls_config_management=true
    slssteam_mode=true
    use_steamless=true
  '';
in {
  options.programs.nix-crab.accela.enable =
    lib.mkEnableOption "ASSella (Steam depot downloader, ACCELA fork)";

  config = lib.mkIf config.programs.nix-crab.accela.enable {
    home.packages = [launcher];

    home.file.".local/share/icons/hicolor/256x256/apps/assella.png".source = logo;

    # Not xdg.desktopEntries: XDG_DATA_HOME is searched before the profile, so
    # the entry ACCELA/ASSella installers write would shadow ours. Same as
    # steamidra.
    home.file.".local/share/applications/assella.desktop" = {
      source = "${desktopItem}/share/applications/assella.desktop";
      force = true;
    };

    # Seeds only when absent; upstream's awk-merges into existing sections, so
    # keeping QSettings in one piece beats owning the file. Same trick as the
    # earlier ACCELA module.
    home.activation.accelaSeedConfig = lib.hm.dag.entryAfter ["writeBoundary"] ''
      accelaConf="${config.xdg.configHome}/Tachibana Labs/ACCELA.conf"
      if [ ! -e "$accelaConf" ]; then
        run mkdir -p "$(dirname "$accelaConf")"
        run install -m644 "${seedConf}" "$accelaConf"
      fi
    '';
  };
}
