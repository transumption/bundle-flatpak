{ stdenv, closureInfo, flatpak, flatpak-builder }: partialManifest:

let
  closure = closureInfo { rootPaths = [ manifest.command ]; };

  defaultManifest = {
    runtime = "org.freedesktop.BasePlatform";
    runtime-version = "1.6";
    sdk = "org.freedesktop.BaseSdk";
    modules = [{
      name = "nix-flatpak";
      buildsystem = "simple";
      build-commands = [ "cp -r store /app" ];
      sources = [{ type = "dir"; path = "nix"; }];
    }];
  };

  runtime = stdenv.mkDerivation {
    name = "flatpak-runtime";
    nativeBuildInputs = [ flatpak ];

    outputHashAlgo = "sha256";
    outputhash = "1qnzadh1k3hszn94rb7369fsb3f1f6j0xiq777g75fxw06fz0cf0";
    outputHashMode = "recursive";

    HOME = ".";

    buildCommand = ''
      flatpak remote-add --user flathub https://flathub.org/repo/flathub.flatpakrepo
      flatpak install -y --user flathub org.freedesktop.BasePlatform//1.6 org.freedesktop.BaseSdk//1.6

      mv .local/share/flatpak/runtime $out
    '';
  };

  manifest = stdenv.lib.recursiveUpdate defaultManifest partialManifest;
in

stdenv.mkDerivation {
  name = "${manifest.app-id}.flatpak";
  nativeBuildInputs = [ flatpak flatpak-builder ];

  HOME = ".";

  buildCommand = ''
    cat <<EOF > manifest.json
${builtins.toJSON manifest}
EOF

    for path in $(< ${closure}/store-paths); do
      cp --parents -r $path .
    done

    chmod -R +w .

    find . -type f -exec sed -i s:/nix/store:/app/store:g {} \;

    mkdir -p .local/share/flatpak
    cp -rs ${runtime} $_/runtime

    flatpak remote-add --user flathub https://flathub.org/repo/flathub.flatpakrepo
    flatpak-builder --user --install build manifest.json
    flatpak build-bundle .local/share/flatpak/repo $out ${manifest.app-id}
  '';

  meta = with stdenv.lib; {
    platforms = platforms.linux;
  };
}
