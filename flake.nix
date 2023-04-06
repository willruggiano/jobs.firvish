{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    pre-commit-nix.url = "github:cachix/pre-commit-hooks.nix";
  };

  outputs = {flake-parts, ...} @ inputs:
    flake-parts.lib.mkFlake {inherit inputs;} {
      imports = [
        inputs.pre-commit-nix.flakeModule
      ];

      systems = ["x86_64-linux" "aarch64-darwin"];
      perSystem = {
        config,
        pkgs,
        system,
        ...
      }: {
        apps.generate-vimdoc.program = pkgs.writeShellApplication {
          name = "generate-vimdoc";
          runtimeInputs = with pkgs; [lemmy-help];
          text = ''
            lemmy-help -c lua/jobs-firvish.lua > doc/jobs-firvish.txt
          '';
        };

        devShells.default = pkgs.mkShell {
          name = "jobs.firvish";
          buildInputs = with pkgs; [lemmy-help];
          shellHook = ''
            ${config.pre-commit.installationScript}
          '';
        };

        formatter = pkgs.alejandra;

        pre-commit = {
          settings = {
            hooks.alejandra.enable = true;
            hooks.stylua.enable = true;
          };
        };
      };
    };
}
