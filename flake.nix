{
  inputs = {
    opam-nix.url = "github:tweag/opam-nix";
    flake-utils.url = "github:numtide/flake-utils";
    nixpkgs.follows = "opam-nix/nixpkgs";
  };
  outputs = { self, flake-utils, opam-nix, nixpkgs }@inputs:
    let package = "passage";
    in flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        on = opam-nix.lib.${system};
        scope = on.buildOpamProject {
          resolveArgs = {
            # Add extra nixpkgs deps for conf packages
            extraPackages = with pkgs; [ pkg-config ];
          };
        } package ./. { ocaml-base-compiler = "*"; };
        overlay = final: prev: {
          ${package} = prev.${package}.overrideAttrs
            (old: { buildInputs = (old.buildInputs or [ ]) ++ [ pkgs.age ]; });
        };
      in {
        legacyPackages = scope.overrideScope overlay;
        packages.default = self.legacyPackages.${system}.${package};

        devShell = pkgs.mkShell {
          inputsFrom = [ self.packages.${system}.default ];
          buildInputs = with pkgs; [ age ];
          nativeBuildInputs = with pkgs; [ pkg-config ];
          shellHook = ''
            # Source the completion script
            source ${./passage-completion.sh}
            if [[ -n "$ZSH_VERSION" ]]; then
              autoload -Uz _passage
              compdef _passage passage
            fi
          '';
        };
      });
}
