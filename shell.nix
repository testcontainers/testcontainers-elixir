{
  pkgs,
  dbName,
  mixEnv,
  beamPackages,
}: let
  # define packages to install
  basePackages = with pkgs; [
    elixir
    hex
    mix2nix
    postgresql
    esbuild
    tailwindcss
  ];

  # Add basePackages + optional system packages per system
  inputs = with pkgs;
    basePackages
    ++ lib.optionals stdenv.isLinux [inotify-tools]
    ++ lib.optionals stdenv.isDarwin
    (with darwin.apple_sdk.frameworks; [CoreFoundation CoreServices]);

  # define shell startup command
  hooks = ''
    # this allows mix to work on the local directory
    mkdir -p .nix-mix .nix-hex
    export MIX_HOME=$PWD/.nix-mix
    export HEX_HOME=$PWD/.nix-mix
    export PATH=$MIX_HOME/bin:$HEX_HOME/bin:$PATH

    export MIX_ENV=${mixEnv}

    export LANG=en_US.UTF-8
    export ELIXIR_ERL_OPTIONS="+fnu"
    # keep your shell history in iex
    export ERL_AFLAGS="-kernel shell_history enabled"

    # postgres related
    # keep all your db data in a folder inside the project
    export PGDATA="$PWD/db"

    # phoenix related env vars
    export POOL_SIZE=15
    export DB_URL="postgresql://postgres:postgres@localhost:5432/${dbName}"
    export PORT=4000
  '';
in
  pkgs.mkShell {
    buildInputs = inputs;
    shellHook = hooks;
  }
