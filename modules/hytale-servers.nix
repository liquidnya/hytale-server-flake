self: {
  config,
  pkgs,
  lib,
  modulesPath,
  ...
}: let
  inherit
    (lib)
    attrsets
    lists
    strings
    types
    getExe
    mkOption
    mkEnableOption
    mkIf
    ;
  inherit (attrsets) mapAttrs mapAttrs' mapAttrsToList nameValuePair;
  inherit (strings) concatStrings;

  flakePkgs = self.packages."${pkgs.stdenv.hostPlatform.system}";

  cfg = config.services.hytale-servers;
in {
  options = let
    file = types.submodule (
      {
        name,
        config,
        ...
      }: {
        options = {
          name = mkOption {
            type = types.str;
            default = name;
            description = ''
              The name of the file.
            '';
            internal = true;
            readOnly = true;
            visible = false;
          };

          method = mkOption {
            type = types.enum [
              "copy"
              "symlink"
            ];
            default = "symlink";
            description = ''
              How to manage the target file.
              - "symlink": The target will be a symlink to the source in the store.
              - "copy": The source will be copied to the target.
              "symlink" may cause issues when read-write access is expected and does not support custom permissions,
              whereas "copy" imposes a disk space penalty.
            '';
            example = "copy";
          };

          source = mkOption {
            type = types.path;
            default = pkgs.writeText (baseNameOf name) config.text;
            description = ''
              Path of the source file or directory.
            '';
          };

          text = mkOption {
            type = types.nullOr types.lines;
            default = null;
            description = ''
              Text content of the file.
            '';
          };
        };
      }
    );

    hytaleServer = types.submodule (
      {
        name,
        config,
        ...
      }: {
        imports = [
          (modulesPath + "/misc/assertions.nix")
          (lib.mkRemovedOptionModule ["version"] "Pinning the Hytale server version is no longer supported.")
          (lib.mkRemovedOptionModule ["acknowledgeVersionWarning"] "Pinning the Hytale server version is no longer supported.")
          (lib.mkRemovedOptionModule ["autoUpdate"] "Updates are now handled by the server itself. Run `/help update` in your server for details.")
        ];

        options = {
          enable = mkEnableOption "this Hytale server";

          name = mkOption {
            type = types.str;
            default = name;
            description = ''
              The name of the Hytale server.
            '';
            internal = true;
            readOnly = true;
            visible = false;
          };

          autoStart = mkOption {
            type = types.bool;
            default = false;
            description = ''
              Whether to start the server on boot.
              It is currently not recommended to set this option, as the service hangs when credentials are not present or expired.
            '';
            example = true;
          };

          assetsDir = mkOption {
            type = types.str;
            default = "${cfg.assetsDir}/${config.patchline}";
            description = ''
              The path to the server binary and assets.
            '';
            internal = true;
            readOnly = true;
            visible = false;
          };

          dataDir = mkOption {
            type = types.str;
            default = "${cfg.dataDir}/${name}";
            description = ''
              The path to the server data directory.
            '';
            internal = true;
            readOnly = true;
            visible = false;
          };

          listenAddress = mkOption {
            type = types.str;
            default = "0.0.0.0";
            description = ''
              The IP address to bind the server to.
            '';
            example = "127.0.0.1";
          };

          port = mkOption {
            type = types.int;
            default = 5520;
            description = ''
              The port which the server will listen to.
            '';
            example = 65535;
          };

          openFirewall = mkOption {
            type = types.bool;
            default = false;
            description = ''
              Whether to open the server port in the firewall.
            '';
            example = true;
          };

          restart = mkOption {
            type = types.enum [
              "no"
              "always"
              "on-success"
              "on-failure"
              "on-abnormal"
              "on-abort"
              "on-warning"
            ];
            default = "on-success";
            description = ''
              The condition under which to restart the server if it stops.
              This is the service's `Restart=` parameter.
              Note that this will cause the server to restart instead of stopping
              if the `/stop` command is issued on the server.
            '';
            internal = true;
            visible = false;
          };

          tmux.enable = mkOption {
            type = types.bool;
            default = false;
            description = ''
              Whether to run the server process in a tmux session.
            '';
            example = true;
          };

          patchline = mkOption {
            type = types.enum [
              "release"
              "pre-release"
            ];
            default = "release";
            description = ''
              The Hytale version patchline to follow.
            '';
            example = "pre-release";
          };

          java = let
            javaWarning = ''
              Configuring the Hytale server Java currently has no effect, due to the hardcoded behaviour
              of the server start script. This may be fixed or removed in the future.
            '';
          in {
            package = mkOption {
              type = types.package;
              default = pkgs.javaPackages.compiler.temurin-bin.jre-25;
              description = ''
                The package to provide the JVM used by the server.
              '';
            };

            jvmOpts = mkOption {
              type = types.str;
              default = "";
              description = ''
                Additional flags to pass to the JVM.
              '';
              example = "-Xms4G -Xmx8G";
              apply = x:
                if (x != "")
                then builtins.warn javaWarning x
                else x;
            };
          };

          files = mkOption {
            type = types.attrsOf file;
            default = {};
            description = ''
              Files to link from the Nix store into the server data directory upon server start.
              This can be used for declarative server configuration and plugin management.
            '';
          };
        };
      }
    );
  in {
    services.hytale-servers = {
      enable = mkEnableOption "Hytale server management";

      user = mkOption {
        type = types.str;
        default = "hytale";
        description = ''
          The name of the user account to own the Hytale servers.
          It's recommended to leave this as the default.
        '';
        internal = true;
        visible = false;
      };

      group = mkOption {
        type = types.str;
        default = "hytale";
        description = ''
          The name of the user group to own the Hytale servers.
          It's recommended to leave this as the default.
        '';
        internal = true;
        visible = false;
      };

      credentialsPath = mkOption {
        type = types.str;
        default = "/var/cache/hytale/credentials.json";
        description = ''
          The location to store the Hytale downloader credentials.
        '';
      };

      assetsDir = mkOption {
        type = types.str;
        default = "/var/lib/hytale/assets";
        description = ''
          The directory to store Hytale assets in.
          The newest available archive will be automatically downloaded upon server startup.
        '';
      };

      dataDir = mkOption {
        type = types.str;
        default = "/srv/hytale";
        description = ''
          The directory to store Hytale server data in.
          Server settings, mods, and universes will be stored in subfolders within this directory.
        '';
      };

      runtimeDir = mkOption {
        type = types.str;
        default = "/run/hytale";
        description = ''
          The directory to store Hytale server runtime data in.
        '';
        internal = true;
        readOnly = true;
        visible = false;
      };

      servers = mkOption {
        type = types.attrsOf hytaleServer;
        default = {};
        description = ''
          The Hytale server definitions.
        '';
      };
    };
  };

  config = mkIf cfg.enable (
    let
      enabledServers = attrsets.filterAttrs (_: server: server.enable) cfg.servers;
    in {
      users = {
        users.hytale = mkIf (cfg.user == "hytale") {
          description = "Hytale server service user";
          home = cfg.dataDir;
          homeMode = "770";
          createHome = true;
          isSystemUser = true;
          group = "hytale";
          # apparently needed since tmux parses commands via the login shell
          shell = pkgs.bash;
        };
        groups.hytale = mkIf (cfg.group == "hytale") {};
      };

      networking.firewall = let
        openedServers = attrsets.filterAttrs (_: c: c.openFirewall) enabledServers;
      in {
        allowedUDPPorts = lists.flatten (mapAttrsToList (_: c: c.port) openedServers);
      };

      environment.systemPackages = let
        hytaleServerDownloadScript = pkgs.writeShellApplication {
          name = "hytale-server-download";
          runtimeInputs = with pkgs; [
            flakePkgs.hytale-downloader
            jq
            unzip
          ];
          text = ''
            ASSETS_DIR="${cfg.assetsDir}"
            CREDENTIALS_PATH="${cfg.credentialsPath}"

            hytale_downloader() {
              hytale-downloader \
                -skip-update-check \
                -patchline "$patchline" \
                -credentials-path "$CREDENTIALS_PATH" \
                "$@"
            }

            request_auth() {
              # cause the downloader to request authentication
              hytale_downloader -print-version
            }

            try_hytale_downloader() {
              if output="$(hytale_downloader "$@")"; then
                echo "$output"
              else
                rm "$CREDENTIALS_PATH"; request_auth

                hytale_downloader "$@"
              fi
            }

            # defaults
            patchline="release"

            while getopts "p:f" arg; do
              case "$arg" in
                p)
                  patchline="$OPTARG" ;;
                f)
                  force="about 500 newtons" ;;
                *)
                  echo "usage: $0 [-p patchline] [-f]" >&2
                  exit 1 ;;
              esac
            done

            if [ "$USER" != "${cfg.user}" ]; then
              echo "Script must be run as the \`${cfg.user}\` user." >&2
              exit 1
            fi

            # check if the token has expired, and refresh it if so
            if [ -e "$CREDENTIALS_PATH" ]; then
              auth_expires_at="$(jq .expires_at "$CREDENTIALS_PATH")"
              current_time="$(date +%s)"
              if [ "$current_time" -ge "$auth_expires_at" ]; then
                rm "$CREDENTIALS_PATH"; request_auth
              fi
            else
              request_auth
            fi

            game_dir="$ASSETS_DIR/$patchline"

            if [ -d "$game_dir" ] && ! "$force"; then
              echo "Server data directory already exists" >&2
              exit 1
            fi

            download_dir="$(mktemp -d)"
            hytale_downloader -download-path "$download_dir/assets.zip"

            rm -rf "$game_dir"; mkdir -p "$game_dir"
            unzip "$download_dir/assets.zip" -d "$game_dir"
            rm -r "$download_dir"
          '';
        };
      in [
        hytaleServerDownloadScript
      ];

      systemd.tmpfiles.rules =
        [
          "d '${dirOf cfg.credentialsPath}' 0700 ${cfg.user} ${cfg.group}"
          "d '${cfg.assetsDir}' 0700 ${cfg.user} ${cfg.group}"
        ]
        ++ mapAttrsToList (
          _: server: "d '${server.dataDir}' 0770 ${cfg.user} ${cfg.group} - -"
        )
        enabledServers;

      systemd.sockets = let
        targetServers = attrsets.filterAttrs (_: server: !server.tmux.enable) cfg.servers;

        mkHytaleServerSocket = server: {
          inherit (server) enable;

          requires = ["hytale-server-${server.name}.service"];
          partOf = ["hytale-server-${server.name}.service"];

          socketConfig = {
            ListenFIFO = "${cfg.runtimeDir}/${server.name}.stdin";
            SocketMode = "0660";
            SocketUser = cfg.user;
            SocketGroup = cfg.group;
            RemoveOnStop = true;
            FlushPending = true;
          };
        };
      in
        mapAttrs' (
          _: server: nameValuePair "hytale-server-${server.name}" (mkHytaleServerSocket server)
        )
        targetServers;

      systemd.services = let
        mkServerSessionScripts = server: let
          socketPath = "${cfg.runtimeDir}/${server.name}.sock";
          fifoPath = "${cfg.runtimeDir}/${server.name}.stdin";
          tmux = "${getExe pkgs.tmux} -S ${socketPath}";

          assetsCheck = ''
            if [ ! -f "${server.dataDir}/Server/HytaleServer.jar" ] \
            && [ ! -d "${server.assetsDir}" ]; then
              echo "Server data not present; please run \`hytale-server-download\` to continue" >&2
              exit 1
            fi
          '';

          /*
          TODO properly port the startup script to NixOS. Currently, it does not allow us to set
          our own JVM options, or separate the server code/assets from the data to be exposed at /srv.
          */
          serverLaunchCommand = with server; ''
            bash -- "${dataDir}/start.sh" --bind ${listenAddress}:${toString port}
          '';

          sessionStart =
            if server.tmux.enable
            then ''
              ${tmux} new-session -d ${serverLaunchCommand}
            ''
            else serverLaunchCommand;

          sessionPreStart = ''
            # prevent group users from modifying the server
            umask 027
            if [ ! -f "${server.dataDir}/Server/HytaleServer.jar" ]; then
              cp -r "${server.assetsDir}/." "${server.dataDir}"
            fi
          '';

          # allow the hytale group to access the tmux session
          sessionPostStart = lib.optionalString server.tmux.enable ''
            chmod 660 ${socketPath}
          '';

          sessionStop =
            if server.tmux.enable
            then ''
              if ! ${tmux} has-session; then exit; fi
              ${tmux} send-keys C-u stop Enter
              while ${tmux} has-session; do sleep 1s; done
            ''
            else ''
              echo stop > ${fifoPath}
              while kill -0 "$1" 2>/dev/null; do sleep 1s; done
            '';
        in {
          startCondition = pkgs.writeShellScript "hytale-server-${server.name}-assets-check" assetsCheck;
          start = pkgs.writeShellApplication {
            name = "hytale-server-${server.name}-start";
            runtimeInputs = [
              # start.sh requires java in the path
              server.java.package
              # the script explicitly depends on bash rather than sh, so it's safer to pull bash
              # in case bashisms are introduced in future versions
              pkgs.bash
            ];
            text = sessionStart;
          };
          preStart = pkgs.writeShellScript "hytale-server-${server.name}-pre-start" sessionPreStart;
          postStart = pkgs.writeShellScript "hytale-server-${server.name}-post-start" sessionPostStart;
          stop = pkgs.writeShellScript "hytale-server-${server.name}-stop" sessionStop;
        };

        mkHytaleServerService = server: let
          optionalSocketDependency = lib.optional (!server.tmux.enable) "hytale-server-${server.name}.socket";

          sessionScripts = mkServerSessionScripts server;
        in {
          inherit (server) enable;

          description = "Hytale Server ${server.name}";
          wantedBy = lib.mkIf server.autoStart ["default.target"];
          requires = optionalSocketDependency;
          partOf = optionalSocketDependency;
          after = ["network.target"];

          path = with pkgs; [
            # infocmp
            ncurses
            # chmod
            coreutils
          ];

          serviceConfig = {
            Type =
              if server.tmux.enable
              then "forking"
              else "simple";

            ExecCondition = sessionScripts.startCondition;
            ExecStart = getExe sessionScripts.start;
            ExecStartPre = sessionScripts.preStart;
            ExecStartPost = sessionScripts.postStart;
            ExecStop = "${sessionScripts.stop} $MAINPID";

            StandardInput =
              if server.tmux.enable
              then "null"
              else "socket";
            /*
            StandardOutput =
              if server.tmux.enable
              then "null"
              else "journal";
            StandardError =
              if server.tmux.enable
              then "null"
              else "journal";
            */
            StandardOutput = "journal";
            StandardError = "journal";
            Restart = server.restart;

            User = cfg.user;
            Group = cfg.group;
            WorkingDirectory = server.dataDir;
            RuntimeDirectory = lib.removePrefix "/run/" cfg.runtimeDir;
            RuntimeDirectoryPreserve = "restart";

            # hardening
            CapabilityBoundingSet = [""];
            DeviceAllow = [""];
            LockPersonality = true;
            PrivateDevices = true;
            PrivateTmp = true;
            PrivateUsers = true;
            ProtectClock = true;
            ProtectControlGroups = true;
            ProtectHome = true;
            ProtectHostname = true;
            ProtectKernelLogs = true;
            ProtectKernelModules = true;
            ProtectKernelTunables = true;
            ProtectProc = "invisible";
            RestrictAddressFamilies =
              [
                "AF_INET"
                "AF_INET6"
              ]
              ++ lib.optional server.tmux.enable "AF_UNIX";
            RestrictNamespaces = true;
            RestrictRealtime = true;
            RestrictSUIDSGID = true;
            SystemCallArchitectures = "native";
            UMask = "0007";
          };
        };
      in
        mapAttrs' (
          _: server: nameValuePair "hytale-server-${server.name}" (mkHytaleServerService server)
        )
        cfg.servers;

      # |                                                             |
      # |                                                             |
      # \_________________________________  __________________________/
      #                                   |/
      system.activationScripts.updateHytaleServerFiles = let
        mkServerFilesPackage = server:
          pkgs.runCommandLocal "hytale-server-${server.name}-files" {
            nativeBuildInputs = with pkgs; [xorg.lndir];
          } (
            ''
              mkdir -p $out

              linkFile() {
                method=$1
                source=$2
                destination=$3

                pkgDestination="$(realpath -m "$out/$destination")"

                mkdir -p "$(dirname "$pkgDestination")"
                if [ "$method" = "symlink" ]; then
                  if [ -d "$source" ]; then
                    lndir -silent "$source" "$pkgDestination"
                  else
                    ln -sfn "$source" "$pkgDestination"
                  fi
                elif [ "$method" = "copy" ]; then
                  cp -r "$source" "$pkgDestination"
                fi
              }
            ''
            + concatStrings (
              mapAttrsToList (_: file: ''
                linkFile "${file.method}" "${file.source}" "${file.name}"
              '')
              server.files
            )
          );
        serverFilesPackages = mapAttrs (_: server: mkServerFilesPackage server) enabledServers;
        genServerPackagesCommands = f:
          concatStrings (
            mapAttrsToList (serverName: pkg: f enabledServers."${serverName}" pkg) serverFilesPackages
          );

        migrateFiles = pkgs.writeShellApplication {
          name = "migrate-files";
          text = ''
            server_dir="$1"
            server_name="$2"

            if [ -e "$server_dir/config.json" ]; then
              echo "\`$server_name\` contains old server data, attempting to migrate" >&2

              mkdir "$server_dir/Server"
              find "$server_dir" -mindepth 1 -maxdepth 1 -path "$server_dir/Server" -prune -o -exec \
                mv -t "$server_dir/Server" '{}' +
            fi
          '';
        };
        cleanOldFiles = pkgs.writeShellApplication {
          name = "clean-old-files";
          runtimeInputs = with pkgs; [diffutils];
          text = ''
            prev_dir="$1"
            target_dir="$2"
            shift 2

            for file in "$@"; do
              prev_file="$prev_dir/$file"
              target_file="$target_dir/$file"

              if cmp -s "$prev_file" "$target_file"; then rm -rf "$target_file"; fi

              # remove the directories that have been made empty unless it's the server data root
              target_base_dir="$(dirname "$target_file")"
              if [ -d "$target_base_dir" ] && [ "$target_base_dir" != "$target_dir" ]; then
                rmdir -p --ignore-fail-on-non-empty "$target_base_dir"
              fi
            done
          '';
        };
        linkFiles = pkgs.writeShellApplication {
          name = "link-files";
          runtimeInputs = with pkgs; [diffutils];
          text = ''
            LINK_PATTERN="${lib.escapeShellArg builtins.storeDir}/*-hytale-server-*-files/*"

            warn_skip_file() {
              echo "Not overwriting existing file: $1" >&2
            }

            src_dir="$1"
            dst_dir="$2"
            shift 2

            for file in "$@"; do
              src_file="$src_dir/$file"
              dst_file="$dst_dir/$file"

              if [ -L "$src_file" ]; then
                if [ -e "$dst_file" ]; then
                  # if it's identical to the one that's already there, don't bother
                  if [ "$(readlink -e "$src_file")" = "$(readlink -e "$dst_file")" ]; then continue
                  # if it looks like a stale link to an old file, get rid of it
                  elif [ ! "$(readlink "$dst_file")" = "$LINK_PATTERN" ]; then
                    warn_skip_file "$dst_file"
                    continue
                  fi
                fi

                mkdir -p "$(dirname "$dst_file")"
                ln -Tsf "$src_file" "$dst_file"
              else
                if [ -e "$dst_file" ]; then
                  # if it's identical to the one that's already there, don't bother
                  if cmp -s "$src_file" "$dst_file"; then continue; fi
                  warn_skip_file "$dst_file"
                  continue
                fi

                rm -rf "$dst_file"
                mkdir -p "$(dirname "$dst_file")"
                cp -r "$src_file" "$dst_file"; chmod -R ug+w "$dst_file"
              fi
            done
          '';
        };

        gcRootsPath = "/nix/var/nix/gcroots/hytale";
        activateFilesScript = pkgs.writeShellScript "make-server-files" ''
          umask 007

          ${genServerPackagesCommands (
            server: pkg: let
              packageGcRootsPath = "${gcRootsPath}/${pkg.name}";
              serverConfigDir = "${server.dataDir}/Server";
            in ''
              "${getExe migrateFiles}" "${server.dataDir}" "${server.name}"

              find -L "${packageGcRootsPath}" \( -type f -or -type l \) -printf '%P\0' \
                | xargs -0 "${getExe cleanOldFiles}" "${packageGcRootsPath}" "${serverConfigDir}"

              find -L "${pkg}" \( -type f -or -type l \) -printf '%P\0' \
                | xargs -0 "${getExe linkFiles}" "${pkg}" "${serverConfigDir}"
            ''
          )}
        '';
        updateGcRootsScript = pkgs.writeShellScript "update-hytale-gc-roots" ''
          if [ -d "${gcRootsPath}" ]; then rm -rf "${gcRootsPath}"; fi
          mkdir -p "${gcRootsPath}"

          ${genServerPackagesCommands (
            _: pkg: ''
              ln -s "${pkg}" "${gcRootsPath}/${pkg.name}"
            ''
          )}
        '';
      in {
        text = ''
          ${getExe pkgs.sudo} -Hu hytale ${activateFilesScript}
          ${updateGcRootsScript}
        '';
      };
    }
  );
}
