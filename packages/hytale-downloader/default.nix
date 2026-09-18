{
  lib,
  outputs,
  stdenv,
  fetchzip,
  ...
}: let
  inherit (outputs.lib.getHytaleCDNSystem stdenv.hostPlatform) arch os;
in
  stdenv.mkDerivation {
    pname = "hytale-downloader";
    version = "2026.05.13-99ade04";

    meta = {
      mainProgram = "hytale-downloader";
      # this is unfree and not redistributable
      license = lib.licenses.unfree;
      sourceProvenance = with lib.sourceTypes; [
        binaryNativeCode
      ];
    };

    src = fetchzip {
      url = "https://downloader.hytale.com/hytale-downloader.zip";
      hash = "sha256-g7GIhPhQIQXs/5LdAOuHyVjF28gWZ2kmaCk08IdF7ao=";
      stripRoot = false;
    };

    installPhase = ''
      mkdir -p $out/bin
      install -m755 $src/hytale-downloader-${os}-${arch} $out/bin/hytale-downloader
    '';
  }
