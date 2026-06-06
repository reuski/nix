{ inputs, ... }:
{
  flake.overlays.python-validity = final: _prev: {
    python-validity = final.callPackage (
      {
        lib,
        python3Packages,
        gobject-introspection,
        wrapGAppsNoGuiHook,
        innoextract,
      }:

      let
        d = inputs.python-validity.lastModifiedDate;
      in
      python3Packages.buildPythonPackage {
        pname = "python-validity";
        version = "0-unstable-${lib.substring 0 4 d}-${lib.substring 4 2 d}-${lib.substring 6 2 d}";
        pyproject = true;

        src = inputs.python-validity;

        nativeBuildInputs = [
          gobject-introspection
          wrapGAppsNoGuiHook
        ];

        build-system = [ python3Packages.setuptools ];

        dependencies = with python3Packages; [
          cryptography
          dbus-python
          pygobject3
          pyusb
          pyyaml
        ];

        postPatch = ''
          substituteInPlace validitysensor/init_data_dir.py \
            --replace-fail '/var/run/python-validity/' '/var/lib/python-validity/'
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
          buildPythonPath "$out ''${pythonPath[*]}"
          wrapProgram $out/lib/python-validity/dbus-service \
            --prefix PYTHONPATH : "$program_PYTHONPATH"
        '';

        meta = {
          description = "Validity/Synaptics fingerprint sensor driver for ThinkPads";
          homepage = "https://github.com/uunicorn/python-validity";
          license = lib.licenses.mit;
          platforms = lib.platforms.linux;
        };
      }
    ) { };
  };
}
