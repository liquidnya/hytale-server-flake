# Hytale Server Flake

## Current features

- Module for configuring Hytale servers
  - Service to automatically download server assets
  - Support for linking files from the store (such as plugins) into the server
    directory
  - Support for running the server in a tmux session

## Usage

- Add the following to your `flake.nix`:

  ```nix
  inputs.hytale-flake = {
    url = "github:liquidnya/hytale-server-flake";
    inputs.nixpkgs.follows = "nixpkgs";
  };
  ```

- Add the following to your system configuration and tweak to your needs:

  ```nix
  imports = [
    inputs.hytale-flake.nixosModules.hytale-servers
  ];

  services.hytale-servers = {
    enable = true;

    servers = {
      foobar = {
        autoUpdate = true;
        enable = true;
        listenAddress = "12.34.56.78";
        port = 5520;
        openFirewall = true;
        patchline = "release";
        # tmux.enable = true;

        files = {
          "mods/my-plugin.jar".source = ./my-plugin.jar;
        };
      };
    };
  };
  ```

For more options, see [modules/hytale-servers.nix](./modules/hytale-servers.nix]).

Before starting the server, it's required to run `hytale-server-download` as the
service user (`hytale` by default) once in order to fetch the server jar and
assets. You won't need to run this again, as the server is able to update
itself; please refer to the official Hytale docs for details.

## Caveats

This project has the following known issues:

- Services will hang on first launch since credentials are required
- Server doesn't log to the journal when tmux is used
- Activation script takes a while to build

## Roadmap

- [ ] Add a project-specific CLI to list, start, stop, and attach the terminal to the server process.
  This will replace the tmux session feature.
- [ ] Add selected open-source mods to this flake
  - [ ] Add [Hytale Discord Integration mod by ErdbeerbaerLP](https://github.com/ErdbeerbaerLP/HT-DiscordIntegration)
- [ ] Make the downloader service not block or fail when the auth token isn't valid
- [ ] Improve the activation script
  - [ ] cleanup code
  - [ ] support setting permission flags

## Credits

This project originates from [essegd](https://github.com/essegd) and is largely inspired by
[nix-minecraft](https://github.com/Infinidoge/nix-minecraft), and portions of
the activation script are derived from
[home-manager](https://github.com/nix-community/home-manager).
All relevant licenses of this project can be found in [COPYING](./COPYING).
