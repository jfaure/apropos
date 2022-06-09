{
  description = "apropos";

  inputs = {
    haskell-nix.url = "github:t4ccer/haskell.nix?ref=t4/ghc9-fix";
    nixpkgs.follows = "haskell-nix/nixpkgs-unstable";
    haskell-nix.inputs.nixpkgs.follows = "haskell-nix/nixpkgs-2105";
    flake-compat-ci.url = "github:hercules-ci/flake-compat-ci";
    flake-compat = {
      url = "github:edolstra/flake-compat";
      flake = false;
    };
    tasty-hedgehog = {
      url = "github:qfpl/tasty-hedgehog?ref=1.2.0.0";
      flake = false;
    };
    these = {
      url = "github:haskellari/these?ref=v1.1.1.1";
      flake = false;
    };
    indexed-traversable = {
      url = "github:haskellari/indexed-traversable/ghc-9.2a";
      flake = false;
    };
    assoc = {
      url = "github:haskellari/assoc/28cdc11e50a606ba1356976438b5ca0ad1ffe197";
      flake = false;
    };
    lens = {
      url = "github:ekmett/lens?ref=v5.1.1";
      flake = false;
    };
    one-tuple = {
      url = "github:haskellari/OneTuple?ref=v0.3.1";
      flake = false;
    };
    constraints = {
      url = "github:ekmett/constraints?ref=v0.13.4";
      flake = false;
    };
    invariant-functors = {
      url = "github:nfrisby/invariant-functors?ref=0.5.6";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, haskell-nix, flake-compat, flake-compat-ci, tasty-hedgehog, these, indexed-traversable, assoc, lens, one-tuple, constraints, invariant-functors }:
    let
      extraSources = [
        {
          src = tasty-hedgehog;
          subdirs = [ "." ];
        }
        {
          src = these;
          subdirs = [ "./these" ];
        }
        {
          src = indexed-traversable;
          subdirs = [ "indexed-traversable" "indexed-traversable-instances" ];
        }
        {
          src = assoc;
          subdirs = [ "." ];
        }
        {
          src = lens;
          subdirs = [ "." ];
        }
        {
          src = one-tuple;
          subdirs = [ "." ];
        }
        {
          src = constraints;
          subdirs = [ "." ];
        }
        {
          src = invariant-functors;
          subdirs = [ "." ];
        }
      ];

      supportedSystems =
        [ "x86_64-linux" ];

      perSystem = nixpkgs.lib.genAttrs supportedSystems;

      nixpkgsFor = system:
        import nixpkgs {
          inherit system;
          overlays = [ haskell-nix.overlay ];
          inherit (haskell-nix) config;
        };
      nixpkgsFor' = system: import nixpkgs { inherit system; };

      compiler-nix-name = "ghc921";

      fourmoluFor = system: (nixpkgsFor system).haskell-nix.tool "ghc921" "fourmolu" { };

      projectFor = system:
        let
          deferPluginErrors = true;
          pkgs = nixpkgsFor system;

          fakeSrc = pkgs.runCommand "real-source" { } ''
            cp -rT ${self} $out
            chmod u+w $out/cabal.project
          '';
        in
        (nixpkgsFor system).haskell-nix.cabalProject' {
          inherit compiler-nix-name;
          src = fakeSrc.outPath;
          cabalProjectFileName = "cabal.project";
          modules = [{ packages = { }; }];
          extraSources = extraSources;
          shell = {
            withHoogle = true;

            # tools.haskell-language-server = { };

            exactDeps = true;

            # We use the ones from Nixpkgs, since they are cached reliably.
            # Eventually we will probably want to build these with haskell.nix.
            nativeBuildInputs =
              [
                pkgs.cabal-install
                pkgs.hlint
                (fourmoluFor system)
                pkgs.nixpkgs-fmt
                pkgs.haskellPackages.cabal-fmt
                pkgs.haskellPackages.apply-refact
                pkgs.fd
              ];
            additional = ps: [
              ps.tasty-hedgehog
              ps.these
              ps.indexed-traversable
              ps.indexed-traversable-instances
              ps.assoc
              ps.lens
              ps.OneTuple
              ps.constraints
              ps.invariant
            ];
          };
        };

      formatCheckFor = system:
        let
          pkgs = nixpkgsFor system;
        in
        pkgs.runCommand "format-check"
          {
            nativeBuildInputs = [ self.devShell.${system}.nativeBuildInputs ];
          } ''
          cd ${self}
          export LC_CTYPE=C.UTF-8
          export LC_ALL=C.UTF-8
          export LANG=C.UTF-8
          export IN_NIX_SHELL='pure'
          make format_check cabalfmt_check nixpkgsfmt_check lint
          mkdir $out
        '';
    in
    {
      inherit extraSources;

      project = perSystem projectFor;
      flake = perSystem (system: (projectFor system).flake { });

      # this could be done automatically, but would reduce readability
      packages = perSystem (system: self.flake.${system}.packages);
      checks = perSystem (system:
        self.flake.${system}.checks // {
          formatCheck = formatCheckFor system;
        });
      check = perSystem (system:
        (nixpkgsFor system).runCommand "combined-test"
          {
            nativeBuildInputs = builtins.attrValues self.checks.${system};
          } "touch $out");
      apps = perSystem (system: self.flake.${system}.apps);
      devShell = perSystem (system: self.flake.${system}.devShell);

      herculesCI.ciSystems = [ "x86_64-linux" ];
    };
}
