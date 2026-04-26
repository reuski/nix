{ config, pkgs, ... }:

{
  environment.systemPackages = [ pkgs.open-fprintd pkgs.python-validity ];

  systemd.packages = [ pkgs.open-fprintd ];

  systemd.tmpfiles.rules = [ "d /var/lib/python-validity 0755 root root -" ];

  systemd.services.open-fprintd = {
    wantedBy = [ "multi-user.target" ];
  };

  security.pam.services.greetd.fprintAuth = true;
  security.pam.services.login.fprintAuth = true;

  services.udev.extraRules = ''
    SUBSYSTEM!="usb", GOTO="python_validity_end"
    ENV{DEVTYPE}!="usb_device", GOTO="python_validity_end"

    ATTRS{idVendor}=="138a", ATTRS{idProduct}=="0090", GOTO="python_validity_match"
    ATTRS{idVendor}=="138a", ATTRS{idProduct}=="0097", GOTO="python_validity_match"
    ATTRS{idVendor}=="06cb", ATTRS{idProduct}=="009a", GOTO="python_validity_match"

    GOTO="python_validity_end"

    LABEL="python_validity_match"

    ACTION=="add|change", ATTR{power/control}="auto", RUN+="${config.systemd.package}/bin/systemctl --no-block start python3-validity.service"
    ACTION=="remove", RUN+="${config.systemd.package}/bin/systemctl --no-block stop python3-validity.service"

    LABEL="python_validity_end"
  '';

  systemd.services.python3-validity = {
    description = "python-validity driver dbus service";
    after = [ "open-fprintd.service" ];
    serviceConfig = {
      Type = "simple";
      ExecStart = "${pkgs.python-validity}/lib/python-validity/dbus-service --debug";
      Restart = "no";
    };
  };
}
