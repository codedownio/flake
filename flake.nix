{
  description = "CodeDown Desktop";

  inputs.flake-utils.url = "github:numtide/flake-utils";
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/release-22.11";

  inputs.templates.url = "github:codedownio/templates";
  inputs.templates.flake = false;

  outputs = { self, flake-utils, nixpkgs, templates }:
    flake-utils.lib.eachSystem [ "x86_64-linux" ] (system:
      let
        pkgs = import nixpkgs { inherit system; };

        util = pkgs.callPackage ./util.nix {};

        frontend = pkgs.fetchzip {
          url = "https://github.com/codedownio/desktop/releases/download/v0.2.0.0/codedown-frontend.tar.gz";
          sha256 = "sha256-Mlm4tIBYbn24j0UVY2KJHyRKFmt1rpHLZPwfR+YtNys=";
          stripRoot = false;
        };

        staticDocs = pkgs.fetchzip {
          url = "https://github.com/codedownio/desktop/releases/download/v0.2.0.0/codedown-static-docs.tar.gz";
          sha256 = "sha256-UG+y5n433dKKvbCP0FXWk5DYOGjigzOxUxOPwCClaas=";
          stripRoot = false;
        };

        editor = util.packageBinary {
          name = "codedown-editor";
          binary = pkgs.fetchurl {
            url = "https://github.com/codedownio/desktop/releases/download/v0.2.0.0/codedown-editor";
            sha256 = "1by5dr83dhq11r9qgd9b886zyqvssf2173n876aiqr95m4bqka8p";
          };
        };

        runner = util.packageBinary {
          name = "codedown-runner";
          binary = pkgs.fetchurl {
            url = "https://github.com/codedownio/desktop/releases/download/v0.2.0.0/codedown-runner";
            sha256 = "0hp3k1x5njbc1r3fq3y3n6vanj1l201kzr62cbq4ng8d500h7f2q";
          };
        };

        server = util.packageBinary {
          name = "codedown-server";
          binary = pkgs.fetchurl {
            url = "https://github.com/codedownio/desktop/releases/download/v0.2.0.0/codedown-server";
            sha256 = "0jzmbx5p5p15nfw70nygr20lbq0icp7jn4a9a0lkn0yysciayb8d";
          };
        };

        wrappedServer = with pkgs; runCommand "codedown-server-wrapped" { buildInputs = [makeWrapper]; } ''
          mkdir -p $out/bin
          makeWrapper "${server}/bin/codedown-server" "$out/bin/codedown-server" \
            --prefix PATH : ${lib.makeBinPath [ bubblewrap ]}
        '';

      in rec {
        apps = {
          default = {
            type = "app";
            program = let
              script = with pkgs; writeShellScript "codedown-server.sh" ''
                CONFIG_DIR=''${XDG_CONFIG_HOME:-$HOME/.config}/codedown

                if [ ! -d "CONFIG_DIR" ]; then
                  echo "Creating $CONFIG_DIR"
                  mkdir -p "$CONFIG_DIR"
                fi

                CONFIG_FILE="$CONFIG_DIR/config.json"
                if [ ! -f "CONFIG_FILE" ]; then
                  echo "Installing initial configuration to $CONFIG_FILE"
                  ${pkgs.gnused}/bin/sed "s|CODEDOWN_ROOT|$CONFIG_DIR|g" "${packages.default}" > "$CONFIG_FILE"
                fi

                ${wrappedServer}/bin/codedown-server -c "$CONFIG_FILE"
              '';
            in
              "${script}";
          };
        };

        packages = {
          default = pkgs.writeTextFile {
            name = "codedown-config.json";
            text = pkgs.callPackage ./config.nix {
              bootstrapNixpkgs = pkgs.path;
              defaultPackageStoreEnv = pkgs.hello; # TODO
              inherit staticDocs;

              inherit editor frontend runner templates;
            };
          };
        };
      });
}
