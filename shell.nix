with import <nixpkgs> {};

stdenv.mkDerivation {
  name = "nix-flatpak";
  buildInputs = [ flatpak-builder jq ostree ];
}
