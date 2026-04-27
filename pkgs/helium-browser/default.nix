{
  lib,
  stdenv,
  stdenvNoCC,
  fetchurl,
  autoPatchelfHook,
  makeWrapper,
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
  version = "0.11.5.1";

  src = fetchurl {
    url = "https://github.com/imputnet/helium-linux/releases/download/${finalAttrs.version}/helium-${finalAttrs.version}-x86_64_linux.tar.xz";
    hash = "sha256-wz9nqa0oU+M0Y0z8kWMCV7JCXhT4fHxhgCZB5yl78no=";
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
      --replace-quiet 'Exec=helium %U'         "Exec=$out/bin/helium-browser %U" \
      --replace-quiet 'Exec=helium --incognito' "Exec=$out/bin/helium-browser --incognito" \
      --replace-quiet 'Exec=helium'            "Exec=$out/bin/helium-browser"

    install -Dm644 product_logo_256.png \
      $out/share/icons/hicolor/256x256/apps/helium.png

    makeWrapper $out/opt/helium/helium $out/bin/helium-browser \
      --prefix LD_LIBRARY_PATH : $out/opt/helium \
      --add-flags "--ozone-platform=wayland" \
      --add-flags "--enable-features=WaylandWindowDecorations" \
      --add-flags "--enable-wayland-ime=true" \
      --add-flags "--password-store=gnome-libsecret"

    runHook postInstall
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
