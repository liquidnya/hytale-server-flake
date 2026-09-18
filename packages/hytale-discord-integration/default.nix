{
  lib,
  stdenv,
  javaPackages,
  gradle_9,
  fetchFromGitHub,
}: let
  jdk = javaPackages.compiler.temurin-bin.jdk-25;
in
  stdenv.mkDerivation (finalAttrs: {
    pname = "hytale-discord-integration";
    version = "0.3.2+hytale-0.6.7";

    src = fetchFromGitHub {
      owner = "ErdbeerbaerLP";
      repo = "HT-DiscordIntegration";
      rev = "2f600309ee26c49448f3a1d7748703fd53b407a5";
      hash = "sha256-iBSvFg1/7BUZjykJRXX6BUIxJjW9JXmYv9mETJkmwmY=";
    };

    patches = [
      ./0001-Update-hytale-server-to-0.6.7.patch
    ];

    nativeBuildInputs = [gradle_9 jdk];

    mitmCache = gradle_9.fetchDeps {
      inherit (finalAttrs) pname;
      data = ./deps.json;
    };

    __darwinAllowLocalNetworking = true;

    gradleFlags = [
      "-Dfile.encoding=utf-8"
      "-Dorg.gradle.java.home=${jdk}"
    ];

    gradleBuildTask = "shadowJar";

    doCheck = true;

    installPhase = ''
      mkdir -p $out/share/java
      cp -r build/libs/. $out/share/java/
    '';

    meta = {
      license = lib.licenses.mit;
      sourceProvenance = with lib.sourceTypes; [
        fromSource
        # dependencies
        binaryBytecode
      ];
    };
  })
