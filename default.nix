{ stdenv, fetchzip, closureInfo, writeTextFile, bubblewrap, flatpak, flatpak-builder, shellcheck }:

partialManifest:

let
  closure = closureInfo { rootPaths = [ manifest.command ]; };

  runtimeVersion = "1.6";

  defaultManifest = {
    runtime = "org.freedesktop.Platform";
    runtime-version = runtimeVersion;
    sdk = "org.freedesktop.Sdk";
    modules = [{
      name = "nix-flatpak";
      buildsystem = "simple";
      build-commands = [ "cp -r store /app" ];
      sources = [{ type = "dir"; path = "nix"; }];
    }];
  };

  runtime = fetchzip {
    # Note that v2 in this URL is temporary, it has been added only
    # because 1.6 is already taken by BasePlatform/BaseSdk version.
    url = "https://gitlab.com/yegortimoshenko/flatpak-runtime/-/jobs/artifacts/${runtimeVersion}v2/download?job=runtime.zip";
    sha256 = "1ilrlrqnlvnrp7fn3c8knacqj5v70nfmlby0a6kla1xp7ad3wmsn";
    stripRoot = false;
  };

  writeShellScript = source: writeTextFile {
    name = "script";
    executable = true;
    checkPhase = "${shellcheck}/bin/shellcheck $out";
    text = ''
      #!${stdenv.shell} -e
      ${source}
    '';
  };

  withEnv = source: writeShellScript ''
    bwrap=(
      ${bubblewrap}/bin/bwrap
      --ro-bind /bin /bin
      --dev /dev
      --ro-bind /etc /etc
      --ro-bind /nix /nix
      --proc /proc
      --bind /tmp /tmp
      --bind /tmp /var/tmp
      --dir /sys/block
      --dir /sys/bus
      --dir /sys/class
      --dir /sys/dev
      --dir /sys/devices
    )

    if test -d /build; then
      bwrap+=(--bind /build /build)
    fi

    "''${bwrap[@]}" ${source} "$@"
  '';

  flatpak-build = writeShellScript ''
    export HOME=$PWD
    export FLATPAK_SYSTEM_DIR=.local/share/flatpak

    for f in ${runtime}/{platform,sdk}.flatpak; do
      flatpak install --user -y $f
    done

    flatpak-builder --disable-rofiles-fuse --sandbox --user build manifest.json
    flatpak build-export $FLATPAK_SYSTEM_DIR/repo build
    flatpak build-bundle $FLATPAK_SYSTEM_DIR/repo "$@"
  '';

  manifest = stdenv.lib.recursiveUpdate defaultManifest partialManifest;
in

stdenv.mkDerivation {
  name = "${manifest.app-id}.flatpak";
  nativeBuildInputs = [ flatpak flatpak-builder ];

  buildCommand = ''
    cat <<EOF > manifest.json
${builtins.toJSON manifest}
EOF

    for path in $(< ${closure}/store-paths); do
      cp --parents -r $path .
    done

    chmod -R +w .

    find . -type f -exec sed -i s:/nix/store:/app/store:g {} \;

    ${withEnv flatpak-build} tmp ${manifest.app-id} && mv tmp $out
  '';

  meta = with stdenv.lib; {
    platforms = platforms.linux;
  };
}
