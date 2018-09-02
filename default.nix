{ closureInfo, lib, runCommand, flatpak, flatpak-builder }: partialManifest:

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

  manifest = lib.recursiveUpdate defaultManifest partialManifest;
in

runCommand "${manifest.app-id}.flatpak" { HOME = "."; buildInputs = [ flatpak flatpak-builder ]; } ''
  cat <<EOF > manifest.json
${builtins.toJSON manifest}
EOF

  for path in $(< ${closure}/store-paths); do
    cp --parents -r $path .
  done

  chmod -R +w .

  find . -type f -exec sed -i s:/nix/store:/app/store:g {} \;

  flatpak-builder build manifest.json --user --install
  flatpak build-bundle .local/share/flatpak/repo $out ${manifest.app-id}
''
