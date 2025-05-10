{
  description = "Elixir 1.17 development environment with VSCode";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          config.allowUnfree = true;
        };

        # Define the VSCode package with desired extensions
        vscode = pkgs.vscode-with-extensions.override {
          vscodeExtensions = with pkgs.vscode-extensions; [
            elixir-lsp.vscode-elixir-ls
            phoenixframework.phoenix
            jnoortheen.nix-ide
            eamodio.gitlens
          ];
        };
      in {
        devShells.default = pkgs.mkShell {
          buildInputs = [
            pkgs.beam.packages.erlang.elixir_1_17
            pkgs.beam.interpreters.erlang
            pkgs.nodejs
            vscode
          ];

          shellHook = ''
            export MIX_HOME=$PWD/.mix
            export HEX_HOME=$PWD/.hex
            export PATH=$MIX_HOME/bin:$HEX_HOME/bin:$PATH
          '';
        };
      });
}
