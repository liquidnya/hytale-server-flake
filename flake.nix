{
  inputs = {
    flakelight.url = "github:nix-community/flakelight";
    flakelight.inputs.nixpkgs.follows = "nixpkgs";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = {flakelight, ...} @ inputs:
    flakelight ./. {
      inherit inputs;
      systems = ["x86_64-linux"];

      imports = [
        ./modules
        ./packages
        ./tests
      ];

      devShell.packages = pkgs: [pkgs.alejandra];
      formatters = {
        "*.nix" = "alejandra";
      };

      lib = {
        # in theory we could package the launcher and server for these other platforms,
        # however I have no experience with nix on macos or windows
        getHytaleCDNSystem = platform: let
          arch = let
            inherit (platform.parsed.cpu) name;
          in
            if name == "x86_64"
            then "amd64"
            else if name == "aarch64"
            then "arm64"
            else throw "Unsupported CPU architecture for Hytale: ${arch}";

          os =
            if platform.isLinux
            then "linux"
            else if platform.isMacos
            then "macos"
            else if (platform.isWindows || platform.isCygwin)
            then "windows"
            else throw "Unsupported OS for Hytale: ${os}";
        in {
          inherit arch os;
        };
      };
    };
}
