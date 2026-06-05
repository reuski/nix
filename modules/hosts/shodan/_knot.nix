{
  services.tangled.knot = {
    enable = true;
    stateDir = "/var/lib/knot";
    server = {
      hostname = "knot.reuski.dev";
      owner = "did:plc:igxk22uwwycyvrhxxwz2zevj";
      listenAddr = "127.0.0.1:5555";
    };
  };

  services.openssh.settings.AllowUsers = [ "git" ];

  services.caddy.virtualHosts."knot.reuski.dev".extraConfig = ''
    reverse_proxy 127.0.0.1:5555
  '';
}
