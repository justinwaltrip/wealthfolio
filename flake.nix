{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    systems.url = "github:nix-systems/default";
    devenv.url = "github:cachix/devenv";
    devenv.inputs.nixpkgs.follows = "nixpkgs";
    nixgl.url = "github:nix-community/nixGL";
  };

  nixConfig = {
    extra-trusted-public-keys = "devenv.cachix.org-1:w1cLUi8dv3hnoSPGAuibQv+f9TZLr6cv/Hm9XgU50cw=";
    extra-substituters = "https://devenv.cachix.org";
  };

  outputs = { self, nixpkgs, devenv, systems, nixgl, ... } @ inputs:
    let
      forEachSystem = nixpkgs.lib.genAttrs (import systems);
    in
    {
      packages = forEachSystem (system: {
        devenv-up = self.devShells.${system}.default.config.procfileScript;
      });

      devShells = forEachSystem
        (system:
          let
            pkgs = nixpkgs.legacyPackages.${system};
            frameworks = pkgs.darwin.apple_sdk.frameworks;
            libraries = with pkgs; [
              gtk3
              cairo
              gdk-pixbuf
              glib
              dbus
              openssl_3
              librsvg
              libproxy
            ] ++ lib.optionals pkgs.stdenv.isLinux [
              webkitgtk
            ];
            extraPackages = with pkgs; [
              curl
              wget
              pkg-config
              dbus
              openssl_3
              glib
              gtk3
              libsoup
              librsvg
              libproxy
            ] ++ lib.optionals pkgs.stdenv.isLinux [
              webkitgtk
            ];
          in
          {
            default = devenv.lib.mkShell {
              inherit inputs pkgs;
              modules = [
                ({ pkgs, config, lib, ... }: {
                  languages.javascript = {
                    enable = true;
                    pnpm = {
                      enable = true;
                      install.enable = true;
                    };
                  };
                  languages.rust = {
                    enable = true;
                  };
                  packages = with pkgs; [
                    gcc
                  ] ++ lib.optionals pkgs.stdenv.isDarwin [
                    darwin.libobjc
                    darwin.libiconv
                    frameworks.Security
                    frameworks.CoreServices
                    frameworks.CoreFoundation
                    frameworks.AppKit
                    frameworks.Foundation
                    frameworks.ApplicationServices
                    frameworks.CoreGraphics
                    frameworks.CoreVideo
                    frameworks.Carbon
                    frameworks.IOKit
                    frameworks.CoreAudio
                    frameworks.AudioUnit
                    frameworks.QuartzCore
                    frameworks.Metal
                    frameworks.WebKit
                    frameworks.SystemConfiguration
                  ] ++ lib.optionals pkgs.stdenv.isLinux extraPackages;
                  env.CFLAGS = lib.mkForce (if pkgs.stdenv.isDarwin then "-I${pkgs.darwin.libobjc}/include/" else "");
                  enterShell = ''
                    export LD_LIBRARY_PATH=${pkgs.lib.makeLibraryPath libraries}:$LD_LIBRARY_PATH
                    export XDG_DATA_DIRS=${pkgs.gsettings-desktop-schemas}/share/gsettings-schemas/${pkgs.gsettings-desktop-schemas.name}:${pkgs.gtk3}/share/gsettings-schemas/${pkgs.gtk3.name}:$XDG_DATA_DIRS
                    export NIX_LDFLAGS="\
                      -F${frameworks.SystemConfiguration}/Library/Frameworks -framework SystemConfiguration \
                      -F${frameworks.AppKit}/Library/Frameworks -framework AppKit \
                      -F${frameworks.Foundation}/Library/Frameworks -framework Foundation \
                      -F${frameworks.WebKit}/Library/Frameworks -framework WebKit \
                      -F${frameworks.ApplicationServices}/Library/Frameworks -framework ApplicationServices \
                      -F${frameworks.CoreGraphics}/Library/Frameworks -framework CoreGraphics \
                      -F${frameworks.CoreVideo}/Library/Frameworks -framework CoreVideo \
                      -F${frameworks.CoreFoundation}/Library/Frameworks -framework CoreFoundation \
                      -F${frameworks.Carbon}/Library/Frameworks -framework Carbon \
                      -F${frameworks.QuartzCore}/Library/Frameworks -framework QuartzCore \
                      -F${frameworks.Security}/Library/Frameworks -framework Security \
                      $NIX_LDFLAGS"
                  '';
                })
              ];
            };
          }
        );
    };
}
