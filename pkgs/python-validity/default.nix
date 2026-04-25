{
  lib,
  python3Packages,
  fetchurl,
  gobject-introspection,
  wrapGAppsNoGuiHook,
  innoextract,
}:

python3Packages.buildPythonPackage rec {
  pname = "python-validity";
  version = "0.15";
  format = "setuptools";

  src = fetchurl {
    url = "https://github.com/uunicorn/python-validity/archive/refs/tags/${version}.tar.gz";
    hash = "sha256-2rBWclhIAoXec/vxlwnXXiDlyrxmJKLavWpP/eYNWMY=";
  };

  nativeBuildInputs = [
    gobject-introspection
    wrapGAppsNoGuiHook
  ];

  propagatedBuildInputs = with python3Packages; [
    cryptography
    dbus-python
    pygobject3
    pyusb
    pyyaml
  ];

  postPatch = ''
    substituteInPlace validitysensor/init_data_dir.py \
      --replace '/var/run/python-validity/' '/var/lib/python-validity/'
  '';

  postInstall = ''
    install -D -m 644 dbus_service/io.github.uunicorn.Fprint.conf \
      $out/share/dbus-1/system.d/io.github.uunicorn.Fprint.conf
    install -D -m 755 dbus_service/dbus-service \
      $out/lib/python-validity/dbus-service
  '';

  dontWrapGApps = true;
  makeWrapperArgs = [ "\${gappsWrapperArgs[@]}" ];

  postFixup = ''
    wrapProgram $out/bin/validity-sensors-firmware \
      --prefix PATH : ${lib.makeBinPath [ innoextract ]}
    wrapPythonProgramsIn "$out/lib/python-validity" "$out ''${pythonPath[*]}"
  '';

  meta = {
    description = "Validity/Synaptics fingerprint sensor driver for ThinkPads";
    homepage = "https://github.com/uunicorn/python-validity";
    license = lib.licenses.gpl3Only;
    platforms = lib.platforms.linux;
  };
}
