{ ... }:
{
  services.nfs = {
    server = {
      enable = true;
      exports."/srv/media"."192.168.1.40" = [
        "rw"
        "sync"
        "root_squash"
        "no_subtree_check"
        "fsid=0"
      ];
    };
    settings = {
      nfsd = {
        vers3 = false;
        vers4 = true;
        udp = false;
      };
      mountd.manage-gids = true;
    };
  };

  systemd.services.nfs-server.unitConfig.RequiresMountsFor = [ "/srv/media" ];

  networking.firewall.extraInputRules = ''
    ip saddr 192.168.1.40 ip daddr 192.168.1.11 tcp dport 2049 accept
  '';
}
