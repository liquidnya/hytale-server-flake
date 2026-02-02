{
  inputs,
  pkgs,
  ...
}: let
  inherit (inputs) self;

  textFile1 = pkgs.writeText "text-file-1" ''
    The quick brown fox jumps over the lazy dog
  '';

  textFile2 = pkgs.writeText "text-file-1" ''
    cheese123
  '';
in
  pkgs.testers.runNixOSTest {
    name = "server-files";

    node.pkgsReadOnly = false;

    nodes.machine = {pkgs, ...}: {
      imports = [self.nixosModules.hytale-servers];

      system.switch.enable = true;

      nix = {
        channel.enable = false;
        registry.nixpkgs.flake = inputs.nixpkgs;
      };

      services.hytale-servers = {
        enable = true;

        servers = {
          foobar = {
            enable = true;
          };
        };
      };

      specialisation = {
        symlink-1.configuration = {
          services.hytale-servers.servers.foobar.files = {
            "bleh".source = textFile1;
          };
        };

        symlink-2.configuration = {
          services.hytale-servers.servers.foobar.files = {
            "bleh".source = textFile2;
          };
        };

        symlink-3.configuration = {
          services.hytale-servers.servers.foobar.files = {
            "bleh-2".source = textFile1;
          };
        };

        copy-1.configuration = {
          services.hytale-servers.servers.foobar.files = {
            "bleh".source = textFile1;
            "bleh-2" = {
              method = "copy";
              source = textFile2;
            };
          };
        };

        directory-1.configuration = {
          services.hytale-servers.servers.foobar.files = {
            "directory/file-1".source = textFile1;
            "directory/file-2" = {
              method = "copy";
              source = textFile2;
            };
          };
        };

        directory-2.configuration = {
          services.hytale-servers.servers.foobar.files = {
            "directory/file-1".source = textFile1;
            "directory-2/file-2" = {
              method = "copy";
              source = textFile2;
            };
          };
        };

        file-with-spaces.configuration = {
          services.hytale-servers.servers.foobar.files = {
            "my very cool file with lots of spaces in its name" = {
              method = "symlink";
              source = textFile1;
            };
            "spatial directory/file-1" = {
              method = "symlink";
              source = textFile1;
            };
            "spatial directory/file-2" = {
              method = "copy";
              source = textFile2;
            };
          };
        };
      };
    };

    testScript = {nodes, ...}: let
      buildSpecs = "${nodes.machine.system.build.toplevel}/specialisation";

      symlink1 = "${buildSpecs}/symlink-1";
      symlink2 = "${buildSpecs}/symlink-2";
      symlink3 = "${buildSpecs}/symlink-3";
      copy1 = "${buildSpecs}/copy-1";
      directory1 = "${buildSpecs}/directory-1";
      directory2 = "${buildSpecs}/directory-2";
      fileWithSpaces = "${buildSpecs}/file-with-spaces";
    in ''
      machine.wait_for_unit('default.target')

      with subtest('Symlink file'):
        machine.succeed('${symlink1}/bin/switch-to-configuration test')

        # is the file a symlink?
        machine.succeed('test -L /srv/hytale/foobar/Server/bleh')
        # does it match the expected contents?
        machine.succeed('cmp /srv/hytale/foobar/Server/bleh ${textFile1}')

      with subtest('Symlink file with updated contents'):
        machine.succeed('${symlink2}/bin/switch-to-configuration test')

        # does the file match the updated contents?
        machine.succeed('cmp /srv/hytale/foobar/Server/bleh ${textFile2}')

      with subtest('Symlink file and remove old files'):
        machine.succeed('${symlink3}/bin/switch-to-configuration test')

        # have we got rid of the old file?
        machine.succeed('test ! -e /srv/hytale/foobar/Server/bleh')
        # does the new file match the updated contents?
        machine.succeed('cmp /srv/hytale/foobar/Server/bleh-2 ${textFile1}')

      with subtest('Make multiple files and remove old files'):
        machine.succeed('${copy1}/bin/switch-to-configuration test')

        # are the files of the correct type?
        machine.succeed('test -L /srv/hytale/foobar/Server/bleh')
        machine.succeed('test ! -L /srv/hytale/foobar/Server/bleh-2')
        # do they have the correct permissions?
        machine.succeed('stat -c "%U %G %a" /srv/hytale/foobar/Server/bleh-2')
        machine.succeed('test "$(stat -c "%U %G %a" /srv/hytale/foobar/Server/bleh-2)" = "hytale hytale 660"')
        # do the files match the updated contents?
        machine.succeed('cmp /srv/hytale/foobar/Server/bleh ${textFile1}')
        machine.succeed('cmp /srv/hytale/foobar/Server/bleh-2 ${textFile2}')

      with subtest('Make directory with files'):
        machine.succeed('${directory1}/bin/switch-to-configuration test')

        # have we got rid of the old file?
        machine.succeed('test ! -e /srv/hytale/foobar/Server/bleh-1')
        machine.succeed('test ! -e /srv/hytale/foobar/Server/bleh-2')
        # have we made the directory with the expected contents?
        machine.succeed('test -d /srv/hytale/foobar/Server/directory')
        machine.succeed('cmp /srv/hytale/foobar/Server/directory/file-1 ${textFile1}')
        machine.succeed('cmp /srv/hytale/foobar/Server/directory/file-2 ${textFile2}')

      with subtest('Make multiple directories with files'):
        machine.succeed('${directory2}/bin/switch-to-configuration test')

        # have we got rid of the old file?
        machine.succeed('test ! -e /srv/hytale/foobar/Server/directory/bleh-1')
        # do the files match the expected contents?
        machine.succeed('test -d /srv/hytale/foobar/Server/directory')
        machine.succeed('cmp /srv/hytale/foobar/Server/directory/file-1 ${textFile1}')
        machine.succeed('cmp /srv/hytale/foobar/Server/directory-2/file-2 ${textFile2}')

      with subtest('Make files with spaces in their names'):
        machine.succeed('${fileWithSpaces}/bin/switch-to-configuration test')

        # have we got rid of the old directories?
        machine.succeed('test ! -d /srv/hytale/foobar/Server/directory')
        machine.succeed('test ! -d /srv/hytale/foobar/Server/directory-2')
        # does the file the expected contents?
        machine.succeed('cmp "/srv/hytale/foobar/Server/my very cool file with lots of spaces in its name" ${textFile1}')
        machine.succeed('cmp "/srv/hytale/foobar/Server/spatial directory/file-1" ${textFile1}')
        machine.succeed('cmp "/srv/hytale/foobar/Server/spatial directory/file-2" ${textFile2}')
    '';
  }
