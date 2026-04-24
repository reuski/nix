{
  lib,
  stdenv,
  stdenvNoCC,
  fetchurl,
  autoPatchelfHook,
  makeWrapper,
  writeShellScript,
  curl,
  jq,
  common-updater-scripts,

  alsa-lib,
  at-spi2-atk,
  at-spi2-core,
  cairo,
  cups,
  dbus,
  expat,
  fontconfig,
  freetype,
  gdk-pixbuf,
  glib,
  gtk3,
  libdrm,
  libnotify,
  libpulseaudio,
  libsecret,
  libxkbcommon,
  mesa,
  nspr,
  nss,
  pango,
  systemd,
  wayland,
  libappindicator-gtk3,
  libx11,
  libxscrnsaver,
  libxcomposite,
  libxdamage,
  libxext,
  libxfixes,
  libxrandr,
  libxcb,
  libxshmfence,
}:

stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "helium-browser";
  version = "0.11.3.2";

  src = fetchurl {
    url = "https://github.com/imputnet/helium-linux/releases/download/${finalAttrs.version}/helium-${finalAttrs.version}-x86_64_linux.tar.xz";
    hash = "sha256-DMgy1NH2+huzDGySlCqNpgj7JnLt4OtgUeCjxMCWvFs=";
  };

  sourceRoot = "helium-${finalAttrs.version}-x86_64_linux";

  postPatch = ''
    rm -f libqt5_shim.so libqt6_shim.so
  '';

  nativeBuildInputs = [
    autoPatchelfHook
    makeWrapper
  ];

  buildInputs = [
    stdenv.cc.cc.lib
    alsa-lib
    at-spi2-atk
    at-spi2-core
    cairo
    cups
    dbus
    expat
    fontconfig
    freetype
    gdk-pixbuf
    glib
    gtk3
    libdrm
    libnotify
    libpulseaudio
    libsecret
    libxkbcommon
    mesa
    nspr
    nss
    pango
    systemd
    wayland
    libappindicator-gtk3
    libx11
    libxscrnsaver
    libxcomposite
    libxdamage
    libxext
    libxfixes
    libxrandr
    libxcb
    libxshmfence
  ];

  runtimeDependencies = [
    (lib.getLib systemd)
    libnotify
    libsecret
    wayland
  ];

  dontWrapGApps = true;

  installPhase = ''
    runHook preInstall

    install -d $out/opt/helium
    cp -a --reflink=auto . $out/opt/helium/

    install -Dm644 helium.desktop $out/share/applications/helium-browser.desktop
    substituteInPlace $out/share/applications/helium-browser.desktop \
      --replace-quiet 'Exec=helium %U'         'Exec=helium-browser %U' \
      --replace-quiet 'Exec=helium --incognito' 'Exec=helium-browser --incognito' \
      --replace-quiet 'Exec=helium'            'Exec=helium-browser'

    install -Dm644 product_logo_256.png \
      $out/share/icons/hicolor/256x256/apps/helium.png

    makeWrapper $out/opt/helium/helium $out/bin/helium-browser \
      --prefix LD_LIBRARY_PATH : $out/opt/helium \
      --add-flags "--ozone-platform=wayland" \
      --add-flags "--enable-features=WaylandWindowDecorations" \
      --add-flags "--password-store=gnome-libsecret"

    runHook postInstall
  '';

  passthru.updateScript = writeShellScript "update-helium-browser" ''
    set -euo pipefail
    latest=$(${lib.getExe curl} -fsSL \
      https://api.github.com/repos/imputnet/helium-linux/releases/latest \
      | ${lib.getExe jq} -r '.tag_name')
    ${common-updater-scripts}/bin/update-source-version helium-browser "$latest"
  '';

  meta = {
    description = "Private, fast Chromium-based web browser (upstream Linux tarball)";
    homepage = "https://helium.computer/";
    downloadPage = "https://github.com/imputnet/helium-linux/releases";
    license = lib.licenses.gpl3Only;
    platforms = [ "x86_64-linux" ];
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    mainProgram = "helium-browser";
    maintainers = [ ];
  };
})
