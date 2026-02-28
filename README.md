# Hytale Server Flake

A Nix flake that provides a module for configuring Hytale servers.

## Disclaimer

Since the launch of the Hytale EA, Hypixel Studios has been changing the way it
distributes its server binaries and assets and how updates are handled. For this
reason, the behavior of the flake might change a lot over this period. I'll do
my best to make sure that backwards compatibility with setups using older
versions of the flake is maintained, but please be sure to keep an eye on the
repository for new branches and changes just in case!

## Current features

- Module for configuring Hytale servers (you guessed it)
  - Service to automatically download server assets
  - Support for linking files from the store (such as plugins) into the server
    directory
  - Support for running the server in a tmux session

## Usage

- Add the following to your `flake.nix`:

  ```nix
  inputs.hytale-flake = {
    url = "github:essegd/hytale-server-flake";
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
        #tmux.enable = true;

        files = {
          "mods/my-plugin.jar".source = ./my-plugin.jar;
        };
      };
    };
  };
  ```

More options can be seen in the source.

Before starting the server, it's required to run `hytale-server-download` as the
service user (`hytale` by default) once in order to fetch the server jar and
assets. You won't need to run this again, as the server is able to update
itself; please refer to the official Hytale docs for details.

## Caveats

Parts of the module are, admittedly, a bit messy right now. This is my first Nix
project, I spent a bit of time on this and I just wanted to get it out there
before shifting my focus to other stuff. So far, the following things do not
work correctly:

- Services will hang on first launch since credentials are required
- Server doesn't log to the journal when tmux is used
- Activation script takes a while to build (it's a complete mess)

Any help with fixing these issues would be greatly appreciated! In addition, if
you encounter any issues with the project, please make an issue or contribute a
PR, it would also be very much appreciated.

## Roadmap

- Package the Hytale launcher (and of course rename the flake to reflect this)
- Make the downloader service not block or fail when the auth token isn't valid,
  but also maintain the server service's dependency on the downloader
- Improve the activation script (cleanup code, support setting permission flags)
- Write tests for the Hytale server and asset downloader

## Credits

This project is largely inspired by
[nix-minecraft](https://github.com/Infinidoge/nix-minecraft), and portions of
the activation script are derived from
[home-manager](https://github.com/nix-community/home-manager). I owe thanks to
the maintainers of both these projects for making this possible. Their licenses
are given in full text below, respectively:

```
MIT License

Copyright (c) 2022 Infinidoge

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

```
MIT License

Copyright (c) 2017-2026 Home Manager contributors

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```
