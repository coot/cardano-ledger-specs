{
  extras = hackage:
    {
      packages = {
        "sequence" = (((hackage.sequence)."0.9.8").revisions).default;
        "tasty-hedgehog" = (((hackage.tasty-hedgehog)."1.0.0.1").revisions).default;
        "Unique" = (((hackage.Unique)."0.4.7.6").revisions).default;
        "bimap" = (((hackage.bimap)."0.4.0").revisions).default;
        "moo" = (((hackage.moo)."1.2").revisions).default;
        "gray-code" = (((hackage.gray-code)."0.3.1").revisions).default;
        "base58-bytestring" = (((hackage.base58-bytestring)."0.1.0").revisions).default;
        "hedgehog" = (((hackage.hedgehog)."1.0").revisions).default;
        "micro-recursion-schemes" = (((hackage.micro-recursion-schemes)."5.0.2.2").revisions).default;
        "protolude" = (((hackage.protolude)."0.2.4").revisions).default;
        "streaming-binary" = (((hackage.streaming-binary)."0.3.0.1").revisions).default;
        "cborg" = (((hackage.cborg)."0.2.2.0").revisions).default;
        "canonical-json" = (((hackage.canonical-json)."0.6.0.0").revisions).default;
        delegation = ./delegation.nix;
        cs-blockchain = ./cs-blockchain.nix;
        cs-ledger = ./cs-ledger.nix;
        small-steps = ./small-steps.nix;
        non-integer = ./non-integer.nix;
        cardano-prelude = ./cardano-prelude.nix;
        cardano-binary = ./cardano-binary.nix;
        cardano-crypto-class = ./cardano-crypto-class.nix;
        goblins = ./goblins.nix;
        cardano-crypto = ./cardano-crypto.nix;
        };
      compiler.version = "8.6.5";
      compiler.nix-name = "ghc865";
      };
  resolver = "lts-13.26";
  modules = [ ({ lib, ... }: { packages = {}; }) { packages = {}; } ];
  compiler = "ghc-8.6.5";
  }