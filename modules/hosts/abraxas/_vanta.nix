{ ... }:
{
  launchd.daemons.vanta.serviceConfig = {
    Label = "com.vanta.metalauncher";
    ProgramArguments = [ "/usr/local/vanta/metalauncher" ];
    RunAtLoad = true;
    KeepAlive = true;
    StandardErrorPath = "/var/log/vanta_stderr.log";
  };
}
